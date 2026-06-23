# Regression Diff Candidates

Purpose: collect recent high-risk local TON diffs for regression-driven source gating. No builds, tests, harnesses, or network traffic were run for this collection.

## Environment

- repo root: `/workspace/tonBugHunt`
- branch: `work`
- HEAD: `dc7aad6edca4e214578aadd8aee52fcaaa085489`
- remote: `(none configured)`
- git status before file creation: `(clean before creating audit/REGRESSION_DIFF_CANDIDATES.md)`
- date/time: `2026-06-22T16:05:47Z`

## Commands used

- `pwd`
- `git rev-parse --show-toplevel`
- `git branch --show-current`
- `git rev-parse HEAD`
- `git remote -v`
- `git status --short`
- `git log --since='120 days ago' --date=iso-strict --pretty=format:'%H%x09%ad%x09%an%x09%s' --name-only -- <high-risk paths>`
- `git show --stat/--unified for suspicious commits only`

## Commit list (last 120 days, high-risk paths)

Commits inspected: **128**

### 1. `fde91bd4fa8f2739992777af0382f5701ca47efb`
- date: 2026-06-05T09:58:31-04:00
- author: Dan Klishch
- subject: Do not track "permanent validator keys" in manager (#2421)
- touched high-risk files: validator/manager.cpp

### 2. `c686c88a7e1c0ce725e5b63fc106fb8554f44a52`
- date: 2026-06-05T03:39:40-04:00
- author: Dan Klishch
- subject: Rename simplex_config_v2::enable_observers to enable_block_observers (#2419)
- touched high-risk files: validator/consensus/bridge.cpp, validator/consensus/private-overlay.cpp, validator/manager.cpp

### 3. `71fae45affe507170da30f3afe36deaecd471ea1`
- date: 2026-06-05T03:37:46-04:00
- author: Dan Klishch
- subject: Remove a bunch of unused options with `catchain` in their name (#2418)
- touched high-risk files: validator/consensus/block-sync-overlay.cpp, validator/consensus/bridge.cpp, validator/consensus/private-overlay.cpp, validator/manager.cpp

### 4. `2a31ce147d9c2742b543be9ae8db791e6e681b30`
- date: 2026-06-03T09:48:07-04:00
- author: Dan Klishch
- subject: Remove rldp1 (#2403)
- touched high-risk files: rldp2/CMakeLists.txt, validator/full-node.cpp

### 5. `d1379acb0f1693dadbf3ff88388ed0e06aaa49c6`
- date: 2026-05-31T17:03:56+03:00
- author: EmelyanenkoK
- subject: Harden fast sync certificate processing and other fixes
- touched high-risk files: validator/full-node-fast-sync-overlays.cpp

### 6. `2332f942c82defb95159c63ff28dee1f182e4883`
- date: 2026-05-30T15:54:28+03:00
- author: EmelyanenkoK
- subject: Update max_neighbours_ to 10 (#2407)
- touched high-risk files: overlay/overlays.h

### 7. `7f7ecc78306aee263b64fb24b14e25e2732704dc`
- date: 2026-05-29T17:51:42+03:00
- author: SpyCheese
- subject: Formatting
- touched high-risk files: validator/impl/collator.cpp

### 8. `127d38d0f266f5a3f4aa063aa667ea6fc421430d`
- date: 2026-05-29T17:19:50+03:00
- author: SpyCheese
- subject: Fix checking rldp2 part size
- touched high-risk files: rldp2/RldpConnection.cpp

### 9. `b647a8d5fcdb48cc27eba6d1b30d3305fd1546b3`
- date: 2026-05-29T15:43:20+03:00
- author: SpyCheese
- subject: Various changes and bugfixes
- touched high-risk files: adnl/adnl-peer.cpp, overlay/broadcast-fec.cpp, overlay/broadcast-simple.cpp, overlay/broadcast-twostep.cpp, overlay/overlay.cpp, overlay/overlay.hpp, overlay/overlays.h, rldp2/OutboundTransfer.h, rldp2/RldpConnection.cpp, rldp2/RldpConnection.h, rldp2/rldp.cpp, validator/consensus/block-producer.cpp, validator/consensus/block-validator.cpp, validator/consensus/bridge.cpp, validator/full-node-master.cpp, validator/impl/collator.cpp, validator/impl/liteserver.cpp, validator/manager-disk.cpp, validator/manager-hardfork.cpp, validator/manager.cpp

### 10. `c5d7d60b5301ba0dee577afe8db5dfcd5008abf6`
- date: 2026-05-23T15:20:11+03:00
- author: EmelyanenkoK
- subject: Adjust time threshold for last masterchain block check (#2340)
- touched high-risk files: validator/manager.cpp

### 11. `4209d2dbfda6cdf866dae69c0f2519dd1f0ee5d4`
- date: 2026-05-22T09:30:22-04:00
- author: Dan Klishch
- subject: Remove adnl-proxy and all related code (#2385)
- touched high-risk files: adnl/CMakeLists.txt, adnl/adnl-network-manager.cpp, adnl/adnl-network-manager.h, adnl/adnl-network-manager.hpp, adnl/adnl-proxy-types.cpp, adnl/adnl-proxy-types.h, adnl/adnl-proxy-types.hpp, adnl/adnl-proxy.cpp, adnl/adnl-test-loopback-implementation.h

### 12. `f5c669138912fcacdb15cec897e38267dbdc0e61`
- date: 2026-05-22T16:30:05+03:00
- author: SpyCheese
- subject: Various optimizations, collated data (#2384)
- touched high-risk files: validator/impl/collator.cpp, validator/manager-hardfork.cpp, validator/manager.cpp

### 13. `7cbaa3516cc7e0375e8cf54bd0724c7376db9905`
- date: 2026-05-20T17:50:53-04:00
- author: Dan Klishch
- subject: Continue sending candidate broadcasts in fast-sync
- touched high-risk files: validator/consensus/block-accepter.cpp

### 14. `1af31d59bb8671c647741d04df6e136e44c4e5a0`
- date: 2026-05-19T08:50:09-04:00
- author: Dan Klishch
- subject: Send block candidates over a dedicated block-sync overlay (#2380)
- touched high-risk files: validator/consensus/block-accepter.cpp, validator/consensus/block-sync-overlay.cpp, validator/consensus/bridge.cpp, validator/consensus/bus.h, validator/consensus/private-overlay.cpp, validator/manager.cpp

### 15. `b35ad24963089dc0dd913139df785ab9ff1621a3`
- date: 2026-05-17T12:00:06+00:00
- author: EmelyanenkoK
- subject: Apply clang-format to full node RLDP change
- touched high-risk files: validator/full-node.cpp

### 16. `832d3600f37d8f00cf981b70ee828690a8ca45ff`
- date: 2026-05-16T14:37:13+00:00
- author: EmelyanenkoK
- subject: Disable legacy RLDP for full-node shard inbound
- touched high-risk files: validator/full-node-shard.cpp, validator/full-node.cpp

### 17. `0f90e36e3c2dd715bfd661e986a41832c7a11030`
- date: 2026-05-06T23:15:36-04:00
- author: Dan Klishch
- subject: Use custom std::chrono clock as backing storage for td::Timestamp
- touched high-risk files: validator/consensus/simplex/candidate-resolver.cpp, validator/consensus/simplex/consensus.cpp

### 18. `b4added638b23fbb7c62722f4ba9190521e7ae39`
- date: 2026-05-15T18:11:09+01:00
- author: birydrad
- subject: Merge pull request #2371 from DanShaders/noncancelable-work
- touched high-risk files: (no path output)

### 19. `2ebc83d011a9bbeab08440e68b66e11b20193a50`
- date: 2026-05-15T15:26:52+04:00
- author: Marat
- subject: liteserver: get shard client state (#2327)
- touched high-risk files: validator/impl/liteserver.cpp, validator/manager-disk.cpp, validator/manager.cpp

### 20. `1ef331930872332b8ea7b892f5655e6803695f66`
- date: 2026-02-16T12:47:35-05:00
- author: Dan Klishch
- subject: Add waitFor{LiteServer,InitialSync} console queries
- touched high-risk files: validator/manager.cpp

### 21. `ff6775abe05b0f29e7906dd3189cf52a791c4137`
- date: 2026-02-16T10:28:29-05:00
- author: Dan Klishch
- subject: Add --console-ready-fd flag to validator-engine
- touched high-risk files: adnl/adnl-ext-server.cpp, adnl/adnl-ext-server.h, adnl/adnl-ext-server.hpp, adnl/adnl-peer-table.cpp, adnl/adnl.h, validator/manager.cpp

### 22. `28f872b7edb05627b93eaf7b07d4366497fae73c`
- date: 2026-05-07T18:05:08+01:00
- author: birydrad
- subject: Merge pull request #2349 from DanShaders/remove-legacy-format
- touched high-risk files: (no path output)

### 23. `91f26b24613f3037fa53f13fb2f8febc6c01e011`
- date: 2026-05-06T09:55:48-04:00
- author: Dan Klishch
- subject: Rewrite `<< block_id.to_str()` -> `<< block_id`
- touched high-risk files: validator/consensus/bridge.cpp, validator/consensus/bus.cpp, validator/consensus/chain-state.cpp, validator/consensus/private-overlay.cpp, validator/full-node-custom-overlays.cpp, validator/full-node-fast-sync-overlays.cpp, validator/full-node-serializer.cpp, validator/full-node-shard.cpp, validator/impl/collator.cpp, validator/impl/liteserver.cpp, validator/impl/out-msg-queue-proof.cpp, validator/manager-disk.cpp, validator/manager-hardfork.cpp, validator/manager-init.cpp, validator/manager.cpp, validator/shard-client.cpp

### 24. `1ab4e4a35ed1cab97e83e32ecd1c2da131285694`
- date: 2026-05-07T02:32:00-04:00
- author: Dan Klishch
- subject: Remove a bunch of unused includes from validator/consensus/bus.h (#2350)
- touched high-risk files: validator/consensus/bridge.cpp, validator/consensus/bus.h, validator/consensus/simplex/db.cpp

### 25. `9fba0d8e3cba01803c4b020f7f1b66efb86142bc`
- date: 2026-05-06T17:09:07+03:00
- author: EmelyanenkoK
- subject: Cap validator set total weight (#2343)
- touched high-risk files: validator/consensus/bridge.cpp, validator/consensus/simplex/certificate.cpp, validator/consensus/simplex/pool.cpp

### 26. `b93d647ff672ee2854c68672a8dc79e1af412d41`
- date: 2026-05-06T02:12:36-04:00
- author: Dan Klishch
- subject: Remove old-style BlockId{,Ext} & co. formatting
- touched high-risk files: validator/full-node-shard.cpp, validator/manager-disk.cpp, validator/manager-hardfork.cpp, validator/manager-init.cpp, validator/manager.cpp, validator/shard-client.cpp

### 27. `39dbc14a6fda466d37c013c9fc111b1db2a38708`
- date: 2026-05-06T04:34:03-04:00
- author: Dan Klishch
- subject: Do not treat Simplex slots unaccepted by manager as normal (#2348)
- touched high-risk files: validator/consensus/simplex/stats.cpp

### 28. `759fc825aa41ab22258a19e792bb662ad50057ed`
- date: 2026-04-30T08:45:09-04:00
- author: Dan Klishch
- subject: Remove catchain (#2301)
- touched high-risk files: catchain/CMakeLists.txt, catchain/catchain-block.cpp, catchain/catchain-block.hpp, catchain/catchain-received-block.cpp, catchain/catchain-received-block.h, catchain/catchain-received-block.hpp, catchain/catchain-receiver-interface.h, catchain/catchain-receiver-source.cpp, catchain/catchain-receiver-source.h, catchain/catchain-receiver-source.hpp, catchain/catchain-receiver.cpp, catchain/catchain-receiver.h, catchain/catchain-receiver.hpp, catchain/catchain-types.h, catchain/catchain.cpp, catchain/catchain.h, catchain/catchain.hpp, validator-session/CMakeLists.txt, validator-session/candidate-serializer.cpp, validator-session/persistent-vector.cpp, validator-session/persistent-vector.h, validator-session/validator-session-description.cpp, validator-session/validator-session-description.h, validator-session/validator-session-description.hpp, validator-session/validator-session-round-attempt-state.cpp, validator-session/validator-session-round-attempt-state.h, validator-session/validator-session-state.cpp, validator-session/validator-session-state.h, validator-session/validator-session-types.cpp, validator-session/validator-session-types.h, validator-session/validator-session.cpp, validator-session/validator-session.h, validator-session/validator-session.hpp, validator/consensus/block-producer.cpp, validator/consensus/block-validator.cpp, validator/consensus/bridge.cpp, validator/consensus/simplex/bus.h, validator/consensus/simplex/metric-collector.cpp, validator/consensus/simplex/stats.cpp, validator/consensus/simplex/stats.h, validator/impl/collator.cpp, validator/manager.cpp

### 29. `1b05d6210de0d806570e7c2747ff011010c860f8`
- date: 2026-04-27T10:38:22+03:00
- author: SpyCheese
- subject: Broadcast limiting in overlays and other changes in node
- touched high-risk files: adnl/adnl-ext-connection.cpp, adnl/adnl-peer.cpp, adnl/adnl-peer.hpp, overlay/broadcast-fec.cpp, overlay/broadcast-fec.hpp, overlay/broadcast-simple.cpp, overlay/broadcast-twostep.cpp, overlay/overlay.cpp, overlay/overlay.hpp, overlay/overlays.h, rldp2/InboundTransfer.cpp, rldp2/InboundTransfer.h, rldp2/RldpConnection.cpp, rldp2/rldp-in.hpp, rldp2/rldp.cpp, validator/full-node-shard.cpp, validator/impl/liteserver.cpp, validator/manager.cpp

### 30. `3876263aefc892d45b05c3e5468dcd29a551b50d`
- date: 2026-04-26T11:30:32+03:00
- author: EmelyanenkoK
- subject: Auto sign (#2333)
- touched high-risk files: validator/full-node-shard.cpp, validator/full-node.cpp

### 31. `f44fe14b354e851308ba11727b6e702615cf5523`
- date: 2026-04-25T14:45:44+03:00
- author: SpyCheese
- subject: Improve handling of peers in public overlay (#2328)
- touched high-risk files: overlay/overlay-peers.cpp, overlay/overlay.cpp, overlay/overlay.hpp, overlay/overlays.h

### 32. `675058f0eb7757736be64723d8bb0d8356a0fa57`
- date: 2026-04-23T14:41:19+03:00
- author: SpyCheese
- subject: Change twostep broadcast parameters
- touched high-risk files: overlay/broadcast-twostep.cpp

### 33. `1486f2b87180291da1fe4fcd2c7e7d9a78c4c746`
- date: 2026-04-21T11:13:02+03:00
- author: SpyCheese
- subject: Fix rebroadcasts (#2320)
- touched high-risk files: overlay/broadcast-fec.cpp

### 34. `55559f7151dbbf7f18235fb6f991a0068a17be23`
- date: 2026-04-20T14:53:57+03:00
- author: SpyCheese
- subject: Fix LS last state, allow quic in custom overlays (#2310)
- touched high-risk files: validator/full-node-custom-overlays.cpp, validator/full-node.cpp, validator/manager.cpp

### 35. `453dba2f273728d6420234f24d3b258e435f3cbc`
- date: 2026-04-13T16:56:38+03:00
- author: Evgeny Kapun
- subject: Add #pragma once to header files and enforce via CI (#2289)
- touched high-risk files: validator/consensus/simplex/stats.h, validator/consensus/stats.h

### 36. `79ead2b395807543cc95da9e286f6cd32a0b8084`
- date: 2026-04-06T21:11:45+03:00
- author: SpyCheese
- subject: Always enable quic server on validators (#2291)
- touched high-risk files: validator/full-node-fast-sync-overlays.cpp

### 37. `0d34f2d627325120e3375710ede58d935eb57afb`
- date: 2026-04-06T20:40:55+03:00
- author: SpyCheese
- subject: Mark block as overloaded based on collation time (#2290)
- touched high-risk files: validator/impl/collator.cpp

### 38. `04d8810c8acebc71498fa1a532c0893a620cf6c4`
- date: 2026-04-06T17:10:29+03:00
- author: SpyCheese
- subject: Fix loading external messages without wait_externals_until (#2288)
- touched high-risk files: validator/impl/collator.cpp, validator/manager-disk.cpp, validator/manager-hardfork.cpp

### 39. `cec03a85cfe9b4a25cefde6be1c928984f90579d`
- date: 2026-04-06T12:54:49+03:00
- author: EmelyanenkoK
- subject: Fix adnl limiter cleanup (#2287)
- touched high-risk files: adnl/adnl-local-id.cpp, adnl/utils.hpp

### 40. `68c8b082effda1696a8b4b8bc37e5afa1c3cac7d`
- date: 2026-04-06T06:39:32+00:00
- author: EmelyanenkoK
- subject: Format C/C++ files for lint
- touched high-risk files: overlay/overlay.cpp, validator/manager-disk.cpp, validator/manager-hardfork.cpp, validator/manager.cpp

### 41. `c55dbc8c9072450979d8b2ea2e6df5e765b29ee2`
- date: 2026-04-05T13:33:59-04:00
- author: Dan Klishch
- subject: Add perf counter for sync post-timeout collation work
- touched high-risk files: validator/impl/collator.cpp

### 42. `4a74fc6c0f51608c72516ea9afcefefeca60bf8c`
- date: 2026-04-04T23:13:53-04:00
- author: Dan Klishch
- subject: Do not overwhelm collator with queued external messages
- touched high-risk files: validator/impl/collator.cpp, validator/manager-disk.cpp, validator/manager-hardfork.cpp, validator/manager.cpp

### 43. `60cc8ca257f3043d701b7fbf43a72054eb171c47`
- date: 2026-04-05T17:27:20+03:00
- author: SpyCheese
- subject: Changes in block-producer
- touched high-risk files: validator/consensus/block-producer.cpp

### 44. `64f1b1f95f20f625a7f6836f8306512328109e95`
- date: 2026-04-06T09:01:05+03:00
- author: EmelyanenkoK
- subject: Add Norh hash mempool with purging (#2285)
- touched high-risk files: validator/manager-disk.cpp, validator/manager.cpp

### 45. `33ebbd8c2eaf18275b8d87cfcbefce6919f33b73`
- date: 2026-04-06T09:00:18+03:00
- author: SpyCheese
- subject: Overlays improvements (#2268)
- touched high-risk files: catchain/catchain-receiver.cpp, overlay/broadcast-fec.cpp, overlay/broadcast-simple.cpp, overlay/broadcast-twostep.cpp, overlay/broadcast-twostep.hpp, overlay/overlay-manager.cpp, overlay/overlay-peers.cpp, overlay/overlay.cpp, overlay/overlay.hpp, overlay/overlays.h, validator/consensus/private-overlay.cpp, validator/consensus/simplex/candidate-resolver.cpp, validator/full-node-custom-overlays.cpp, validator/full-node-fast-sync-overlays.cpp, validator/full-node-shard.cpp

### 46. `b54ea04c57dcfbf55faef1664df09241e69bb811`
- date: 2026-04-06T01:58:39-04:00
- author: Dan Klishch
- subject: Add min_block_interval_ms Simplex param to cap block rate (#2267)
- touched high-risk files: validator/consensus/simplex/consensus.cpp, validator/consensus/simplex/state-resolver.cpp

### 47. `a6298cf27004c8ea0d9a30fa2149ef839bb28807`
- date: 2026-04-06T08:57:55+03:00
- author: SpyCheese
- subject: Adnl limits (#2261)
- touched high-risk files: adnl/adnl-local-id.cpp, adnl/adnl-local-id.h, adnl/adnl-peer-table.cpp, adnl/adnl-peer-table.h, adnl/adnl-peer-table.hpp, adnl/adnl-peer.cpp, adnl/adnl-peer.hpp, adnl/adnl.h, adnl/utils.cpp, overlay/overlay-peers.cpp, overlay/overlay.hpp

### 48. `aa6f67df6bd4b2370a3692eeeed1bb0d229029a6`
- date: 2026-04-06T08:55:05+03:00
- author: SpyCheese
- subject: Changes in collator and simplex (#2180)
- touched high-risk files: validator/consensus/block-producer.cpp, validator/impl/collator.cpp, validator/manager-disk.cpp, validator/manager-hardfork.cpp, validator/manager.cpp

### 49. `75c307676ae40951f0be4bd4468d47393dbeffc9`
- date: 2026-04-04T16:14:24+01:00
- author: birydrad
- subject: Quic ratelimit (#2257)
- touched high-risk files: adnl/utils.hpp

### 50. `2d114a51efd67a89da7c251e778f5a8f5cb20085`
- date: 2026-04-01T14:39:21+03:00
- author: SpyCheese
- subject: Antispam in simplex overlay (#2242)
- touched high-risk files: overlay/broadcast-twostep.cpp, overlay/overlay.cpp, overlay/overlay.hpp, overlay/overlays.h, validator/consensus/bus.cpp, validator/consensus/bus.h, validator/consensus/private-overlay.cpp, validator/consensus/simplex/pool.cpp

### 51. `15db42fff1799118df533bb6bc4fba2198c8de31`
- date: 2026-04-01T08:55:27+03:00
- author: SpyCheese
- subject: Refactor and fix ValidatorManagerMasterchainStarter (#2207)
- touched high-risk files: validator/manager-init.cpp

### 52. `98cd5457e504806fda11132192fffb553ce44cf9`
- date: 2026-03-31T20:27:42+03:00
- author: SpyCheese
- subject: Bugfixes in liteserver and fullnode (#2260)
- touched high-risk files: overlay/broadcast-simple.cpp, overlay/overlay-peers.cpp, validator/consensus/types.cpp, validator/impl/liteserver.cpp

### 53. `1de01a657855063efee0ced0fcd2805ae198a140`
- date: 2026-03-30T23:13:31+03:00
- author: SpyCheese
- subject: Send shard block desc in fast-sync overlay without twostep (#2254)
- touched high-risk files: overlay/broadcast-fec.cpp, overlay/broadcast-simple.cpp, overlay/broadcast-twostep.cpp, overlay/overlay-id.hpp, overlay/overlay-manager.cpp, overlay/overlay-peers.cpp, overlay/overlay.cpp, overlay/overlays.h, validator/consensus/types.cpp, validator/full-node-fast-sync-overlays.cpp

### 54. `07d3e5b64818001451f3f2335a5201b93235c80e`
- date: 2026-03-30T10:21:07+03:00
- author: SpyCheese
- subject: Weight heavy full-node ratelimit by chunk size (#2250)
- touched high-risk files: adnl/adnl-ext-server.cpp, validator/full-node-shard.cpp

### 55. `9b18a89bd82de61c29cecc84ddd1c4a899074176`
- date: 2026-03-30T10:15:31+03:00
- author: SpyCheese
- subject: Better check for finalized blocks in StateResolver (#2248)
- touched high-risk files: validator/consensus/simplex/state-resolver.cpp

### 56. `8a42d4bd839c47ba676684ac77888e74296dbaf9`
- date: 2026-03-28T07:57:56+03:00
- author: SpyCheese
- subject: Improve getting mtu for streams in quic (#2232)
- touched high-risk files: adnl/adnl-sender-ex.cpp, adnl/adnl-sender-ex.h

### 57. `21260cad487367456633a87279c01e8b48f14a89`
- date: 2026-03-27T22:23:21+03:00
- author: EmelyanenkoK
- subject: Merge branch 'testnet' into broadcast-patch
- touched high-risk files: (no path output)

### 58. `7b12ebd2a2e101d576385f38ee0fe86317bff793`
- date: 2026-03-26T21:08:00-04:00
- author: Dan Klishch
- subject: Check certificate signatures only after cheap semantic checks
- touched high-risk files: validator/consensus/simplex/certificate.cpp

### 59. `720a9c6bb24904512f21acde54dc1c73a647504b`
- date: 2026-03-26T21:02:47-04:00
- author: Dan Klishch
- subject: Allow to vote Notar on slots for which we observed Notar already
- touched high-risk files: validator/consensus/simplex/pool.cpp

### 60. `8736d512d7e4462984965897b456469bc051cf06`
- date: 2026-03-26T20:42:18-04:00
- author: Dan Klishch
- subject: Temporarily ban peers that send bad Simplex votes/certificates
- touched high-risk files: validator/consensus/simplex/pool.cpp

### 61. `bc8b51f733f0e5c25b0ed4d118e25f469167a0a3`
- date: 2026-03-26T19:55:16-04:00
- author: Dan Klishch
- subject: Limit egress allocated to standstill resolution
- touched high-risk files: validator/consensus/simplex/pool.cpp

### 62. `dcce4621ed00cb3bb5c9930bb2be6b89909efc85`
- date: 2026-03-26T18:08:50-04:00
- author: Dan Klishch
- subject: Rate-limit consensus.simplex.requestCandidate requests
- touched high-risk files: validator/consensus/simplex/candidate-resolver.cpp

### 63. `a871e858394aa1ee611e9ad492c64222e00a202a`
- date: 2026-02-26T23:41:42-05:00
- author: Dan Klishch
- subject: Allow to construct ChainState directly from a tip
- touched high-risk files: validator/consensus/chain-state.cpp, validator/consensus/chain-state.h

### 64. `90cfbe6b232b89540cf0b5c31bd6f63a9fbd5c2c`
- date: 2026-03-25T14:51:42-04:00
- author: Dan Klishch
- subject: Fix off-by-one error in unknown overlay packet buffer
- touched high-risk files: overlay/overlay-manager.cpp

### 65. `6ccb2e6e7e3a6908da84d54749099e322e0ad1d9`
- date: 2026-03-25T12:21:20-04:00
- author: Dan Klishch
- subject: Do not spam requestCandidate requests in case of synchronous errors
- touched high-risk files: validator/consensus/simplex/candidate-resolver.cpp

### 66. `9ca6075b4c63011e816d020183feb5018224cea1`
- date: 2026-03-24T23:39:03-04:00
- author: Dan Klishch
- subject: Allow to set and query noncritical param overrides from engine console
- touched high-risk files: validator/consensus/bridge.cpp

### 67. `2e4585f5045c1993e02c482d3bb768a9ce04e688`
- date: 2026-03-24T22:25:28-04:00
- author: Dan Klishch
- subject: Invent "noncritical params" for Simplex timing & DoS protection params
- touched high-risk files: validator/consensus/block-producer.cpp, validator/consensus/bridge.cpp, validator/consensus/bus.cpp, validator/consensus/bus.h, validator/consensus/simplex/bus.cpp, validator/consensus/simplex/bus.h, validator/consensus/simplex/candidate-resolver.cpp, validator/consensus/simplex/consensus.cpp, validator/consensus/simplex/db.cpp, validator/consensus/simplex/pool.cpp

### 68. `cc84d8613c672b61fa4224800f52a53648d8b47a`
- date: 2026-03-27T19:56:08+03:00
- author: SpyCheese
- subject: Improve consensus DB cleanup (#2237)
- touched high-risk files: validator/consensus/bridge.cpp, validator/consensus/bus.h

### 69. `e2f2b2e0bab9f7a20fd23fc7f0428994c28fbf68`
- date: 2026-03-27T14:29:55+03:00
- author: SpyCheese
- subject: Fix twostep broadcasts
- touched high-risk files: overlay/broadcast-twostep.cpp

### 70. `6173b26819fba268938cffe9dc7f90c72d5b7c63`
- date: 2026-03-23T13:15:11+03:00
- author: SpyCheese
- subject: Don't rebroadcast more than one part per twostep broadcast
- touched high-risk files: overlay/broadcast-twostep.cpp

### 71. `5869aaf7c6cba95233842743a198dd49c57ad632`
- date: 2026-03-23T13:12:21+03:00
- author: SpyCheese
- subject: Include total data size in twostep broadcast id
- touched high-risk files: overlay/broadcast-twostep.cpp

### 72. `13af811a3d7228b00514b790000aae71f2d667f4`
- date: 2026-03-23T12:49:15+03:00
- author: SpyCheese
- subject: Ignore port in adnl local id rate limiter
- touched high-risk files: adnl/adnl-local-id.cpp

### 73. `05cc7a174a0a7ae46cec36f60d7d1a3e8b76d041`
- date: 2026-03-26T21:49:17-04:00
- author: Dan Klishch
- subject: Do not allow duplicate or unexpected candidate broadcasts
- touched high-risk files: validator/consensus/bus.cpp, validator/consensus/bus.h, validator/consensus/private-overlay.cpp, validator/consensus/simplex/pool.cpp, validator/consensus/types.cpp, validator/consensus/types.h

### 74. `e21a3f6a476e1f393b5ca262d94c902a94d2aa7d`
- date: 2026-03-23T10:11:24+03:00
- author: SpyCheese
- subject: Better broadcast deduplication and filtering
- touched high-risk files: overlay/broadcast-fec.cpp, overlay/broadcast-simple.cpp, overlay/broadcast-twostep.cpp, overlay/broadcast-twostep.hpp, overlay/overlay-manager.cpp, overlay/overlay-manager.h, overlay/overlay-peers.cpp, overlay/overlay.cpp, overlay/overlay.h, overlay/overlay.hpp, overlay/overlays.h, validator/consensus/private-overlay.cpp

### 75. `83139caefc0fce0ff7fdc08052577c051a3350b2`
- date: 2026-03-26T21:08:00-04:00
- author: Dan Klishch
- subject: Check certificate signatures only after cheap semantic checks
- touched high-risk files: validator/consensus/simplex/certificate.cpp

### 76. `5cb9cceed1f52f3a5fc115b7334ed3b28d8eb48c`
- date: 2026-03-26T21:02:47-04:00
- author: Dan Klishch
- subject: Allow to vote Notar on slots for which we observed Notar already
- touched high-risk files: validator/consensus/simplex/pool.cpp

### 77. `ee2e9ff4a63c27521a3bff2de1690686b8308132`
- date: 2026-03-26T20:42:18-04:00
- author: Dan Klishch
- subject: Temporarily ban peers that send bad Simplex votes/certificates
- touched high-risk files: validator/consensus/simplex/pool.cpp

### 78. `cdc7690bf9f138af989b493f51b4a0328ee8caf6`
- date: 2026-03-26T19:55:16-04:00
- author: Dan Klishch
- subject: Limit egress allocated to standstill resolution
- touched high-risk files: validator/consensus/simplex/pool.cpp

### 79. `59e366862087cd90f53da8494cd7a1d77bbde62c`
- date: 2026-03-26T18:08:50-04:00
- author: Dan Klishch
- subject: Rate-limit consensus.simplex.requestCandidate requests
- touched high-risk files: validator/consensus/simplex/candidate-resolver.cpp

### 80. `37ec43a60c76be4f20673f150bc71b07964f760b`
- date: 2026-02-26T23:41:42-05:00
- author: Dan Klishch
- subject: Allow to construct ChainState directly from a tip
- touched high-risk files: validator/consensus/chain-state.cpp, validator/consensus/chain-state.h

### 81. `c09269f756fb1e3bdaa525a0940df3b91aff7e00`
- date: 2026-03-25T14:51:42-04:00
- author: Dan Klishch
- subject: Fix off-by-one error in unknown overlay packet buffer
- touched high-risk files: overlay/overlay-manager.cpp

### 82. `fb2fb77d1e4ce94530cc57d4d904b89816049ce6`
- date: 2026-03-25T12:21:20-04:00
- author: Dan Klishch
- subject: Do not spam requestCandidate requests in case of synchronous errors
- touched high-risk files: validator/consensus/simplex/candidate-resolver.cpp

### 83. `2f1c75eac597c63a4dffc0710ae80e8c0e3d905b`
- date: 2026-03-24T22:25:28-04:00
- author: Dan Klishch
- subject: Invent "noncritical params" for Simplex timing & DoS protection params
- touched high-risk files: validator/consensus/block-producer.cpp, validator/consensus/bridge.cpp, validator/consensus/bus.cpp, validator/consensus/bus.h, validator/consensus/simplex/bus.cpp, validator/consensus/simplex/bus.h, validator/consensus/simplex/candidate-resolver.cpp, validator/consensus/simplex/consensus.cpp, validator/consensus/simplex/db.cpp, validator/consensus/simplex/pool.cpp

### 84. `535441cc7c7b2585a628ce5b8977c2da9bd0b070`
- date: 2026-03-25T11:15:09-04:00
- author: Dan Klishch
- subject: Remove suppression_mappings.txt (#2229)
- touched high-risk files: catchain/catchain-receiver.cpp, validator-session/candidate-serializer.cpp, validator-session/validator-session.cpp, validator/consensus/null/bus.h, validator/consensus/null/consensus.cpp, validator/consensus/simplex/certificate.cpp, validator/consensus/stats.cpp, validator/full-node-fast-sync-overlays.cpp, validator/impl/liteserver.cpp

### 85. `4d49b714ecfbc2e1bf23e75b9fadc75399122fb0`
- date: 2026-03-19T07:55:08+01:00
- author: Oleg Vallas
- subject: Fix empty collated data (#2211)
- touched high-risk files: validator-session/candidate-serializer.cpp

### 86. `39731934d4fbbf6dce4d84509afed424a44c853c`
- date: 2026-03-19T09:50:56+03:00
- author: EmelyanenkoK
- subject: Removing null-consensus (#2209)
- touched high-risk files: validator/consensus/bridge.cpp, validator/consensus/null/bus.h, validator/consensus/null/consensus.cpp

### 87. `c1f06c8304c79a78b4f991e2cd8c3b2a38e1a9d7`
- date: 2026-03-18T20:32:31+03:00
- author: SpyCheese
- subject: Store ip:port for quic in AdnlAddressList (#2184)
- touched high-risk files: adnl/adnl-address-list.cpp, adnl/adnl-address-list.h, adnl/adnl-address-list.hpp, adnl/adnl-peer.cpp

### 88. `3abee30359120c51bfbbd05a589ae31ffa7d453d`
- date: 2026-03-17T18:29:45+03:00
- author: SpyCheese
- subject: Various changes in node (#2208)
- touched high-risk files: adnl/adnl-local-id.cpp, adnl/adnl-local-id.h, adnl/utils.hpp, overlay/broadcast-twostep.cpp, rldp2/InboundTransfer.cpp, rldp2/InboundTransfer.h, rldp2/RldpConnection.cpp, validator/full-node-shard.cpp, validator/impl/collator.cpp, validator/impl/liteserver.cpp, validator/manager.cpp

### 89. `3bb6abcdbe2d810d6b526ee037bc1851011f7254`
- date: 2026-03-13T16:11:54-04:00
- author: Dan Klishch
- subject: Remove Simplex DB migrations (#2203)
- touched high-risk files: validator/consensus/bridge.cpp, validator/consensus/manager-facade.h, validator/consensus/simplex/candidate-resolver.cpp, validator/consensus/simplex/db.cpp

### 90. `a0f3d286d96523fd407fc2593e999f02d584f264`
- date: 2026-03-12T10:46:56-04:00
- author: Dan Klishch
- subject: Mark NullConsensusImpl::start_up as overriden
- touched high-risk files: validator/consensus/null/consensus.cpp

### 91. `7c45a2c9a9d041736eed355fdf100d5e18b88286`
- date: 2026-03-12T17:07:53+03:00
- author: SpyCheese
- subject: Cleanup actor-owned promises in tear_down
- touched high-risk files: validator/consensus/block-validator.cpp, validator/consensus/null/consensus.cpp, validator/consensus/simplex/candidate-resolver.cpp, validator/consensus/simplex/pool.cpp, validator/consensus/simplex/state-resolver.cpp

### 92. `8600279a4b4179f4a35a0d21fd096715c3ab0dd1`
- date: 2026-03-12T13:09:20+03:00
- author: SpyCheese
- subject: Assert on DB write errors in Simplex
- touched high-risk files: validator/consensus/bridge.cpp

### 93. `f31e44fa243cd59760f448cd4a995c4907da5746`
- date: 2026-03-11T23:01:42-04:00
- author: Dan Klishch
- subject: Cache block candidates produced by Simplex in manager
- touched high-risk files: validator/consensus/block-producer.cpp, validator/consensus/block-validator.cpp, validator/consensus/bridge.cpp, validator/consensus/manager-facade.h

### 94. `2d859729e483ea11931ee44746ee6bff8e8c8a9b`
- date: 2026-03-11T22:51:28-04:00
- author: Dan Klishch
- subject: Store block candidates in Simplex db
- touched high-risk files: validator/consensus/simplex/bus.cpp, validator/consensus/simplex/bus.h, validator/consensus/simplex/candidate-resolver.cpp, validator/consensus/simplex/consensus.cpp, validator/consensus/simplex/db.cpp

### 95. `b09a6b6f96fa69038bbdea48674f5d9f60695d7f`
- date: 2026-03-11T21:26:31-04:00
- author: Dan Klishch
- subject: Add option to only cache candidate during Manager::set_block_candidate
- touched high-risk files: validator/consensus/bridge.cpp, validator/impl/collator.cpp, validator/manager-disk.cpp, validator/manager.cpp

### 96. `01d6e1cda740c53d90987cc7a92855f6ee8595cd`
- date: 2026-03-11T16:56:00+03:00
- author: SpyCheese
- subject: Set broadcast size limit from config
- touched high-risk files: validator/consensus/private-overlay.cpp

### 97. `1194034a1e4f657120dd465ab126cae5afb5f6f3`
- date: 2026-03-11T21:17:36-04:00
- author: Dan Klishch
- subject: Save certificates before acting on them in simplex::Pool
- touched high-risk files: validator/consensus/bridge.cpp, validator/consensus/simplex/bus.cpp, validator/consensus/simplex/bus.h, validator/consensus/simplex/certificate.cpp, validator/consensus/simplex/certificate.h, validator/consensus/simplex/consensus.cpp, validator/consensus/simplex/db.cpp, validator/consensus/simplex/pool.cpp

### 98. `37e0c8a635337d06b1e74dc122b0c70acbbb308a`
- date: 2026-03-10T16:22:11-04:00
- author: Dan Klishch
- subject: Increase max allowed size of a response for a private overlay query
- touched high-risk files: validator/consensus/private-overlay.cpp

### 99. `7aea0d1819d85c408233e707b0d3e8b20e5651e1`
- date: 2026-03-10T12:39:22-04:00
- author: Dan Klishch
- subject: Do not start generation for stale windows
- touched high-risk files: validator/consensus/block-producer.cpp, validator/consensus/simplex/consensus.cpp

### 100. `b668cf36e5bda409f78b21f1a180623c657d373e`
- date: 2026-03-10T12:33:33-04:00
- author: Dan Klishch
- subject: Remove unused OurLeaderWindowAborted event
- touched high-risk files: validator/consensus/block-producer.cpp, validator/consensus/bus.cpp, validator/consensus/bus.h

### 101. `94a6bd6d27c3558fdff9928263b0e9a430794e60`
- date: 2026-03-10T11:28:17-04:00
- author: Dan Klishch
- subject: Revert bogus change in BlockValidator
- touched high-risk files: validator/consensus/block-validator.cpp

### 102. `410e49bbe32d3c5924139d3dcfa603fce0df9906`
- date: 2026-02-24T01:01:07-05:00
- author: Dan Klishch
- subject: Move bus runtime into td::actor namespace from ton::runtime
- touched high-risk files: validator/consensus/block-accepter.cpp, validator/consensus/block-producer.cpp, validator/consensus/block-validator.cpp, validator/consensus/bridge.cpp, validator/consensus/bus.h, validator/consensus/null/bus.h, validator/consensus/null/consensus.cpp, validator/consensus/private-overlay.cpp, validator/consensus/simplex/bus.h, validator/consensus/simplex/candidate-resolver.cpp, validator/consensus/simplex/consensus.cpp, validator/consensus/simplex/metric-collector.cpp, validator/consensus/simplex/pool.cpp, validator/consensus/simplex/state-resolver.cpp, validator/consensus/trace-collector.cpp

### 103. `a8827f31862aa5abf479cd149c8386196ee4e0e0`
- date: 2026-02-24T00:55:57-05:00
- author: Dan Klishch
- subject: Move bus runtime into tdactor
- touched high-risk files: validator/consensus/bridge.cpp, validator/consensus/bus.h, validator/consensus/runtime.h

### 104. `d9bc8b9520964817a704949cd6eb50527f595559`
- date: 2026-03-09T16:12:23+03:00
- author: SpyCheese
- subject: Fix inconsistent treating # as (un)singned in TL-B and other fixes (#2191)
- touched high-risk files: adnl/adnl-local-id.cpp, adnl/adnl-local-id.h, adnl/adnl-node-id.hpp, adnl/adnl-peer-table.cpp, adnl/adnl-peer.cpp, overlay/broadcast-fec.cpp, overlay/overlay-manager.cpp, overlay/overlay-peers.cpp, overlay/overlay.hpp, rldp2/rldp.cpp, validator/consensus/block-validator.cpp, validator/consensus/chain-state.cpp, validator/consensus/null/consensus.cpp, validator/consensus/private-overlay.cpp, validator/consensus/simplex/consensus.cpp, validator/full-node-serializer.cpp, validator/full-node-shard.cpp, validator/impl/collator.cpp, validator/impl/liteserver.cpp, validator/impl/out-msg-queue-proof.cpp, validator/manager.cpp

### 105. `024a023bd0bfbc6eda577f009abe7a2c5208b104`
- date: 2026-02-28T16:36:09+03:00
- author: EmelyanenkoK
- subject: Revert "Cleanup outdated consensus dbs on startup (#2168)" (#2175)
- touched high-risk files: validator/consensus/bridge.cpp, validator/manager.cpp

### 106. `8aca1e2fa259a9d7ac96485a23977f8933678cc9`
- date: 2026-02-28T00:23:53-05:00
- author: Dan Klishch
- subject: Fix some suppressed warnings (#2170)
- touched high-risk files: overlay/overlay.cpp, validator/impl/liteserver.cpp

### 107. `905e29b3e07eb65785f9215f21571574a3b9aa4f`
- date: 2026-02-28T00:22:52-05:00
- author: Dan Klishch
- subject: Do not start simplex in already destroyed groups (#2172)
- touched high-risk files: validator/consensus/bridge.cpp

### 108. `7dd84d01d8b654385a94502dc6f3f5b3245bd407`
- date: 2026-02-24T13:52:22-05:00
- author: Dan Klishch
- subject: Cast FinalVote even if validation takes too long and we see NotarCert
- touched high-risk files: validator/consensus/simplex/consensus.cpp

### 109. `cfd8850c836001702aa6e4d63caf1fb7a8810233`
- date: 2026-02-24T12:07:26-05:00
- author: Dan Klishch
- subject: Rebroadcast finalization certificates
- touched high-risk files: validator/consensus/simplex/pool.cpp

### 110. `9aac62b84d3b8f45ad59e5eeb64885115537d898`
- date: 2026-02-24T11:30:31-05:00
- author: Dan Klishch
- subject: Do not notarize forks with real blocks in masterchain in simplex
- touched high-risk files: validator/consensus/block-validator.cpp

### 111. `7810e7af464af5761b7d6e9208f78069048d7642`
- date: 2026-02-24T11:03:05-05:00
- author: Dan Klishch
- subject: Provide gen_utime_exact for already-finalized blocks
- touched high-risk files: validator/consensus/simplex/state-resolver.cpp

### 112. `8e2fe3f165a27a2d0c44276b5664c1b80d0bdfbd`
- date: 2026-02-21T15:48:49-05:00
- author: Dan Klishch
- subject: Move state resolver into a separate actor
- touched high-risk files: validator/consensus/bridge.cpp, validator/consensus/simplex/bus.cpp, validator/consensus/simplex/bus.h, validator/consensus/simplex/consensus.cpp, validator/consensus/simplex/state-resolver.cpp

### 113. `efcc0fdae5308ba151257e5e3cf1e3a2ee41645b`
- date: 2026-02-24T10:41:05-05:00
- author: Dan Klishch
- subject: Limit time for transaction processing by target_rate in simplex
- touched high-risk files: validator/consensus/block-producer.cpp

### 114. `3394867cc19d10fb8886b75493b7a797b09f3469`
- date: 2026-02-08T20:53:28+03:00
- author: SpyCheese
- subject: Expose "soft" timeout in collator
- touched high-risk files: validator/consensus/bridge.cpp, validator/impl/collator.cpp, validator/manager-disk.cpp, validator/manager-hardfork.cpp

### 115. `3c0cae03c12b4a7eb06dce91822b016c7da5d312`
- date: 2026-02-21T00:27:03-05:00
- author: Dan Klishch
- subject: Adaptively increase first block timeout if we voted for skip
- touched high-risk files: validator/consensus/simplex/bus.h, validator/consensus/simplex/consensus.cpp

### 116. `7c06e37800da69961c0404f0b4b4cabb3dd1cc4c`
- date: 2026-02-21T00:19:02-05:00
- author: Dan Klishch
- subject: Massively simplify simplex::ConsensusState
- touched high-risk files: validator/consensus/simplex/consensus.cpp, validator/consensus/simplex/pool.cpp, validator/consensus/simplex/state.h

### 117. `84707bc222b6d79db1343463a558120becf126d4`
- date: 2026-02-18T06:41:20+00:00
- author: Evgeny Kapun
- subject: Prevent concurrent calls to maybe_publish_new_leader_window
- touched high-risk files: validator/consensus/simplex/pool.cpp

### 118. `be3a835fda82444cd172c9c7544d2c7bbef81ab6`
- date: 2026-02-17T21:33:50+00:00
- author: Evgeny Kapun
- subject: Don't generate LeaderWindowObservation before start
- touched high-risk files: validator/consensus/simplex/pool.cpp

### 119. `f2e4cbec1b2670e7f972e7c042b7f685878807a2`
- date: 2026-02-14T21:12:45+00:00
- author: Evgeny Kapun
- subject: Simplify timeout handling in simplex::Consensus
- touched high-risk files: validator/consensus/simplex/consensus.cpp

### 120. `f8ec23118d29a6284101587d668f5a79e0d0c889`
- date: 2026-02-20T13:56:14-05:00
- author: Dan Klishch
- subject: Handle StopRequested in MetricCollector
- touched high-risk files: validator/consensus/simplex/metric-collector.cpp

### 121. `7c65de6fee7bfab43cad682a63397591c6393e6c`
- date: 2026-02-27T10:11:53+03:00
- author: SpyCheese
- subject: Cleanup outdated consensus dbs on startup (#2168)
- touched high-risk files: validator/consensus/bridge.cpp, validator/manager.cpp

### 122. `19a58073d55b593eacf1cce45f8bff159c11d154`
- date: 2026-02-27T02:08:57-05:00
- author: Dan Klishch
- subject: Fully guard td::Promise & co with concepts (#2161)
- touched high-risk files: adnl/adnl-peer.cpp, adnl/adnl-pong.cpp, catchain/catchain-receiver.cpp, validator/full-node.cpp, validator/impl/collator.cpp, validator/manager.cpp, validator/shard-client.cpp

### 123. `8b8ecc5c2125a54523025252292b8468c1bd3f7a`
- date: 2026-02-24T17:05:22+03:00
- author: EmelyanenkoK
- subject: Merge pull request #1876 from ton-blockchain/archive-import
- touched high-risk files: (no path output)

### 124. `6b36f2e3d7410b3fa6f7f1770ee77480a5be327a`
- date: 2026-02-24T17:01:44+03:00
- author: SpyCheese
- subject: AdnlSenderEx interface + some QUIC improvoments (#2165)
- touched high-risk files: adnl/CMakeLists.txt, adnl/adnl-sender-ex.cpp, adnl/adnl-sender-ex.h, catchain/catchain-receiver-interface.h, catchain/catchain-receiver.cpp, catchain/catchain-receiver.hpp, catchain/catchain.cpp, catchain/catchain.h, catchain/catchain.hpp, overlay/overlay.cpp, overlay/overlay.hpp, overlay/overlays.h, rldp2/CMakeLists.txt, rldp2/rldp-in.hpp, rldp2/rldp-utils.h, rldp2/rldp.cpp, rldp2/rldp.h, validator-session/validator-session.cpp, validator-session/validator-session.h, validator-session/validator-session.hpp, validator/consensus/bridge.cpp, validator/consensus/bus.h, validator/consensus/private-overlay.cpp, validator/full-node-custom-overlays.cpp, validator/full-node-fast-sync-overlays.cpp, validator/manager.cpp

### 125. `81a13814360eee7e24d698504e83cb78bf6dbd0d`
- date: 2026-02-24T11:13:19+03:00
- author: SpyCheese
- subject: Merge branch 'testnet' into archive-import
- touched high-risk files: (no path output)

### 126. `bc14daaf485687d5a9467b302d0bca1732d04c5a`
- date: 2026-02-24T10:28:15+03:00
- author: EmelyanenkoK
- subject: Merge pull request #2164 from ton-blockchain/master
- touched high-risk files: (no path output)

### 127. `229efd16727f1348d31edf1ed100177b9710be38`
- date: 2026-02-23T13:11:39-05:00
- author: Dan Klishch
- subject: Some tdactor cleanup (#2151)
- touched high-risk files: validator/consensus/null/consensus.cpp, validator/consensus/simplex/consensus.cpp, validator/consensus/utils.h

### 128. `3f67ce7257867943ed5a17e07f5fcae13a207aed`
- date: 2026-02-23T17:57:54+03:00
- author: SpyCheese
- subject: Optimize archive
- touched high-risk files: validator/manager.cpp

## Filtered candidates

Suspicious diffs retained for Claude/source gate: **8**

### `127d38d0f266f5a3f4aa063aa667ea6fc421430d`
- files/functions touched: rldp2/RldpConnection.cpp
- why suspicious: RLDP2 receiver part-size validation changed for network-controlled total_size/part_idx/fec metadata; needs source gate for last-part edge cases and whether bad parts are retained before rejection.
- relevant diff excerpt:
```diff
-  size_t expected_part_size =
-      part_idx + 1 == n_parts ? total_size % OutboundTransfer::part_size() : OutboundTransfer::part_size();
+  size_t expected_part_size = part_idx + 1 == n_parts && total_size % OutboundTransfer::part_size() != 0
+                                  ? total_size % OutboundTransfer::part_size()
+                                  : OutboundTransfer::part_size();
```
- likely disposition: needs Claude/source gate unless noted as already covered by closed branches.

### `1b05d6210de0d806570e7c2747ff011010c860f8`
- files/functions touched: adnl/adnl-peer.cpp; overlay/overlays.cpp; overlay/overlay-broadcast.cpp; rldp2/*; validator/full-node*.cpp; validator/impl/liteserver.cpp
- why suspicious: Large limiter/queue/broadcast/RLDP timeout changes; likely intended hardening, but touches multiple trust-boundary resource gates in one commit.
- relevant diff excerpt:
```diff
+  while (out_messages_queue_total_size_ > MAX_MESSAGE_QUEUE_TOTAL_SIZE) {
+    out_messages_queue_total_size_ -= out_messages_queue_.back().first.size();
+    out_messages_queue_.pop_back();
+    VLOG(ADNL_NOTICE) << this << ": dropping OUT message: queue is too big";
+  }
...
+  CO_TRY(overlay->get_broadcasts_limiter(src_keyhash, cert.get()).precheck_new_broadcast(broadcast->data_.size()));
...
-  overlay->get_broadcasts_limiter(src_keyhash, cert.get()).register_broadcast(broadcast->data_.size());
+  CO_TRY(overlay->get_broadcasts_limiter(src_keyhash, cert.get()).try_register_broadcast(broadcast->data_.size()));
```
- likely disposition: needs Claude/source gate unless noted as already covered by closed branches.

### `a6298cf27004c8ea0d9a30fa2149ef839bb28807`
- files/functions touched: adnl/adnl-local-id.cpp; adnl/adnl-local-id.h; adnl/adnl-peer-table.cpp
- why suspicious: ADNL receive path changed to coroutine, added per-IP unique peer/rate limit and periodic cleanup; affects externally reachable packet path before peer-table dispatch.
- relevant diff excerpt:
```diff
+td::actor::Task<> AdnlLocalId::receive_coro(td::IPAddress addr, td::BufferSlice data) {
+  InboundRateLimiter &rate_limiter = inbound_rate_limiter_[remove_port(addr)];
...
+  if (rate_limiter.recent_inbound_peers.size() >= UNIQUE_PEERS_PER_IP_LIMIT) {
+    if (!rate_limiter.recent_inbound_peers.contains(packet.from_short())) {
+      co_return td::Status::Error("too many unique peer ids from a single ip");
+    }
+  } else {
+    rate_limiter.recent_inbound_peers.insert(packet.from_short());
+  }
...
+  td::actor::send_closure(peer_table_, &AdnlPeerTable::receive_decrypted_packet, short_id_, std::move(packet),
+                          data_size);
```
- likely disposition: needs Claude/source gate unless noted as already covered by closed branches.

### `07d3e5b64818001451f3f2335a5201b93235c80e`
- files/functions touched: validator/full-node-shard.cpp; validator/full-node.cpp; adnl/adnl-ext-server.cpp; validator/manager.cpp
- why suspicious: Heavy full-node request cost weighting and ADNL ext auth nonce cap changed limiter semantics for untrusted requests.
- relevant diff excerpt:
```diff
+constexpr td::uint32 k_heavy_request_cost_unit = 1 << 21;
+size_t heavy_request_cost(td::uint64 requested_max_size) {
+  size_t cost = static_cast<size_t>((requested_max_size + k_heavy_request_cost_unit - 1) / k_heavy_request_cost_unit);
+  return cost == 0 ? 1 : cost;
+}
+size_t request_cost_for_limiter(ton_api::Function &function) {
+  ... tonNode_getArchiveSlice ... tonNode_downloadPersistentStateSliceV2 ... tonNode_downloadZeroState ...
+}
...
-  if (!limiter_->check_in(fun_ptr->get_id())) {
+  if (!limiter_->check_in(fun_ptr->get_id(), request_cost_for_limiter(*fun_ptr))) {
```
- likely disposition: needs Claude/source gate unless noted as already covered by closed branches.

### `dcce4621ed00cb3bb5c9930bb2be6b89909efc85`
- files/functions touched: validator/consensus/simplex/candidate-resolver.cpp; validator/consensus/simplex/consensus.cpp
- why suspicious: Added rate limit to consensus.simplex.requestCandidate overlay requests; network-controlled request path now has new per-peer limiter state.
- relevant diff excerpt:
```diff
+    co_await check_rate_limit(event->source);
...
+  std::map<PeerValidatorId, fullnode::LimiterWindow> rate_limiter_;
+  td::Status check_rate_limit(PeerValidatorId src) {
+    if (!rate_limiter_.contains(src)) {
+      rate_limiter_[src] = fullnode::LimiterWindow{.size = 1.0, .limit = params_.candidate_resolve_rate_limit};
+    }
+    auto &window = rate_limiter_[src];
+    auto now = td::Timestamp::now();
+    if (!window.check(now)) {
+      return td::Status::Error(ErrorCode::failure, "too many requests");
+    }
+    window.insert(now);
+    return td::Status::OK();
+  }
```
- likely disposition: needs Claude/source gate unless noted as already covered by closed branches.

### `3abee30359120c51bfbbd05a589ae31ffa7d453d`
- files/functions touched: adnl/adnl-local-id.cpp; rldp2/InboundTransfer.cpp; rldp2/RldpConnection.cpp
- why suspicious: ADNL limiter cleanup and RLDP2 inbound transfer buffering/state representation changed; affects packet-level memory and timeout behavior.
- relevant diff excerpt:
```diff
+  if (!cleanup_rate_limiter_at_) {
+    alarm_timestamp().relax(cleanup_rate_limiter_at_ = td::Timestamp::in(1.0));
+  }
...
-size_t InboundTransfer::total_size() const { return data_.size(); }
+size_t InboundTransfer::total_size() const { return total_size_; }
...
+    data_parts_.emplace_back();
...
-void InboundTransfer::finish_part(td::uint32 part_i, td::Slice data) {
+void InboundTransfer::finish_part(td::uint32 part_i, td::BufferSlice data) {
```
- likely disposition: needs Claude/source gate unless noted as already covered by closed branches.

### `e21a3f6a476e1f393b5ca262d94c902a94d2aa7d`
- files/functions touched: overlay/overlay-broadcast.cpp; overlay/overlays.cpp; overlay/overlay-broadcast.hpp
- why suspicious: Broadcast deduplication/filtering changed keys/extra metadata propagation before overlay delivery.
- relevant diff excerpt:
```diff
+        static_cast<std::int32_t>(data_size), extra.clone()));
...
-    overlay->deliver_broadcast(send_as, std::move(data));
+    overlay->deliver_broadcast(send_as, std::move(data), std::move(extra));
```
- likely disposition: needs Claude/source gate unless noted as already covered by closed branches.

### `b647a8d5fcdb48cc27eba6d1b30d3305fd1546b3`
- files/functions touched: overlay/overlay-broadcast.cpp; rldp2/RldpConnection.cpp; validator/full-node-master.cpp; validator/impl/liteserver.cpp
- why suspicious: Mixed serving/overlay/RLDP resource changes including overlay part-size guard and RLDP limit key changes.
- relevant diff excerpt:
```diff
+  if (part_size >= data_size) {
+    co_return td::Status::Error(ErrorCode::protoviolation, "too big part size");
+  }
...
-void RldpConnection::drop_limits(TransferId id) {
+void RldpConnection::drop_limits(TransferId id, bool is_inbound) {
   Limit limit;
   limit.transfer_id = id;
+  limit.is_inbound = is_inbound;
```
- likely disposition: needs Claude/source gate unless noted as already covered by closed branches.

## Explicitly excluded commits

Skipped from the suspicious set because the observed changes were docs/tests/formatting/build metadata/removals without a new active trust-boundary resource gate in the requested paths:

- `7f7ecc78306aee263b64fb24b14e25e2732704dc` — Formatting.
- `68c8b082effda1696a8b4b8bc37e5afa1c3cac7d` — Format C/C++ files for lint.
- `453dba2f273728d6420234f24d3b258e435f3cbc` — Add #pragma once in headers and enforce via CI.
- `91f26b24670a95fa6780f51b60bd6019b8afb535` — Rewrite << block_id.to_str() -> << block_id.
- `b93d647ff672ee2854c68672a8dc79e1af412d41` — Remove old-style BlockId formatting.
- `1ab4e4a35ed1cab97e83e32ecd1c2da131285694` — Remove unused includes.
- `535441cc7c7b2585a628ce5b8977c2da9bd0b070` — Remove suppression_mappings.txt.
- `4209d2dbfda6cdf866dae69c0f2519dd1f0ee5d4` — Remove adnl-proxy and all related code.
- `2a31ce147d9c2742b543be9ae8db791e6e681b30` — Remove rldp1.

## Summary

- number of commits inspected: 128
- number of suspicious diffs: 8
- runtime/network activity: none
- builds/tests: none
