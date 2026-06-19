#include "auto/tl/ton_api.hpp"
#include "td/utils/Random.h"
#include "td/utils/base64.h"
#include "td/utils/buffer.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "tl-utils/tl-utils.hpp"

#include <cstdlib>
#include <iostream>
#include <string>

namespace {
std::string env_or(std::string name, std::string fallback = "") {
  const char *value = std::getenv(name.c_str());
  return value ? std::string(value) : fallback;
}

td::uint64 env_u64(std::string name, td::uint64 fallback) {
  auto value = env_or(name);
  if (value.empty()) {
    return fallback;
  }
  return static_cast<td::uint64>(std::stoull(value));
}

td::uint32 env_u32(std::string name, td::uint32 fallback) {
  auto value = env_or(name);
  if (value.empty()) {
    return fallback;
  }
  return static_cast<td::uint32>(std::stoul(value));
}

std::string hex_encode(td::Slice s) {
  static const char *digits = "0123456789abcdef";
  std::string out;
  out.reserve(s.size() * 2);
  for (unsigned char c : s) {
    out.push_back(digits[c >> 4]);
    out.push_back(digits[c & 15]);
  }
  return out;
}

}  // namespace

int main() {
  try {
    const td::uint32 symbol_size = env_u32("RLDP2_SYMBOL_SIZE", 768);
    const td::uint32 payload_size = env_u32("RLDP2_SYMBOL_PAYLOAD_BYTES", symbol_size);
    const td::uint64 total_size = env_u64("RLDP2_TOTAL_SIZE", 7680);
    const td::uint32 part = env_u32("RLDP2_PART", 0);
    const td::uint32 seqno = env_u32("RLDP2_SEQNO", 0);
    const auto out_path = env_or("RLDP2_PACKET_OUT", "");

    if (symbol_size == 0 || symbol_size > 1024) {
      std::cerr << "status\terror\tbad RLDP2_SYMBOL_SIZE\n";
      return 2;
    }
    if (payload_size == 0 || payload_size > 1024 || payload_size != symbol_size) {
      std::cerr << "status\terror\tRLDP2_SYMBOL_PAYLOAD_BYTES must be 1..1024 and equal RLDP2_SYMBOL_SIZE\n";
      return 2;
    }
    if (total_size == 0 || total_size > 7680) {
      std::cerr << "status\terror\tRLDP2_TOTAL_SIZE must be 1..7680\n";
      return 2;
    }

    td::Bits256 transfer_id;
    td::Random::secure_bytes(transfer_id.as_slice());

    auto symbols_count = static_cast<td::int32>((total_size + symbol_size - 1) / symbol_size);
    auto fec = ton::create_tl_object<ton::ton_api::fec_raptorQ>(static_cast<td::int32>(total_size),
                                                               static_cast<td::int32>(symbol_size), symbols_count);
    td::BufferSlice data(payload_size);
    td::Random::secure_bytes(data.as_slice());

    auto packet = ton::create_serialize_tl_object<ton::ton_api::rldp2_messagePart>(
        transfer_id, std::move(fec), static_cast<td::int32>(part), static_cast<td::int64>(total_size),
        static_cast<td::int32>(seqno), std::move(data));

    if (!out_path.empty()) {
      auto fd = td::FileFd::open(out_path, td::FileFd::Flags::Create | td::FileFd::Flags::Truncate | td::FileFd::Flags::Write)
                    .move_as_ok();
      fd.write(packet.as_slice()).ensure();
    }

    std::cout << "timestamp\ttransfer_id\tpacket_bytes\tpacket_hex\n";
    std::cout << static_cast<td::uint32>(td::Clocks::system()) << '\t' << transfer_id.to_hex() << '\t' << packet.size()
              << '\t' << hex_encode(packet.as_slice()) << '\n';
    return 0;
  } catch (const std::exception &e) {
    std::cerr << "status\terror\t" << e.what() << "\n";
    return 1;
  }
}
