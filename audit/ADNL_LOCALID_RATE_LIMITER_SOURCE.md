# ADNL-LOCALID-RATE-LIMITER-REGRESSION-01 raw source extract

Source extraction only. No builds, tests, harnesses, or runtime/network traffic were run.

## Environment

- pwd: `/workspace/tonBugHunt`
- repo root: `/workspace/tonBugHunt`
- branch: `work`
- HEAD: `3a30d9d37eccca633e6ece843098358700661e2e`
- git status before file creation: `(clean before creating audit/ADNL_LOCALID_RATE_LIMITER_SOURCE.md)`
- date/time: `2026-06-23T09:34:41Z`

## Commands used

- `pwd`
- `git rev-parse --show-toplevel`
- `git branch --show-current`
- `git rev-parse HEAD`
- `git status --short`
- `rg -n "receive_coro|void AdnlLocalId::receive|InboundRateLimiter|inbound_rate_limiter_|UNIQUE_PEERS_PER_IP_LIMIT|remove_port|void AdnlLocalId::alarm|AdnlLocalId::alarm|receive_decrypted_packet" adnl/adnl-local-id.cpp adnl/adnl-local-id.h adnl/adnl-peer-table.cpp adnl/adnl-peer.cpp adnl/utils.cpp`
- `git show --unified=80 a6298cf27004c8ea0d9a30fa2149ef839bb28807 -- adnl/adnl-local-id.cpp adnl/adnl-local-id.h adnl/adnl-peer-table.cpp adnl/adnl-peer.cpp adnl/utils.cpp`

## Full relevant source excerpts from HEAD
### `remove_port(addr)` implementation

```cpp
adnl/adnl-local-id.cpp:29: static td::IPAddress remove_port(td::IPAddress addr) {
adnl/adnl-local-id.cpp:30:   addr.set_port(0);
adnl/adnl-local-id.cpp:31:   return addr;
adnl/adnl-local-id.cpp:32: }
```
### `AdnlLocalId::receive` wrapper/caller and full `AdnlLocalId::receive_coro`

```cpp
adnl/adnl-local-id.cpp:47: void AdnlLocalId::receive(td::IPAddress addr, td::BufferSlice data) {
adnl/adnl-local-id.cpp:48:   [](AdnlLocalId *self, td::IPAddress addr, td::BufferSlice data) -> td::actor::Task<> {
adnl/adnl-local-id.cpp:49:     auto R = co_await self->receive_coro(addr, std::move(data)).wrap();
adnl/adnl-local-id.cpp:50:     if (R.is_error()) {
adnl/adnl-local-id.cpp:51:       VLOG(ADNL_NOTICE) << self << ": dropping IN message from " << addr << ": " << R.move_as_error();
adnl/adnl-local-id.cpp:52:     }
adnl/adnl-local-id.cpp:53:     co_return {};
adnl/adnl-local-id.cpp:54:   }(this, std::move(addr), std::move(data))
adnl/adnl-local-id.cpp:55:                                                                          .start()
adnl/adnl-local-id.cpp:56:                                                                          .detach();
adnl/adnl-local-id.cpp:57: }
adnl/adnl-local-id.cpp:58: 
adnl/adnl-local-id.cpp:59: td::actor::Task<> AdnlLocalId::receive_coro(td::IPAddress addr, td::BufferSlice data) {
adnl/adnl-local-id.cpp:60:   InboundRateLimiter &rate_limiter = inbound_rate_limiter_[remove_port(addr)];
adnl/adnl-local-id.cpp:61:   if (!cleanup_rate_limiter_at_) {
adnl/adnl-local-id.cpp:62:     alarm_timestamp().relax(cleanup_rate_limiter_at_ = td::Timestamp::in(1.0));
adnl/adnl-local-id.cpp:63:   }
adnl/adnl-local-id.cpp:64:   if (!rate_limiter.rate_limiter.take()) {
adnl/adnl-local-id.cpp:65:     add_dropped_packet_stats(addr);
adnl/adnl-local-id.cpp:66:     co_return td::Status::Error("rate limit exceeded");
adnl/adnl-local-id.cpp:67:   }
adnl/adnl-local-id.cpp:68:   ++rate_limiter.currently_decrypting_packets;
adnl/adnl-local-id.cpp:69: 
adnl/adnl-local-id.cpp:70:   size_t data_size = data.size();
adnl/adnl-local-id.cpp:71:   auto r_decrypted_data =
adnl/adnl-local-id.cpp:72:       co_await td::actor::ask(keyring_, &keyring::Keyring::decrypt_message, short_id_.pubkey_hash(), std::move(data))
adnl/adnl-local-id.cpp:73:           .wrap();
adnl/adnl-local-id.cpp:74: 
adnl/adnl-local-id.cpp:75:   // rate_limiter cannot be deleted from map while currently_decrypting_packets > 0
adnl/adnl-local-id.cpp:76:   --rate_limiter.currently_decrypting_packets;
adnl/adnl-local-id.cpp:77:   add_decrypted_packet_stats(addr);
adnl/adnl-local-id.cpp:78: 
adnl/adnl-local-id.cpp:79:   auto tl = co_await fetch_tl_object<ton_api::adnl_packetContents>(co_await std::move(r_decrypted_data), true);
adnl/adnl-local-id.cpp:80:   auto packet = co_await AdnlPacket::create(std::move(tl));
adnl/adnl-local-id.cpp:81:   packet.set_remote_addr(addr);
adnl/adnl-local-id.cpp:82:   if (rate_limiter.recent_inbound_peers.size() >= UNIQUE_PEERS_PER_IP_LIMIT) {
adnl/adnl-local-id.cpp:83:     if (!rate_limiter.recent_inbound_peers.contains(packet.from_short())) {
adnl/adnl-local-id.cpp:84:       co_return td::Status::Error("too many unique peer ids from a single ip");
adnl/adnl-local-id.cpp:85:     }
adnl/adnl-local-id.cpp:86:   } else {
adnl/adnl-local-id.cpp:87:     rate_limiter.recent_inbound_peers.insert(packet.from_short());
adnl/adnl-local-id.cpp:88:     if (!cleanup_recent_inbound_peers_at_) {
adnl/adnl-local-id.cpp:89:       alarm_timestamp().relax(cleanup_recent_inbound_peers_at_ = td::Timestamp::in(UNIQUE_PEERS_PER_IP_WINDOW));
adnl/adnl-local-id.cpp:90:     }
adnl/adnl-local-id.cpp:91:   }
adnl/adnl-local-id.cpp:92: 
adnl/adnl-local-id.cpp:93:   td::actor::send_closure(peer_table_, &AdnlPeerTable::receive_decrypted_packet, short_id_, std::move(packet),
adnl/adnl-local-id.cpp:94:                           data_size);
adnl/adnl-local-id.cpp:95:   co_return {};
adnl/adnl-local-id.cpp:96: }
```
### `InboundRateLimiter`, `inbound_rate_limiter_` map type, cleanup timestamps, and `UNIQUE_PEERS_PER_IP_LIMIT`

```cpp
adnl/adnl-local-id.h:99:   AdnlNodeIdShort short_id_;
adnl/adnl-local-id.h:100: 
adnl/adnl-local-id.h:101:   td::uint32 mode_;
adnl/adnl-local-id.h:102: 
adnl/adnl-local-id.h:103:   struct InboundRateLimiter {
adnl/adnl-local-id.h:104:     RateLimiter rate_limiter = RateLimiter(75, 0.33);
adnl/adnl-local-id.h:105:     td::uint64 currently_decrypting_packets = 0;
adnl/adnl-local-id.h:106:     std::set<AdnlNodeIdShort> recent_inbound_peers;
adnl/adnl-local-id.h:107:   };
adnl/adnl-local-id.h:108:   std::map<td::IPAddress, InboundRateLimiter> inbound_rate_limiter_;
adnl/adnl-local-id.h:109:   struct PacketStats {
adnl/adnl-local-id.h:110:     double ts_start = 0.0, ts_end = 0.0;
adnl/adnl-local-id.h:111: 
adnl/adnl-local-id.h:112:     struct Counter {
adnl/adnl-local-id.h:113:       td::uint64 packets = 0;
adnl/adnl-local-id.h:114:       double last_packet_ts = 0.0;
adnl/adnl-local-id.h:115: 
adnl/adnl-local-id.h:116:       void inc() {
adnl/adnl-local-id.h:117:         ++packets;
adnl/adnl-local-id.h:118:         last_packet_ts = td::Clocks::system();
adnl/adnl-local-id.h:119:       }
adnl/adnl-local-id.h:120:     };
adnl/adnl-local-id.h:121:     std::map<td::IPAddress, Counter> decrypted_packets;
adnl/adnl-local-id.h:122:     std::map<td::IPAddress, Counter> dropped_packets;
adnl/adnl-local-id.h:123: 
adnl/adnl-local-id.h:124:     tl_object_ptr<ton_api::adnl_stats_localIdPackets> tl(bool all = true) const;
adnl/adnl-local-id.h:125:   } packet_stats_cur_, packet_stats_prev_;
adnl/adnl-local-id.h:126:   void add_decrypted_packet_stats(td::IPAddress addr);
adnl/adnl-local-id.h:127:   void add_dropped_packet_stats(td::IPAddress addr);
adnl/adnl-local-id.h:128:   void prepare_packet_stats();
adnl/adnl-local-id.h:129: 
adnl/adnl-local-id.h:130:   void publish_address_list();
adnl/adnl-local-id.h:131: 
adnl/adnl-local-id.h:132:   td::Timestamp publish_address_list_at_ = td::Timestamp::now();
adnl/adnl-local-id.h:133:   td::Timestamp cleanup_rate_limiter_at_ = td::Timestamp::never();
adnl/adnl-local-id.h:134:   td::Timestamp cleanup_recent_inbound_peers_at_ = td::Timestamp::never();
adnl/adnl-local-id.h:135: 
adnl/adnl-local-id.h:136:   static constexpr size_t UNIQUE_PEERS_PER_IP_LIMIT = 60;
adnl/adnl-local-id.h:137:   static constexpr double UNIQUE_PEERS_PER_IP_WINDOW = 60.0;
```
### `RateLimiter` implementation used inside `InboundRateLimiter`

```cpp
adnl/utils.hpp:43: class RateLimiter {
adnl/utils.hpp:44:  public:
adnl/utils.hpp:45:   explicit RateLimiter(td::uint32 capacity, double period)
adnl/utils.hpp:46:       : period_(period), emission_interval_(make_emission_interval(capacity, period)), ready_at_{-emission_interval_} {
adnl/utils.hpp:47:   }
adnl/utils.hpp:48: 
adnl/utils.hpp:49:   bool take() {
adnl/utils.hpp:50:     const auto now = td::Timestamp::now();
adnl/utils.hpp:51:     auto min_ready_at = now.at() - emission_interval_;
adnl/utils.hpp:52:     if (ready_at_ < min_ready_at) {
adnl/utils.hpp:53:       ready_at_ = min_ready_at;
adnl/utils.hpp:54:     }
adnl/utils.hpp:55:     if (ready_at_ > now.at()) {
adnl/utils.hpp:56:       return false;
adnl/utils.hpp:57:     }
adnl/utils.hpp:58:     ready_at_ += period_;
adnl/utils.hpp:59:     return true;
adnl/utils.hpp:60:   }
adnl/utils.hpp:61: 
adnl/utils.hpp:62:   td::Timestamp ready_at() const {
adnl/utils.hpp:63:     const auto now = td::Timestamp::now();
adnl/utils.hpp:64:     if (ready_at_ > now.at()) {
adnl/utils.hpp:65:       return td::Timestamp::at(ready_at_);
adnl/utils.hpp:66:     }
adnl/utils.hpp:67:     return now;
adnl/utils.hpp:68:   }
adnl/utils.hpp:69: 
adnl/utils.hpp:70:   bool is_full() const {
adnl/utils.hpp:71:     return ready_at_ < td::Timestamp::now().at() - emission_interval_;
adnl/utils.hpp:72:   }
adnl/utils.hpp:73: 
adnl/utils.hpp:74:   double period() const {
adnl/utils.hpp:75:     return period_;
adnl/utils.hpp:76:   }
adnl/utils.hpp:77: 
adnl/utils.hpp:78:  private:
adnl/utils.hpp:79:   static double make_emission_interval(td::uint32 capacity, double period) {
adnl/utils.hpp:80:     CHECK(capacity >= 1);
adnl/utils.hpp:81:     CHECK(period > 0.0);
adnl/utils.hpp:82:     return static_cast<double>(capacity - 1) * period;
adnl/utils.hpp:83:   }
adnl/utils.hpp:84: 
adnl/utils.hpp:85:   double period_;
adnl/utils.hpp:86:   double emission_interval_;
adnl/utils.hpp:87:   double ready_at_;
adnl/utils.hpp:88: };
adnl/utils.hpp:89: 
adnl/utils.hpp:90: }  // namespace adnl
```
### `AdnlLocalId::start_up`, `AdnlLocalId::alarm`, and rate-limiter cleanup/eviction logic

```cpp
adnl/adnl-local-id.cpp:270: void AdnlLocalId::start_up() {
adnl/adnl-local-id.cpp:271:   alarm();
adnl/adnl-local-id.cpp:272: }
adnl/adnl-local-id.cpp:273: 
adnl/adnl-local-id.cpp:274: void AdnlLocalId::alarm() {
adnl/adnl-local-id.cpp:275:   if (publish_address_list_at_.is_in_past()) {
adnl/adnl-local-id.cpp:276:     publish_address_list();
adnl/adnl-local-id.cpp:277:     publish_address_list_at_ =
adnl/adnl-local-id.cpp:278:         td::Timestamp::in(AdnlPeerTable::republish_addr_list_timeout() * td::Random::fast(1.0, 2.0));
adnl/adnl-local-id.cpp:279:   }
adnl/adnl-local-id.cpp:280:   alarm_timestamp().relax(publish_address_list_at_);
adnl/adnl-local-id.cpp:281:   if (cleanup_recent_inbound_peers_at_ && cleanup_recent_inbound_peers_at_.is_in_past()) {
adnl/adnl-local-id.cpp:282:     cleanup_recent_inbound_peers_at_ = td::Timestamp::never();
adnl/adnl-local-id.cpp:283:     for (auto &[_, limiter] : inbound_rate_limiter_) {
adnl/adnl-local-id.cpp:284:       limiter.recent_inbound_peers.clear();
adnl/adnl-local-id.cpp:285:     }
adnl/adnl-local-id.cpp:286:   }
adnl/adnl-local-id.cpp:287:   if ((cleanup_rate_limiter_at_ && cleanup_rate_limiter_at_.is_in_past())) {
adnl/adnl-local-id.cpp:288:     for (auto it = inbound_rate_limiter_.begin(); it != inbound_rate_limiter_.end();) {
adnl/adnl-local-id.cpp:289:       auto &limiter = it->second;
adnl/adnl-local-id.cpp:290:       if (limiter.currently_decrypting_packets == 0 && limiter.rate_limiter.is_full() &&
adnl/adnl-local-id.cpp:291:           limiter.recent_inbound_peers.empty()) {
adnl/adnl-local-id.cpp:292:         it = inbound_rate_limiter_.erase(it);
adnl/adnl-local-id.cpp:293:       } else {
adnl/adnl-local-id.cpp:294:         ++it;
adnl/adnl-local-id.cpp:295:       }
adnl/adnl-local-id.cpp:296:     }
adnl/adnl-local-id.cpp:297:     if (inbound_rate_limiter_.empty()) {
adnl/adnl-local-id.cpp:298:       cleanup_rate_limiter_at_ = td::Timestamp::never();
adnl/adnl-local-id.cpp:299:     } else {
adnl/adnl-local-id.cpp:300:       cleanup_rate_limiter_at_ = td::Timestamp::in(1.0);
adnl/adnl-local-id.cpp:301:     }
adnl/adnl-local-id.cpp:302:   }
adnl/adnl-local-id.cpp:303:   alarm_timestamp().relax(cleanup_rate_limiter_at_);
adnl/adnl-local-id.cpp:304:   alarm_timestamp().relax(cleanup_recent_inbound_peers_at_);
adnl/adnl-local-id.cpp:305: }
adnl/adnl-local-id.cpp:306: 
```
### Other `inbound_rate_limiter_` read/write sites in `AdnlLocalId`

```cpp
adnl/adnl-local-id.cpp:337:   for (auto &[ip, x] : inbound_rate_limiter_) {
adnl/adnl-local-id.cpp:338:     if (x.currently_decrypting_packets != 0) {
adnl/adnl-local-id.cpp:339:       stats->current_decrypt_.push_back(create_tl_object<ton_api::adnl_stats_ipPackets>(
adnl/adnl-local-id.cpp:340:           ip.is_valid() ? ip.get_ip_str().str() : "", x.currently_decrypting_packets));
adnl/adnl-local-id.cpp:341:     }
adnl/adnl-local-id.cpp:342:   }
adnl/adnl-local-id.cpp:343:   prepare_packet_stats();
adnl/adnl-local-id.cpp:344:   stats->packets_recent_ = packet_stats_prev_.tl();
adnl/adnl-local-id.cpp:345:   promise.set_result(std::move(stats));
adnl/adnl-local-id.cpp:346: }
adnl/adnl-local-id.cpp:347: 
adnl/adnl-local-id.cpp:348: void AdnlLocalId::add_decrypted_packet_stats(td::IPAddress addr) {
adnl/adnl-local-id.cpp:349:   prepare_packet_stats();
adnl/adnl-local-id.cpp:350:   packet_stats_cur_.decrypted_packets[remove_port(addr)].inc();
adnl/adnl-local-id.cpp:351: }
adnl/adnl-local-id.cpp:352: 
adnl/adnl-local-id.cpp:353: void AdnlLocalId::add_dropped_packet_stats(td::IPAddress addr) {
adnl/adnl-local-id.cpp:354:   prepare_packet_stats();
adnl/adnl-local-id.cpp:355:   packet_stats_cur_.dropped_packets[remove_port(addr)].inc();
adnl/adnl-local-id.cpp:356: }
```
### `AdnlPeerTableImpl::receive_decrypted_packet` signature and first relevant lines

```cpp
adnl/adnl-peer-table.cpp:123: void AdnlPeerTableImpl::receive_decrypted_packet(AdnlNodeIdShort dst, AdnlPacket packet, td::uint64 serialized_size) {
adnl/adnl-peer-table.cpp:124:   packet.run_basic_checks().ensure();
adnl/adnl-peer-table.cpp:125: 
adnl/adnl-peer-table.cpp:126:   if (!packet.inited_from_short()) {
adnl/adnl-peer-table.cpp:127:     VLOG(ADNL_INFO) << this << ": dropping IN message [?->" << dst << "]: destination not set";
adnl/adnl-peer-table.cpp:128:     return;
adnl/adnl-peer-table.cpp:129:   }
adnl/adnl-peer-table.cpp:130:   AdnlNodeIdShort src = packet.from_short();
adnl/adnl-peer-table.cpp:131: 
adnl/adnl-peer-table.cpp:132:   auto it = peers_.find(src);
adnl/adnl-peer-table.cpp:133:   if (it == peers_.end()) {
adnl/adnl-peer-table.cpp:134:     if (!packet.inited_from()) {
adnl/adnl-peer-table.cpp:135:       VLOG(ADNL_NOTICE) << this << ": dropping IN message [" << packet.from_short() << "->" << dst
adnl/adnl-peer-table.cpp:136:                         << "]: unknown peer and no full src in packet";
adnl/adnl-peer-table.cpp:137:       return;
adnl/adnl-peer-table.cpp:138:     }
adnl/adnl-peer-table.cpp:139:     if (network_manager_.empty()) {
adnl/adnl-peer-table.cpp:140:       VLOG(ADNL_NOTICE) << this << ": dropping IN message [" << packet.from_short() << "->" << dst
adnl/adnl-peer-table.cpp:141:                         << "]: unknown peer and network manager uninitialized";
adnl/adnl-peer-table.cpp:142:       return;
adnl/adnl-peer-table.cpp:143:     }
adnl/adnl-peer-table.cpp:144: 
adnl/adnl-peer-table.cpp:145:     it = peers_.try_emplace(src).first;
adnl/adnl-peer-table.cpp:146:   }
adnl/adnl-peer-table.cpp:147: 
adnl/adnl-peer-table.cpp:148:   auto it2 = local_ids_.find(dst);
adnl/adnl-peer-table.cpp:149:   if (it2 == local_ids_.end()) {
adnl/adnl-peer-table.cpp:150:     VLOG(ADNL_ERROR) << this << ": dropping IN message [" << packet.from_short() << "->" << dst
adnl/adnl-peer-table.cpp:151:                      << "]: unknown dst (but how did we decrypt message?)";
adnl/adnl-peer-table.cpp:152:     return;
adnl/adnl-peer-table.cpp:153:   }
adnl/adnl-peer-table.cpp:154: 
adnl/adnl-peer-table.cpp:155:   if (packet.inited_from()) {
adnl/adnl-peer-table.cpp:156:     update_id(it->second, packet.from());
adnl/adnl-peer-table.cpp:157:   }
adnl/adnl-peer-table.cpp:158: 
adnl/adnl-peer-table.cpp:159:   td::actor::send_closure(get_peer_pair(src, it->second, dst, it2->second), &AdnlPeerPair::receive_packet,
adnl/adnl-peer-table.cpp:160:                           std::move(packet), serialized_size);
adnl/adnl-peer-table.cpp:161: }
adnl/adnl-peer-table.cpp:162: 
```
## Exact ordering analysis

- Is `inbound_rate_limiter_[remove_port(addr)]` executed before decrypt? **Yes.** `receive_coro` first binds `InboundRateLimiter &rate_limiter = inbound_rate_limiter_[remove_port(addr)]` at `adnl/adnl-local-id.cpp:60`; the decrypt ask starts later at `adnl/adnl-local-id.cpp:70-72`.
- Does `operator[]` create an entry for invalid/undecryptable packets? **Yes for the outer IP map.** The `std::map<td::IPAddress, InboundRateLimiter>` declaration is at `adnl/adnl-local-id.h:108`, and `operator[]` is used before decrypt at `adnl/adnl-local-id.cpp:60`; invalid decrypt/parse errors occur after the entry has already been selected/created at `adnl/adnl-local-id.cpp:70-79`.
- Is there a global cap on number of IP entries? **No visible global cap in the extracted source.** The source shows a per-entry `RateLimiter(75, 0.33)` at `adnl/adnl-local-id.h:104`, but no size cap around the `std::map` at `adnl/adnl-local-id.h:108` or before `operator[]` at `adnl/adnl-local-id.cpp:60`.
- Is there TTL/cleanup for stale IP entries? **Yes, conditional cleanup exists.** `receive_coro` schedules `cleanup_rate_limiter_at_` for 1 second at `adnl/adnl-local-id.cpp:61-63`; `alarm()` erases entries only when `currently_decrypting_packets == 0`, `rate_limiter.is_full()`, and `recent_inbound_peers.empty()` at `adnl/adnl-local-id.cpp:288-293`.
- Is cleanup guaranteed under sustained traffic? **Unclear.** `alarm()` reschedules every 1 second while the map is non-empty at `adnl/adnl-local-id.cpp:297-301`, but sustained packets from an IP can keep the entry non-empty/not full or keep `recent_inbound_peers` populated until the separate 60-second clear runs at `adnl/adnl-local-id.cpp:282-286`.
- Does cleanup remove entries with empty/expired `recent_inbound_peers`? **Yes, only after `recent_inbound_peers` is empty and the rate limiter is full.** The peer set is cleared globally at `adnl/adnl-local-id.cpp:282-286`; the map entry is erased later only if the combined conditions at `adnl/adnl-local-id.cpp:288-293` hold.
- Is IPv6 keyed by full address or aggregated by /64/prefix? **Full `td::IPAddress` after port zeroing in this source.** `remove_port` only calls `addr.set_port(0)` at `adnl/adnl-local-id.cpp:29-31`; no /64 or prefix aggregation is visible.
- Are IPv4-mapped IPv6 and IPv4 normalized consistently? **Unclear from the extracted source.** The only visible normalization is port zeroing in `remove_port` at `adnl/adnl-local-id.cpp:29-31`; any IPv4-mapped IPv6 normalization would need to be inside `td::IPAddress`, not shown here.
- Is `recent_inbound_peers` capped before insertion? **Yes for successful decrypt/parse packets.** Size is checked against `UNIQUE_PEERS_PER_IP_LIMIT` at `adnl/adnl-local-id.cpp:82-87`; the cap value is `60` at `adnl/adnl-local-id.h:136`.
- Can invalid packets mutate `recent_inbound_peers`, or only the outer IP map? **Only the outer IP map is confirmed for invalid/undecryptable packets.** `recent_inbound_peers.insert(packet.from_short())` occurs after decrypt, TL fetch, and `AdnlPacket::create` at `adnl/adnl-local-id.cpp:76-88`.
- Does an invalid packet reach peer table? **No.** `receive_decrypted_packet` is called only after successful decrypt/parse and peer-set logic at `adnl/adnl-local-id.cpp:93-94`; the peer table itself begins with `packet.run_basic_checks().ensure()` at `adnl/adnl-peer-table.cpp:124`.

## Commit diff: `a6298cf27004c8ea0d9a30fa2149ef839bb28807`

Relevant sections only from:

`git show --unified=80 a6298cf27004c8ea0d9a30fa2149ef839bb28807 -- adnl/adnl-local-id.cpp adnl/adnl-local-id.h adnl/adnl-peer-table.cpp adnl/adnl-peer.cpp adnl/utils.cpp`

### Diff excerpt: `adnl/adnl-local-id.cpp` receive path

```diff
-#include "td/utils/crypto.h"
 
 #include "adnl-local-id.h"
 #include "utils.hpp"
 
 namespace ton {
 
 namespace adnl {
 
 static td::IPAddress remove_port(td::IPAddress addr) {
   addr.set_port(0);
   return addr;
 }
 
 AdnlNodeIdFull AdnlLocalId::get_id() const {
   return id_;
 }
 
 AdnlNodeIdShort AdnlLocalId::get_short_id() const {
   return short_id_;
 }
 
 AdnlAddressList AdnlLocalId::get_addr_list() const {
   CHECK(!addr_list_.empty());
   return addr_list_;
 }
 
 void AdnlLocalId::receive(td::IPAddress addr, td::BufferSlice data) {
+  [](AdnlLocalId *self, td::IPAddress addr, td::BufferSlice data) -> td::actor::Task<> {
+    auto R = co_await self->receive_coro(addr, std::move(data)).wrap();
+    if (R.is_error()) {
+      VLOG(ADNL_NOTICE) << self << ": dropping IN message from " << addr << ": " << R.move_as_error();
+    }
+    co_return {};
+  }(this, std::move(addr), std::move(data))
+                                                                         .start()
+                                                                         .detach();
+}
+
+td::actor::Task<> AdnlLocalId::receive_coro(td::IPAddress addr, td::BufferSlice data) {
   InboundRateLimiter &rate_limiter = inbound_rate_limiter_[remove_port(addr)];
   if (!cleanup_rate_limiter_at_) {
     alarm_timestamp().relax(cleanup_rate_limiter_at_ = td::Timestamp::in(1.0));
   }
   if (!rate_limiter.rate_limiter.take()) {
-    VLOG(ADNL_NOTICE) << this << ": dropping IN message: rate limit exceeded";
     add_dropped_packet_stats(addr);
-    return;
+    co_return td::Status::Error("rate limit exceeded");
   }
   ++rate_limiter.currently_decrypting_packets;
-  auto P = td::PromiseCreator::lambda([SelfId = actor_id(this), peer_table = peer_table_, dst = short_id_, addr,
-                                       id = print_id(), size = data.size()](td::Result<AdnlPacket> R) {
-    td::actor::send_closure(SelfId, &AdnlLocalId::decrypt_packet_done, addr);
-    if (R.is_error()) {
-      VLOG(ADNL_WARNING) << id << ": dropping IN message: cannot decrypt: " << R.move_as_error();
-    } else {
-      auto packet = R.move_as_ok();
-      packet.set_remote_addr(addr);
-      td::actor::send_closure(peer_table, &AdnlPeerTable::receive_decrypted_packet, dst, std::move(packet), size);
-    }
-  });
-  decrypt(std::move(data), std::move(P));
-}
 
-void AdnlLocalId::decrypt_packet_done(td::IPAddress addr) {
-  auto it = inbound_rate_limiter_.find(remove_port(addr));
-  CHECK(it != inbound_rate_limiter_.end());
-  --it->second.currently_decrypting_packets;
+  size_t data_size = data.size();
+  auto r_decrypted_data =
+      co_await td::actor::ask(keyring_, &keyring::Keyring::decrypt_message, short_id_.pubkey_hash(), std::move(data))
+          .wrap();
+
+  // rate_limiter cannot be deleted from map while currently_decrypting_packets > 0
+  --rate_limiter.currently_decrypting_packets;
   add_decrypted_packet_stats(addr);
+
+  auto tl = co_await fetch_tl_object<ton_api::adnl_packetContents>(co_await std::move(r_decrypted_data), true);
+  auto packet = co_await AdnlPacket::create(std::move(tl));
+  packet.set_remote_addr(addr);
+  if (rate_limiter.recent_inbound_peers.size() >= UNIQUE_PEERS_PER_IP_LIMIT) {
+    if (!rate_limiter.recent_inbound_peers.contains(packet.from_short())) {
+      co_return td::Status::Error("too many unique peer ids from a single ip");
+    }
+  } else {
+    rate_limiter.recent_inbound_peers.insert(packet.from_short());
+    if (!cleanup_recent_inbound_peers_at_) {
+      alarm_timestamp().relax(cleanup_recent_inbound_peers_at_ = td::Timestamp::in(UNIQUE_PEERS_PER_IP_WINDOW));
+    }
+  }
+
+  td::actor::send_closure(peer_table_, &AdnlPeerTable::receive_decrypted_packet, short_id_, std::move(packet),
+                          data_size);
+  co_return {};
 }
 
```

### Diff excerpt: `adnl/adnl-local-id.cpp` cleanup path

```diff
-  if (R.is_error()) {
-    promise.set_error(R.move_as_error());
-    return;
-  }
-
-  auto packetR = AdnlPacket::create(R.move_as_ok());
-  if (packetR.is_error()) {
-    promise.set_error(packetR.move_as_error());
-    return;
-  }
-  promise.set_value(packetR.move_as_ok());
-}
-
 void AdnlLocalId::sign_async(td::BufferSlice data, td::Promise<td::BufferSlice> promise) {
   td::actor::send_closure(keyring_, &keyring::Keyring::sign_message, short_id_.pubkey_hash(), std::move(data),
                           std::move(promise));
 }
 
 void AdnlLocalId::sign_batch_async(std::vector<td::BufferSlice> data,
                                    td::Promise<std::vector<td::Result<td::BufferSlice>>> promise) {
   td::actor::send_closure(keyring_, &keyring::Keyring::sign_messages, short_id_.pubkey_hash(), std::move(data),
                           std::move(promise));
 }
 
 void AdnlLocalId::start_up() {
   alarm();
 }
 
 void AdnlLocalId::alarm() {
   if (publish_address_list_at_.is_in_past()) {
     publish_address_list();
     publish_address_list_at_ =
         td::Timestamp::in(AdnlPeerTable::republish_addr_list_timeout() * td::Random::fast(1.0, 2.0));
   }
   alarm_timestamp().relax(publish_address_list_at_);
-  if (cleanup_rate_limiter_at_ && cleanup_rate_limiter_at_.is_in_past()) {
+  if (cleanup_recent_inbound_peers_at_ && cleanup_recent_inbound_peers_at_.is_in_past()) {
+    cleanup_recent_inbound_peers_at_ = td::Timestamp::never();
+    for (auto &[_, limiter] : inbound_rate_limiter_) {
+      limiter.recent_inbound_peers.clear();
+    }
+  }
+  if ((cleanup_rate_limiter_at_ && cleanup_rate_limiter_at_.is_in_past())) {
     for (auto it = inbound_rate_limiter_.begin(); it != inbound_rate_limiter_.end();) {
       auto &limiter = it->second;
       if (limiter.currently_decrypting_packets == 0 &&
-          limiter.rate_limiter.last_take_at() < td::Timestamp::in(-limiter.rate_limiter.period())) {
+          limiter.rate_limiter.last_take_at() < td::Timestamp::in(-limiter.rate_limiter.period()) &&
```

### Diff excerpt: `adnl/adnl-local-id.h` declarations

```diff
   auto obj = create_tl_object<ton_api::adnl_stats_localIdPackets>();
   obj->ts_start_ = ts_start;
   obj->ts_end_ = ts_end;
   for (const auto &[ip, packets] : decrypted_packets) {
     if (packets.last_packet_ts >= threshold) {
       obj->decrypted_packets_.push_back(create_tl_object<ton_api::adnl_stats_ipPackets>(
           ip.is_valid() ? PSTRING() << ip.get_ip_str() << ":" << ip.get_port() : "", packets.packets));
     }
   }
diff --git a/adnl/adnl-local-id.h b/adnl/adnl-local-id.h
index db98184..f5d831d 100644
--- a/adnl/adnl-local-id.h
+++ b/adnl/adnl-local-id.h
@@ -1,155 +1,157 @@
 /*
     This file is part of TON Blockchain Library.
 
     TON Blockchain Library is free software: you can redistribute it and/or modify
     it under the terms of the GNU Lesser General Public License as published by
     the Free Software Foundation, either version 2 of the License, or
     (at your option) any later version.
 
     TON Blockchain Library is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU Lesser General Public License for more details.
 
     You should have received a copy of the GNU Lesser General Public License
     along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.
 
     Copyright 2017-2020 Telegram Systems LLP
 */
 #pragma once
 
 #include <map>
 
 #include "auto/tl/ton_api.h"
 #include "dht/dht.h"
-#include "keys/encryptor.h"
-#include "td/actor/actor.h"
+#include "td/actor/coro_utils.h"
 #include "td/utils/BufferedUdp.h"
 
 #include "adnl-peer-table.h"
 #include "utils.hpp"
 
 namespace ton {
 
 namespace adnl {
 
 class AdnlLocalId : public td::actor::Actor {
  public:
   AdnlNodeIdFull get_id() const;
   AdnlNodeIdShort get_short_id() const;
   AdnlAddressList get_addr_list() const;
   void get_addr_list_async(td::Promise<AdnlAddressList> P) {
     P.set_value(get_addr_list());
   }
 
   void update_dht_node(td::actor::ActorId<dht::Dht> dht_node) {
     dht_node_ = dht_node;
 
     publish_address_list();
   }
 
-  void decrypt(td::BufferSlice data, td::Promise<AdnlPacket> promise);
-  void decrypt_continue(td::BufferSlice data, td::Promise<AdnlPacket> promise);
   void decrypt_message(td::BufferSlice data, td::Promise<td::BufferSlice> promise);
   void deliver(AdnlNodeIdShort src, td::BufferSlice data);
   void deliver_query(AdnlNodeIdShort src, td::BufferSlice data, td::Promise<td::BufferSlice> promise);
   void receive(td::IPAddress addr, td::BufferSlice data);
-  void decrypt_packet_done(td::IPAddress addr);
+  td::actor::Task<> receive_coro(td::IPAddress addr, td::BufferSlice data);
 
   void subscribe(std::string prefix, std::unique_ptr<AdnlPeerTable::Callback> callback);
   void unsubscribe(std::string prefix);
 
   void update_address_list(AdnlAddressList addr_list);
 
   void get_self_node(td::Promise<AdnlNode> promise);
 
   void sign_async(td::BufferSlice data, td::Promise<td::BufferSlice> promise);
   void sign_batch_async(std::vector<td::BufferSlice> data,
                         td::Promise<std::vector<td::Result<td::BufferSlice>>> promise);
 
   AdnlLocalId(AdnlNodeIdFull id, AdnlAddressList addr_list, td::uint32 mode,
               td::actor::ActorId<AdnlPeerTable> peer_table, td::actor::ActorId<keyring::Keyring> keyring,
               td::actor::ActorId<dht::Dht> dht_node);
 
   void start_up() override;
   void alarm() override;
 
```

### Diff excerpt: `adnl/adnl-peer-table.cpp` decrypted-packet dispatch

```diff
 void AdnlPeerTableImpl::update_id(AdnlPeerTableImpl::PeerInfo &peer_info, AdnlNodeIdFull &&peer_id) {
   if (peer_info.peer_id.empty()) {
     peer_info.peer_id = std::move(peer_id);
     for (auto &e : peer_info.peers) {
-      td::actor::send_closure(e.second, &AdnlPeerPair::update_peer_id, peer_info.peer_id);
+      td::actor::send_closure(e.second.actor, &AdnlPeerPair::update_peer_id, peer_info.peer_id);
     }
   }
 }
 
 td::actor::ActorOwn<AdnlPeerPair> &AdnlPeerTableImpl::get_peer_pair(AdnlNodeIdShort peer_id,
                                                                     AdnlPeerTableImpl::PeerInfo &peer_info,
                                                                     AdnlNodeIdShort local_id,
                                                                     AdnlPeerTableImpl::LocalIdInfo &local_id_info) {
   auto it = peer_info.peers.find(local_id);
   if (it == peer_info.peers.end()) {
     it = peer_info.peers
              .emplace(local_id, AdnlPeerPair::create(network_manager_, actor_id(this), local_id_info.mode,
                                                      local_id_info.local_id.get(), dht_node_, local_id, peer_id))
              .first;
     if (!peer_info.peer_id.empty()) {
-      td::actor::send_closure(it->second, &AdnlPeerPair::update_peer_id, peer_info.peer_id);
+      td::actor::send_closure(it->second.actor, &AdnlPeerPair::update_peer_id, peer_info.peer_id);
     }
   }
-  return it->second;
+  set_peer_pair_idle(local_id, peer_id, it->second, false);
+  return it->second.actor;
+}
+
+AdnlPeerTableImpl::PeerPair *AdnlPeerTableImpl::get_peer_pair_if_exists(AdnlNodeIdShort peer_id,
+                                                                        AdnlNodeIdShort local_id) {
+  auto p_it = peers_.find(peer_id);
+  if (p_it == peers_.end()) {
+    return nullptr;
+  }
+  auto l_it = p_it->second.peers.find(local_id);
+  return l_it == p_it->second.peers.end() ? nullptr : &l_it->second;
 }
 
 void AdnlPeerTableImpl::receive_decrypted_packet(AdnlNodeIdShort dst, AdnlPacket packet, td::uint64 serialized_size) {
   packet.run_basic_checks().ensure();
 
   if (!packet.inited_from_short()) {
     VLOG(ADNL_INFO) << this << ": dropping IN message [?->" << dst << "]: destination not set";
     return;
   }
   AdnlNodeIdShort src = packet.from_short();
 
   auto it = peers_.find(src);
   if (it == peers_.end()) {
     if (!packet.inited_from()) {
       VLOG(ADNL_NOTICE) << this << ": dropping IN message [" << packet.from_short() << "->" << dst
                         << "]: unknown peer and no full src in packet";
       return;
     }
     if (network_manager_.empty()) {
       VLOG(ADNL_NOTICE) << this << ": dropping IN message [" << packet.from_short() << "->" << dst
                         << "]: unknown peer and network manager uninitialized";
       return;
     }
 
     it = peers_.try_emplace(src).first;
   }
 
   auto it2 = local_ids_.find(dst);
   if (it2 == local_ids_.end()) {
     VLOG(ADNL_ERROR) << this << ": dropping IN message [" << packet.from_short() << "->" << dst
                      << "]: unknown dst (but how did we decrypt message?)";
     return;
   }
 
   if (packet.inited_from()) {
     update_id(it->second, packet.from());
   }
 
   td::actor::send_closure(get_peer_pair(src, it->second, dst, it2->second), &AdnlPeerPair::receive_packet,
                           std::move(packet), serialized_size);
 }
```

## Verdict helper

FORMAT RAW_SOURCE_EXTRACT_RESULT

Candidate ID: ADNL-LOCALID-RATE-LIMITER-REGRESSION-01
Repo: /workspace/tonBugHunt
Branch: work
HEAD: 3a30d9d37eccca633e6ece843098358700661e2e
File created: audit/ADNL_LOCALID_RATE_LIMITER_SOURCE.md
Ordering:

* map entry before decrypt: yes
* invalid packet can create IP entry: yes
Cleanup:
* cleanup exists: yes
* cleanup interval/TTL: cleanup_rate_limiter_at_ is scheduled every 1 second while entries remain; recent_inbound_peers is cleared after UNIQUE_PEERS_PER_IP_WINDOW = 60.0 seconds; erase requires currently_decrypting_packets == 0, rate_limiter.is_full(), and recent_inbound_peers.empty().
* global cap exists: no
IPv6:
* key granularity: full td::IPAddress after set_port(0)
* /64 aggregation: no
* IPv4-mapped normalization: unclear
Peer-table:
* invalid packet reaches peer-table: no
* unique peers per IP cap value: 60
Preliminary source verdict:
* needs further source
Reason: The source confirms outer per-IP map insertion happens before decrypt and no global map-size cap is visible here; cleanup exists but is conditional and IPv4/IPv6 normalization beyond port stripping is not visible in this source extract.
Changed files: audit/ADNL_LOCALID_RATE_LIMITER_SOURCE.md
