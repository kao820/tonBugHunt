#include "adnl/adnl.h"
#include "adnl/adnl-address-list.h"
#include "adnl/adnl-network-manager.h"
#include "auto/tl/ton_api.hpp"
#include "keyring/keyring.h"
#include "keys/encryptor.h"
#include "td/actor/actor.h"
#include "td/actor/PromiseFuture.h"
#include "td/utils/Random.h"
#include "td/utils/buffer.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/port/StdStreams.h"
#include "td/utils/port/signals.h"
#include "tl-utils/tl-utils.hpp"

#include <cstdlib>
#include <iostream>
#include <string>

namespace {
std::string env_or(const char *name, std::string fallback = "") {
  const char *value = std::getenv(name);
  return value ? std::string(value) : fallback;
}

td::Result<td::BufferSlice> hex_decode(td::Slice hex) {
  if (hex.size() % 2 != 0) {
    return td::Status::Error("hex length must be even");
  }
  td::BufferSlice out(hex.size() / 2);
  auto dst = out.as_slice();
  for (size_t i = 0; i < out.size(); i++) {
    auto nybble = [](char c) -> int {
      if ('0' <= c && c <= '9') return c - '0';
      if ('a' <= c && c <= 'f') return c - 'a' + 10;
      if ('A' <= c && c <= 'F') return c - 'A' + 10;
      return -1;
    };
    int hi = nybble(hex[2 * i]);
    int lo = nybble(hex[2 * i + 1]);
    if (hi < 0 || lo < 0) {
      return td::Status::Error("invalid hex digit");
    }
    dst[i] = static_cast<td::uint8>((hi << 4) | lo);
  }
  return out;
}

class Sender : public td::actor::Actor {
 public:
  explicit Sender(td::Promise<td::Unit> done) : done_(std::move(done)) {
  }

  void start_up() override {
    auto packet_path = env_or("RLDP2_PACKET_FILE");
    auto host = env_or("RLDP2_TARGET_HOST", "127.0.0.1");
    auto port_s = env_or("RLDP2_TARGET_PORT");
    auto target_pubkey_hex = env_or("RLDP2_TARGET_ADNL_PUBKEY_TL_HEX");
    if (packet_path.empty() || port_s.empty() || target_pubkey_hex.empty()) {
      finish(td::Status::Error("missing RLDP2_PACKET_FILE, RLDP2_TARGET_PORT, or RLDP2_TARGET_ADNL_PUBKEY_TL_HEX"));
      return;
    }
    if (!(host == "127.0.0.1" || host == "localhost" || host.rfind("127.", 0) == 0) && env_or("RLDP2_ALLOW_NON_LOCAL") != "1") {
      finish(td::Status::Error("non-loopback target refused without RLDP2_ALLOW_NON_LOCAL=1"));
      return;
    }

    auto port = static_cast<td::uint16>(std::stoul(port_s));
    auto ip_r = td::IPAddress::get_ipv4_port(host, port);
    if (ip_r.is_error()) {
      finish(ip_r.move_as_error_prefix("bad target address: "));
      return;
    }
    target_addr_ = ip_r.move_as_ok();

    auto data_r = td::read_file(packet_path);
    if (data_r.is_error()) {
      finish(data_r.move_as_error_prefix("failed to read packet: "));
      return;
    }
    packet_ = data_r.move_as_ok();
    if (packet_.size() == 0 || packet_.size() > 1024) {
      finish(td::Status::Error("packet must be 1..1024 bytes for first-pass bounded run"));
      return;
    }

    auto pub_bytes_r = hex_decode(target_pubkey_hex);
    if (pub_bytes_r.is_error()) {
      finish(pub_bytes_r.move_as_error_prefix("bad target pubkey hex: "));
      return;
    }
    auto pub_r = ton::fetch_tl_object<ton::ton_api::PublicKey>(pub_bytes_r.move_as_ok(), true);
    if (pub_r.is_error()) {
      finish(pub_r.move_as_error_prefix("failed to parse target PublicKey TL: "));
      return;
    }
    target_full_ = ton::adnl::AdnlNodeIdFull{ton::PublicKey{pub_r.move_as_ok()}};
    target_short_ = target_full_.compute_short_id();

    keyring_ = ton::keyring::Keyring::create("");
    adnl_ = ton::adnl::Adnl::create("", keyring_.get());
    network_manager_ = ton::adnl::AdnlNetworkManager::create();
    td::actor::send_closure(adnl_, &ton::adnl::Adnl::register_network_manager, network_manager_.get());

    auto source_pk = ton::PrivateKey{ton::privkeys::Ed25519::random()};
    auto source_pub = source_pk.compute_public_key();
    source_short_ = ton::adnl::AdnlNodeIdShort{source_pub.compute_short_id()};
    td::actor::send_closure(keyring_, &ton::keyring::Keyring::add_key, std::move(source_pk), true, [](td::Result<td::Unit>) {});

    ton::adnl::AdnlAddressList source_addrs;
    td::actor::send_closure(adnl_, &ton::adnl::Adnl::add_id, ton::adnl::AdnlNodeIdFull{source_pub}, source_addrs, td::uint8(0));

    ton::adnl::AdnlAddressList target_addrs;
    target_addrs.add_udp_adnl_address(target_addr_).ensure();
    td::actor::send_closure(adnl_, &ton::adnl::Adnl::add_peer, source_short_, target_full_, target_addrs);

    td::actor::send_closure(adnl_, &ton::adnl::Adnl::send_message, source_short_, target_short_, packet_.clone());
    alarm_timestamp() = td::Timestamp::in(0.5);
  }

  void alarm() override {
    std::cout << "timestamp\tsource_peer\ttarget_peer\tsend_result\tstatus\tresponse_or_error\telapsed_ms\n";
    std::cout << static_cast<td::uint32>(td::Clocks::system()) << '\t' << source_short_ << '\t' << target_short_
              << "\t1\tok\tqueued_adnl_send_message\t500\n";
    finish(td::Status::OK());
  }

 private:
  void finish(td::Status status) {
    if (finished_) {
      return;
    }
    finished_ = true;
    if (status.is_error()) {
      std::cout << "timestamp\tsource_peer\ttarget_peer\tsend_result\tstatus\tresponse_or_error\telapsed_ms\n";
      std::cout << static_cast<td::uint32>(td::Clocks::system()) << "\t-\t-\t0\terror\t" << status.to_string() << "\t0\n";
      done_.set_error(std::move(status));
    } else {
      done_.set_value(td::Unit());
    }
    stop();
  }

  td::Promise<td::Unit> done_;
  bool finished_{false};
  td::actor::ActorOwn<ton::keyring::Keyring> keyring_;
  td::actor::ActorOwn<ton::adnl::Adnl> adnl_;
  td::actor::ActorOwn<ton::adnl::AdnlNetworkManager> network_manager_;
  ton::adnl::AdnlNodeIdFull target_full_;
  ton::adnl::AdnlNodeIdShort target_short_;
  ton::adnl::AdnlNodeIdShort source_short_;
  td::IPAddress target_addr_;
  td::BufferSlice packet_;
};
}  // namespace

int main() {
  SET_VERBOSITY_LEVEL(verbosity_ERROR);
  td::actor::Scheduler scheduler({0});
  td::PromiseFuture<td::Unit> pf;
  auto promise = pf.get_promise();
  auto future = pf.get_future();
  scheduler.run_in_context([&] { td::actor::create_actor<Sender>("rldp2-adnl-sender", std::move(promise)).release(); });
  while (scheduler.run(1)) {
    if (future.is_ready()) {
      break;
    }
  }
  auto res = future.move_as_result();
  return res.is_ok() ? 0 : 1;
}
