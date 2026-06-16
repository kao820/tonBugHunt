#include "adnl/adnl-ext-client.h"
#include "auto/tl/ton_api.h"
#include "keys/keys.hpp"
#include "td/actor/actor.h"
#include "td/utils/Status.h"
#include "td/utils/buffer.h"
#include "td/utils/format.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/port/StdStreams.h"
#include "td/utils/port/path.h"
#include "tl-utils/common-utils.hpp"
#include "ton/ton-tl.hpp"
#include "ton/ton-types.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <iostream>
#include <string>

namespace {

std::string getenv_str(const char* name, const std::string& def = "") {
  const char* value = std::getenv(name);
  return value ? std::string(value) : def;
}

int hex_digit(char c) {
  if (c >= '0' && c <= '9') {
    return c - '0';
  }
  if (c >= 'a' && c <= 'f') {
    return c - 'a' + 10;
  }
  if (c >= 'A' && c <= 'F') {
    return c - 'A' + 10;
  }
  return -1;
}

td::Result<std::string> hex_to_bytes(const std::string& hex) {
  if (hex.size() % 2 != 0) {
    return td::Status::Error("hex string must have even length");
  }
  std::string out(hex.size() / 2, '\0');
  for (size_t i = 0; i < out.size(); ++i) {
    int hi = hex_digit(hex[2 * i]);
    int lo = hex_digit(hex[2 * i + 1]);
    if (hi < 0 || lo < 0) {
      return td::Status::Error("hex string contains non-hex character");
    }
    out[i] = static_cast<char>((hi << 4) | lo);
  }
  return out;
}

bool parse_hash(const char* str, ton::Bits256& hash) {
  auto* data = hash.data();
  for (int i = 0; i < 32; ++i) {
    int hi = hex_digit(str[2 * i]);
    int lo = hex_digit(str[2 * i + 1]);
    if (hi < 0 || lo < 0) {
      return false;
    }
    data[i] = static_cast<unsigned char>((hi << 4) | lo);
  }
  return true;
}

td::Result<ton::BlockIdExt> parse_block_id_ext(const std::string& value) {
  if (value.empty() || value[0] != '(') {
    return td::Status::Error("block id must use lite-client form '(workchain,shard_hex,seqno):root_hash:file_hash'");
  }
  auto pos = value.find(')');
  if (pos == std::string::npos || pos >= 38) {
    return td::Status::Error("block id tuple is malformed");
  }

  char buffer[40];
  std::memcpy(buffer, value.c_str(), pos + 1);
  buffer[pos + 1] = 0;

  ton::BlockIdExt block_id;
  unsigned long long shard = 0;
  if (std::sscanf(buffer, "(%d,%016llx,%u)", &block_id.id.workchain, &shard, &block_id.id.seqno) != 3) {
    return td::Status::Error("failed to parse block id tuple");
  }
  block_id.id.shard = shard;
  if (!block_id.id.is_valid_full()) {
    return td::Status::Error("block id tuple is not a valid full shard id");
  }

  ++pos;
  if (pos + 2 * 65 != value.size() || value[pos] != ':' || value[pos + 65] != ':') {
    return td::Status::Error("block id must include root_hash and file_hash as 64-byte hex strings");
  }
  if (!parse_hash(value.c_str() + pos + 1, block_id.root_hash) ||
      !parse_hash(value.c_str() + pos + 66, block_id.file_hash)) {
    return td::Status::Error("failed to parse root_hash or file_hash");
  }
  if (!block_id.is_valid_full()) {
    return td::Status::Error("block id is not valid after hash parsing");
  }
  return block_id;
}

td::Result<ton::PublicKey> import_public_key_from_hex(const std::string& hex) {
  TRY_RESULT(bytes, hex_to_bytes(hex));
  return ton::PublicKey::import(td::Slice(bytes));
}

td::Result<ton::PrivateKey> import_private_key_from_hex(const std::string& hex) {
  TRY_RESULT(bytes, hex_to_bytes(hex));
  return ton::PrivateKey::import(td::Slice(bytes));
}

bool is_private_host(const std::string& host) {
  if (host == "localhost" || host == "::1" || host.rfind("127.", 0) == 0 || host.rfind("10.", 0) == 0 ||
      host.rfind("192.168.", 0) == 0) {
    return true;
  }
  if (host.rfind("172.", 0) == 0) {
    auto rest = host.substr(4);
    auto dot = rest.find('.');
    if (dot != std::string::npos) {
      int second = std::atoi(rest.substr(0, dot).c_str());
      return second >= 16 && second <= 31;
    }
  }
  return getenv_str("FNSERVE_ALLOW_PRIVATE_NONLOCAL") == "1";
}

td::BufferSlice make_ton_node_query(const std::string& kind) {
  td::BufferSlice inner;
  if (kind == "downloadZeroState") {
    auto block = parse_block_id_ext(getenv_str("FNSERVE_ZERO_STATE_BLOCK")).move_as_ok();
    inner = ton::create_serialize_tl_object<ton::ton_api::tonNode_downloadZeroState>(ton::create_tl_block_id(block));
  } else if (kind == "downloadBlockFull") {
    auto block = parse_block_id_ext(getenv_str("FNSERVE_BLOCK_ID")).move_as_ok();
    inner = ton::create_serialize_tl_object<ton::ton_api::tonNode_downloadBlockFull>(ton::create_tl_block_id(block));
  } else {
    LOG(FATAL) << "unsupported FNSERVE_REQUEST_KIND=" << kind;
  }
  return ton::create_serialize_tl_object_suffix<ton::ton_api::tonNode_query>(std::move(inner));
}

class ClientActor : public td::actor::Actor {
 public:
  ClientActor(ton::adnl::AdnlNodeIdFull dst, ton::PrivateKey local_key, td::IPAddress addr, std::string kind,
              double timeout_seconds, int* exit_code)
      : dst_(std::move(dst))
      , local_key_(std::move(local_key))
      , addr_(addr)
      , kind_(std::move(kind))
      , timeout_seconds_(timeout_seconds)
      , exit_code_(exit_code) {
  }

  class Callback : public ton::adnl::AdnlExtClient::Callback {
   public:
    explicit Callback(td::actor::ActorId<ClientActor> self) : self_(self) {
    }
    void on_ready() override {
      td::actor::send_closure(self_, &ClientActor::on_ready);
    }
    void on_stop_ready() override {
      td::actor::send_closure(self_, &ClientActor::on_closed);
    }

   private:
    td::actor::ActorId<ClientActor> self_;
  };

  void start_up() override {
    start_time_ = std::time(nullptr);
    std::cout << "request_kind=" << kind_ << " start_time=" << start_time_ << "\n";
    client_ = ton::adnl::AdnlExtClient::create(dst_, local_key_, addr_, std::make_unique<Callback>(actor_id(this)));
    alarm_timestamp() = td::Timestamp::in(timeout_seconds_);
  }

  void on_ready() {
    if (sent_) {
      return;
    }
    sent_ = true;
    td::BufferSlice query = make_ton_node_query(kind_);
    auto P = td::PromiseCreator::lambda([SelfId = actor_id(this)](td::Result<td::BufferSlice> R) mutable {
      td::actor::send_closure(SelfId, &ClientActor::on_result, std::move(R));
    });
    td::actor::send_closure(client_, &ton::adnl::AdnlExtClient::send_query, kind_, std::move(query),
                            td::Timestamp::in(timeout_seconds_), std::move(P));
  }

  void on_closed() {
    if (!done_) {
      finish(3, "connection_closed", 0);
    }
  }

  void on_result(td::Result<td::BufferSlice> R) {
    if (R.is_error()) {
      auto S = R.move_as_error();
      std::cerr << "error=" << S << "\n";
      finish(2, "error", 0);
      return;
    }
    auto response = R.move_as_ok();
    finish(0, "ok", response.size());
  }

  void alarm() override {
    if (!done_) {
      finish(4, "timeout", 0);
    }
  }

 private:
  void finish(int code, const char* status, size_t response_size) {
    done_ = true;
    auto end_time = std::time(nullptr);
    std::cout << "request_kind=" << kind_ << " end_time=" << end_time << " status=" << status
              << " response_size=" << response_size << " exit_code=" << code << "\n";
    *exit_code_ = code;
    stop();
    td::actor::SchedulerContext::get().stop();
  }

  ton::adnl::AdnlNodeIdFull dst_;
  ton::PrivateKey local_key_;
  td::IPAddress addr_;
  std::string kind_;
  double timeout_seconds_;
  int* exit_code_;
  td::actor::ActorOwn<ton::adnl::AdnlExtClient> client_;
  bool sent_{false};
  bool done_{false};
  std::time_t start_time_{0};
};

}  // namespace

int main() {
  auto kind = getenv_str("FNSERVE_REQUEST_KIND");
  auto host = getenv_str("FNSERVE_MASTER_HOST");
  auto port = getenv_str("FNSERVE_MASTER_PORT");
  auto master_pubkey_hex = getenv_str("FNSERVE_MASTER_PUBKEY_TL_HEX");
  if (kind != "downloadZeroState" && kind != "downloadBlockFull") {
    std::cerr << "FNSERVE_REQUEST_KIND must be downloadZeroState or downloadBlockFull\n";
    return 10;
  }
  if (host.empty() || port.empty()) {
    std::cerr << "FNSERVE_MASTER_HOST and FNSERVE_MASTER_PORT are required\n";
    return 11;
  }
  if (!is_private_host(host)) {
    std::cerr << "refusing non-private FNSERVE_MASTER_HOST without FNSERVE_ALLOW_PRIVATE_NONLOCAL=1\n";
    return 12;
  }
  if (master_pubkey_hex.empty()) {
    std::cerr << "FNSERVE_MASTER_PUBKEY_TL_HEX is required because ADNL ext-client needs the full server public key\n";
    return 13;
  }

  auto pubkey_r = import_public_key_from_hex(master_pubkey_hex);
  if (pubkey_r.is_error()) {
    std::cerr << "failed to import FNSERVE_MASTER_PUBKEY_TL_HEX: " << pubkey_r.move_as_error() << "\n";
    return 14;
  }
  ton::PrivateKey local_key{ton::privkeys::Ed25519::random()};
  auto client_key_hex = getenv_str("FNSERVE_CLIENT_PRIVKEY_TL_HEX");
  if (!client_key_hex.empty()) {
    auto key_r = import_private_key_from_hex(client_key_hex);
    if (key_r.is_error()) {
      std::cerr << "failed to import FNSERVE_CLIENT_PRIVKEY_TL_HEX: " << key_r.move_as_error() << "\n";
      return 15;
    }
    local_key = key_r.move_as_ok();
  }

  td::IPAddress addr;
  auto addr_status = addr.init_host_port(host + ":" + port);
  if (addr_status.is_error()) {
    std::cerr << "failed to parse target host/port: " << addr_status.move_as_error() << "\n";
    return 16;
  }

  auto block_r = parse_block_id_ext(kind == "downloadZeroState" ? getenv_str("FNSERVE_ZERO_STATE_BLOCK")
                                                                 : getenv_str("FNSERVE_BLOCK_ID"));
  if (block_r.is_error()) {
    std::cerr << "failed to parse block id for " << kind << ": " << block_r.move_as_error() << "\n";
    return 17;
  }

  double timeout = 15.0;
  auto timeout_env = getenv_str("FNSERVE_CLIENT_TIMEOUT");
  if (!timeout_env.empty()) {
    timeout = std::max(1.0, std::atof(timeout_env.c_str()));
  }

  int exit_code = 1;
  td::actor::Scheduler scheduler({1});
  scheduler.run_in_context([&] {
    td::actor::create_actor<ClientActor>("fnserve-master-query-client", ton::adnl::AdnlNodeIdFull{pubkey_r.move_as_ok()},
                                         std::move(local_key), addr, kind, timeout, &exit_code)
        .release();
  });
  scheduler.run();
  return exit_code;
}
