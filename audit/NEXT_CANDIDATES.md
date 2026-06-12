# NEXT_CANDIDATES — TON Critical/High-only follow-up

Дата pass: 2026-06-12.

Правила фильтра: учитываем только product-path, reproducible, non-debug, non-local-only кандидаты с validator/full-node availability/liveness impact. `persistent-state download accumulation` закрыт как не подтверждённый Stage B blocker: `any_downloading_state=False`, `downloading_from_attacker_heuristic=False`, `attacker_slice_count=0`, `RUNNER_EXIT=2`.

## Cleanup / postmortem

- Удалены dedicated Stage B/persistent-state artifacts: `audit/STAGE_B_LOCAL_RUNBOOK.md`, `audit/STAGE_B_PRODUCT_PATH_RUNBOOK.md`, `audit/TON_STATE_DOWNLOAD_POC.md`, `audit/collect_target_rss.sh`, `audit/poc_download_state_accumulation.py`, `audit/run_stage_b_local.sh`, `audit/stage_b_malicious_fullnode.patch`, `audit/stage_b_seed_tool.patch`, `audit/stage_b_tontester_topology.py`.
- Внешние runtime/build логи и workdir не трогались: `/home/algetmargh/ton-stage-b-local`, `/home/algetmargh/ton-stage-b-local/stage_b_logs`, `/home/algetmargh/ton-stage-b-local/stage_b_tontester_workdir`.
- Accidental edits в `test/tontester/src` в текущем checkout не обнаружены.

Гипотеза: persistent-state accumulation.
Статус: закрыта / не подтверждена.
Причина: product-path не достигнут.
Факты: `any_downloading_state=False`, `downloading_from_attacker_heuristic=False`, `attacker_slice_count=0`, `RUNNER_EXIT=2`.
Решение: не отправлять, не тратить ещё ручные раунды без принципиально нового product-path факта.

## CAND-01 — drop — private-overlay twostep FEC incomplete-broadcast state accumulation

Candidate ID: CAND-01-twostep-fec-incomplete-state.

Verdict: `drop` для Critical/High resource-exhaustion.

Affected path:

- `validator/consensus/private-overlay.cpp`: consensus private overlay включает twostep sender и отключает legacy old broadcasts.
- `validator/consensus/simplex/pool.cpp`: precheck candidate broadcast хранит уже принятый `broadcast_id` по `slot`.
- `overlay/broadcast-twostep.cpp`: twostep receiver state создаётся только после precheck/cap.

Reason:

- Один accepted `broadcast_id` на один `slot`: повторный same-slot `broadcast_id`, отличающийся от уже принятого, отклоняется как duplicate/conflict.
- Receiver allocation происходит после precheck/cap, поэтому same-slot spam не создаёт много `BroadcastTwostep` receiver states.
- Byzantine validator не может attacker-unbounded образом варьировать product-valid slots: он ограничен expected-collator schedule, validator group/slot checks и practical future/old slot window.
- Upper bound в пределах GC window получается малым и protocol-bounded, а не attacker-unbounded.

No harness. CAND-01 закрыт; не тратить runtime harness, если не появится новый concrete product-path факт, показывающий allocation до cap или product-valid обход one-broadcast-per-slot.

## CAND-02 — maybe/drop — legacy FEC receiver state accumulation without count cap

Candidate ID: CAND-02-legacy-fec-incomplete-state.

Verdict: `drop` для consensus/private validator overlay; `maybe` только для отдельного fast-sync/custom-overlay reachability gate. Не report-ready.

Affected path:

- `overlay/overlay.cpp`: `overlay_broadcastFec` и `overlay_broadcastFecShort` принимаются только если `opts_.allow_old_broadcasts_ == true`; иначе возвращается `overlay.broadcastFec not allowed` / `overlay.broadcastFecShort not allowed`.
- `overlay/broadcast-fec.cpp`: legacy receiver path создаёт `BroadcastFec` для нового `broadcast_hash` после date/source/signature/limiter checks.
- `validator/consensus/private-overlay.cpp` и `validator/consensus/block-sync-overlay.cpp`: relevant validator private overlays явно ставят `allow_old_broadcasts_ = false`, поэтому CAND-02 не повторяет CAND-01 на consensus/private path.
- `validator/full-node-fast-sync-overlays.cpp` и `validator/full-node-custom-overlays.cpp`: old broadcasts не отключены явно в показанном setup, поэтому остаётся узкий `maybe` только для fast-sync/custom gate.

CAND-02 check answers:

1. Receiver allocation: в `BroadcastsFec::process()` при новом `broadcast_hash` создаётся `std::make_unique<BroadcastFec>(...)`, затем объект кладётся в `lru_` и `broadcasts_`.
2. Precheck before allocation: date/source/fec/seqno/hash, delivered-cache, limiter precheck, `BroadcastFecPart::run_checks()` и signature/source eligibility идут до allocation.
3. Duplicate/cap before allocation: duplicate по `broadcast_hash` проверяется до allocation; если state уже есть, новая part идёт в существующий объект. Явного count cap на количество разных `broadcast_hash` в legacy FEC path не видно.
4. One-broadcast-per-slot analogue: generic legacy FEC не несёт simplex slot cap; но consensus/private route умирает раньше из-за `allow_old_broadcasts_=false`.
5. Reachability: validator consensus/private и block-sync overlays — blocked. Возможная reachability остаётся только для fast-sync/custom/semiprivate overlay, что слабее для Critical/High и требует отдельного gate.
6. Один Byzantine validator/member: в consensus/private path — нет, потому что legacy FEC отклоняется до receiver path. В fast-sync/custom — unclear; нужен one-message gate с authorized member.
7. Count cap или GC: в legacy `BroadcastsFec::gc()` найден age-based GC (`~60s`) без явного count cap; impact всё равно не доказан без validator-relevant reachability.
8. Verdict: `maybe/drop`; не писать большой harness. Следующий шаг только tiny gate, если решено проверять fast-sync/custom relevance.

Minimal gate:

- Clean target fast-sync/custom overlay, attacker — authorized member.
- Отправить один валидный old `overlay_broadcastFec` без twostep и проверить, достигает ли clean target `BroadcastsFec::process()` allocation.
- PASS только если old FEC accepted на validator-relevant fast-sync/custom path и можно создать много разных `broadcast_hash` до GC с заметным RSS/CPU signal.
- BLOCKER/drop если old FEC rejected, source/certificate/signature не проходит, limiter срабатывает, путь только operator-configured custom/public overlay, или allocation/RSS negligible.

Abort condition:

- Если reachable path требует public-overlay Sybil, trusted custom config/operator mistake или не влияет на validator availability, CAND-02 окончательно drop.

## CAND-03 — maybe/drop — Simplex certificate signature verification CPU amplification

Candidate ID: CAND-03-simplex-cert-signature-cpu.

Verdict: `maybe/drop`.

Affected path:

- `validator/consensus/simplex/certificate.cpp`: `Certificate<T>::from_tl()` parses vote signature sets, rejects duplicate/out-of-range validators, accumulates weight, then verifies signatures.
- `validator/consensus/simplex/pool.cpp`: inbound consensus message/certificate paths before or around pool insertion.

Attacker model:

- Byzantine validator in consensus overlay repeatedly sends invalid-but-structurally-valid certificates/vote sets.

Product-path reachability:

- Certificates and votes are normal consensus overlay messages, but inbound rate limits, duplicate caches and expected-message state must be traced before treating this as actionable.

Controlled input:

- Signature set size up to validator-set size, signature bytes, vote/certificate payload and repeated message cadence.

Potential impact:

- CPU burn from repeated Ed25519 verification if invalid signatures are verified before effective duplicate/rate limits.

Known cap/check:

- Validator-set-size cap bounds per-message signatures; likely per-peer/duplicate/round checks may make this expected Byzantine cost.

Minimal gate:

- Static first: trace inbound message dispatch to `Certificate<T>::from_tl()` and identify rate/duplicate check before signature verification.
- Runtime only if a single Byzantine validator can trigger many expensive verifies on clean target without being suppressed.

Abort condition:

- Drop if existing duplicate suppression, per-peer limits, validator-set-size cap, or challenge rules classify it as normal cost of validating Byzantine consensus messages.

## CAND-04 — drop — RLDP2 inbound small-transfer state churn

Candidate ID: CAND-04-rldp2-inbound-small-transfer-churn.

Verdict: `drop` unless new concrete fact appears.

Affected path:

- `rldp2/RldpConnection.cpp`: inbound transfer ids and timeout-based cleanup.

Attacker model:

- Network peer able to send RLDP2 packets.

Product-path reachability:

- RLDP2 is real overlay/full-node query transport, but previous handoff already treated similar inbound-state churn as weak.

Controlled input:

- Many transfer ids and small chunks.

Potential impact:

- Transfer-map churn until timeout, if not bounded by lower-layer limits.

Known cap/check:

- ADNL/RLDP2 packet limits, timeout cleanup, peer-level constraints and prior weak status.

Minimal gate:

- Do not pursue before finding a new missing global/per-peer cap that changes prior conclusion.

Abort condition:

- Keep dropped if resource growth is only timeout-bounded normal network churn.

## CAND-05 — drop/monitor — private-overlay source map `.at()` crash hypothesis

Candidate ID: CAND-05-private-overlay-source-map-at-crash.

Verdict: `drop/monitor`.

Affected path:

- `validator/consensus/private-overlay.cpp`: callback methods map overlay source identifiers to peers via `adnl_id_to_peer_.at(src)` / `short_id_to_peer_.at(src)`.
- `overlay/overlay.cpp`: overlay receive path performs source/membership checks before invoking callback.

Attacker model:

- Remote overlay sender with spoofed or no-longer-known source identity.

Product-path reachability:

- Current static read suggests source authorization/checking happens before callback, so unknown sender should be rejected before `.at()`.

Controlled input:

- Overlay source key/ADNL and message/broadcast envelope.

Potential impact:

- Process crash if a network-reachable callback can receive an authorized-looking source that is absent from local maps.

Known cap/check:

- Overlay-layer `check_src_peer`/membership gates appear to block the path.

Minimal gate:

- Only reopen if a concrete callback path bypasses overlay source checks or a reconfiguration race removes a peer after overlay accepts the message.

Abort condition:

- Drop if every callback entry is preceded by overlay membership/source validation.

## CAND-06 — drop — fast-sync old-FEC empty promise / NeedCheck gate

Candidate ID: CAND-06-fast-sync-fec-empty-check-broadcast.

Verdict: `drop`; CAND-06 закрыть, не тратить harness.

Affected path:

- `overlay/broadcast-fec.cpp`: legacy FEC `BroadcastFecPart::run()` при `untrusted_ == true` создаёт lambda promise и вызывает `overlay->check_broadcast(...)` после успешного `BroadcastFec::finish()`.
- `overlay/overlay.cpp`: `OverlayImpl::check_broadcast(...)` синхронно передаёт promise в overlay callback.
- `validator/full-node-fast-sync-overlays.cpp` и `validator/full-node-custom-overlays.cpp`: callbacks имеют пустой `check_broadcast(...)` body.
- `tdactor/td/actor/PromiseFuture.h`: `LambdaPromise::~LambdaPromise()` вызывает callback с `Status::Error("Lost promise")`, если promise уничтожен без `set_value`/`set_error`.

Attacker model:

- Для fast-sync/custom `NeedCheck` нужен не обычный current-validator sender: current validators попадают в `authorized_keys` и получают `Allowed`.
- Потенциальный `NeedCheck` источник — неавторизованный source с member/broadcast certificate от authorized issuer/root key и без `Trusted` flag. Это уже certificate-gated semiprivate/custom path, а не один Byzantine validator в consensus/private overlay.

Product reachability:

- Validator/private consensus overlay и block-sync overlay не относятся к CAND-06: legacy old-FEC там отключён ранее.
- Fast-sync/custom old-FEC path может быть достижим только при включённом receive side и валидной certificate-based membership/source eligibility.
- Даже если crafted old FEC доходит до `NeedCheck`, статический gate показывает, что promise не остаётся unresolved: пустой callback уничтожает `td::Promise`, а destructor lambda-promise отправляет `Lost promise` в `OverlayImpl::broadcast_fec_checked(...)`.

Old/legacy FEC enabled:

- `OverlayOptions::allow_old_broadcasts_` по умолчанию `true`; fast-sync/custom init не выставляет `allow_old_broadcasts_ = false` в показанном коде.
- Это не спасает CAND-06: suspicious empty callback не образует persistent unresolved async state.

Suspicious state/promise:

- Promise создаётся в `BroadcastFecPart::run()` только после накопления достаточных FEC parts для `BroadcastFec::finish()`.
- Empty callback не вызывает `set_value`, но destruction path вызывает lambda с `Lost promise`; далее `BroadcastFec::broadcast_checked()` получает error и только increments peer error counter.
- `BroadcastFec` object остаётся обычным legacy-FEC receiver state до age-based GC, но это не отдельный empty-promise leak/hang; это сводится к уже слабому CAND-02 legacy-FEC state window.

Precheck/auth before state:

- До allocation/finish есть date/source/fec/seqno/hash checks, delivered-cache check, limiter precheck, `BroadcastFecPart::run_checks()`, source eligibility и signature verification.
- `NeedCheck` появляется только после `OverlayImpl::check_source_eligible(...)`, где authorized current-validator source получает `Allowed`, unknown source без valid certificate получает `Forbidden`, а certificate-mediated source может получить `NeedCheck`.

Cap/GC/timeout:

- Нет отдельного unresolved-promise cap, потому что unresolved promise не сохраняется.
- Legacy `BroadcastFec` state очищается обычным age-based GC (`~60s`) и после failed check не доставляется.
- Для Critical/High это недостаточно без нового факта о validator-relevant, repeatable, high-RSS legacy-FEC accumulation до GC.

Minimal one-message gate:

- Gate нужен только если кто-то хочет эмпирически подтвердить static drop: отправить один complete old `overlay_broadcastFec` от certificate-mediated fast-sync/custom source, который даёт `NeedCheck`.
- Existing expected marker: peer error / `Lost promise` path через `broadcast_fec_checked`, а не зависший promise и не delivery.

PASS:

- Нет PASS для CAND-06 как Critical/High на текущих фактах. Reopen только если runtime покажет, что promise не уничтожается/не вызывает `Lost promise`, state остаётся checked-pending сверх GC, или product-valid attacker может накапливать meaningful state до сильного cap.

BLOCKER:

- `td::Promise` destruction resolves the lambda with `Lost promise`; empty callback therefore does not create unresolved async hang.
- Current-validator fast-sync sender is `Allowed`, not `NeedCheck`; nonvalidator path требует valid certificate and is weaker than Byzantine-validator consensus model.
- Remaining state is ordinary legacy-FEC GC-bounded state from CAND-02, not a new CAND-06 issue.

Next action:

- CAND-06 закрыть. Следующий поиск не должен строить harness вокруг empty `check_broadcast`; если продолжать, идти к новым consensus/full-node candidates с pre-auth/pre-cap state или reachable crash, а не к old-FEC empty promise.

## Next recommended check

CAND-06 закрыт как `drop`: empty `check_broadcast` не даёт unresolved promise из-за destructor path `Lost promise`. Следующий шаг — fresh candidate search в consensus/full-node paths, где маленький gate доказывает pre-auth/pre-cap state, reachable crash или realistic validator availability impact до любого harness.

---

## Autonomous Critical-only triage refresh — 2026-06-12

### Rules / cleanup status

- Official rules refreshed from `contest.com/docs/TonConsensusChallenge`, `ton-blockchain/bug-bounty`, and current upstream `ton-blockchain/ton` `testnet` page.
- Effective filter: no submission before self-reproduction; every report needs a reproduction script/archive; speculative, unverifiable, incomplete, low-quality or AI-generated slop reports are ignored; local/trusted-environment, debug-only, public-overlay Sybil-only and behavior without realistic normal-network impact are out.
- Cleanup: repository status was clean at the start of this pass. No Stage B temporary files (`run_stage_b_local.sh`, `stage_b_*`, seed/attacker patches, RSS sampler) are present in `audit/`. Remaining CAND-01 markdown files are retained as closed audit memory, not runnable temporary artifacts. No production logic was changed.

### Fresh checked areas

- Full-node / validator sync request handlers and download actors.
- Archive importer prestart-sync path.
- RLDP2 inbound transfer state.
- Overlay peer admission / pending peer queues.
- DHT store / reverse-connection state.
- Key-block downloader response handling.

### CN-ARCHIVE-01 — pursue — unbounded archive-slice download to temp file from malicious full-node neighbour

Candidate ID: `CN-ARCHIVE-01`.

Verdict: `pursue`; strong candidate for one focused local PoC, but not report-ready until runtime evidence is collected.

Affected path:

- `validator/manager.cpp`: `ValidatorManagerImpl::prestart_sync()` calls `download_next_archive()` while the validator is out of sync.
- `validator/manager.cpp`: `download_next_archive()` creates `ArchiveImporter` when no local import files are available.
- `validator/import-db-slice.cpp`: `ArchiveImporter::start_up()` requests a masterchain archive from net with a 3600s timeout.
- `validator/import-db-slice.cpp`: `ArchiveImporter::download_shard_archive()` requests shard archives with a 3600s timeout.
- `validator/manager.cpp`: `send_download_archive_request()` delegates to full-node callback.
- `validator/full-node.cpp`: `FullNodeImpl::download_archive()` selects the historical shard actor and forwards to `FullNodeShard`.
- `validator/full-node-shard.cpp`: `FullNodeShardImpl::download_archive()` chooses a neighbour and starts `DownloadArchiveSlice`.
- `validator/net/download-archive-slice.cpp`: `DownloadArchiveSlice` asks the selected peer for archive info, then repeatedly requests `tonNode_getArchiveSlice(archive_id, offset, 2MiB)` and writes every full-size response to a temp file.

Entry point:

- Clean validator/full-node during prestart sync/import path when it needs archive data from network.

Attacker model:

- One Byzantine full-node neighbour selected by the target as `download_from_` for archive download.
- No public-overlay Sybil assumption is needed for the core bug: the attacker is the chosen serving neighbour in the product archive-download path.

Controlled input:

- Malicious answers to `tonNode_getArchiveInfo` / `tonNode_getShardArchiveInfo`: return `tonNode_archiveInfo(id)`.
- Malicious answers to repeated `tonNode_getArchiveSlice`: return exactly the requested 2MiB `max_size` for every increasing `offset` and never return a short final slice.

Dangerous operation / mutation:

- `DownloadArchiveSlice::got_archive_slice()` writes the received buffer to an open temp file, increments `offset_`, and if `data.size() == slice_size()` immediately requests the next slice.
- There is no advertised archive total size, no maximum accumulated archive bytes, no per-archive upper bound, and no server-provided EOF other than a short read.

Precheck/auth/caps before danger:

- The target itself requests slices of `slice_size() == 2MiB` and sets RLDP answer limit to `slice_size() + 1024`, so each malicious answer is protocol-shaped and within the target request limit.
- Server-side request rate limits protect honest serving nodes, not the downloading target receiving a chosen malicious peer's full-size answers.
- The only visible global stop is actor timeout supplied by `ArchiveImporter` (`3600s`), not a byte cap.

Expected impact:

- Disk-space exhaustion in the validator DB temp directory (`db_root_/tmp`) during archive import/prestart sync.
- Potential validator availability loss if the disk fills before the 3600s timeout/abort cleanup; RocksDB and validator state writes can fail on full disk.
- The growth is linear in attacker-supplied bytes but realistic: at 2MiB per response, a malicious neighbour can drive tens/hundreds of GiB of temp-file growth within the 3600s window on ordinary bandwidth.

Why this could meet Critical/High bar:

- Product-path validator availability impact: full disk can halt or destabilize validator operation, not just log spam.
- One malicious full-node neighbour suffices once selected as the archive source.
- The behaviour is not a local DB corruption, debug-only injection, public-overlay Sybil-only, or harness-only effect.
- Official resource-exhaustion rules allow linear growth if it can realistically DoS an average validator; this path can consume disk for up to one hour without a byte cap.

Why it is not an old rejected branch:

- It is not `persistent-state download accumulation`: the path is archive prestart sync/import, not `WaitBlockState` / `DownloadShardState` / persistent-state downloader. The previous Stage B failed to reach product persistent-state download; this candidate has a direct product caller in `ArchiveImporter::start_up()`.
- It is not CAND-01/CAND-02/CAND-06 broadcast/FEC state accumulation.
- It is not public-overlay Sybil-only; the attacker model is a selected archive-serving full-node neighbour.

Minimal PoC gate:

- Clean target starts sufficiently out-of-sync so `ValidatorManagerImpl::prestart_sync()` invokes `ArchiveImporter::start_up()` and network archive download.
- Attacker-only full-node patch returns `tonNode_archiveInfo(id)` for archive info and exactly 2MiB of arbitrary bytes for every `tonNode_getArchiveSlice` request.
- Target log must show `Importing archive ... from net`, `downloading archive slice #... from <attacker_adnl>`, repeated `downloading archive slice ... total=...` with monotonically increasing totals.
- Attacker log must show matching archive slice requests with increasing offsets and cumulative bytes returned.
- Target `db_root_/tmp` temp file size and filesystem free space must grow until either local safety cap, disk-full error, timeout, or clean short-read stop.

PASS:

- Clean target reaches the normal archive download path, selects attacker as `download_from_`, receives repeated full-size slices, and target temp-file/disk usage grows without an archive byte cap.
- The run demonstrates a realistic availability signal: disk-full error, validator/DB write failure, severe free-space depletion under a safety cap, or continued growth until forced stop.

BLOCKER / close condition:

- Target does not enter archive network import in a normal out-of-sync setup.
- Target switches away from malicious neighbour after a bounded number of full-size slices.
- A hidden byte cap/total-size check stops the download at a realistic archive size.
- Downloaded full-size garbage is validated before being written or before meaningful disk growth.
- Impact remains only a short-lived temp file with small bounded size.

Likely fix:

- Extend archive-info protocol or downloader state with an expected total size and reject responses beyond it.
- Add a hard maximum downloaded archive bytes per archive/shard based on configured archive slice bounds and local safety limit.
- Treat too many consecutive full-size slices or excessive cumulative bytes as peer misbehaviour and switch/ban the serving neighbour.
- Keep timeout but do not rely on timeout as the only resource bound.

### Closed during this refresh

#### CN-RLDP2-01 — drop — inbound RLDP2 unknown-transfer state

Source path:

- `rldp2/RldpConnection.cpp`: unknown inbound transfer creates `InboundTransfer` with default MTU receive limit and 10s timeout.
- `adnl/adnl-local-id.cpp`: inbound UDP/ADNL packets are rate-limited per IP and capped by recent unique peer IDs per IP before RLDP delivery.

Kill reason:

- Product path exists, but state per unknown transfer is bounded by default MTU and 10s timeout; ADNL per-IP limiter and unique-peer cap sit before delivery. This is linear packet spam with small bounded per-transfer state, not a Critical/High validator-availability candidate on current facts.

#### CN-OVERLAY-PEERS-01 — drop — overlay pending peer admission

Source path:

- `overlay/overlay.cpp`: `overlay_getRandomPeers` can call `add_peers(...)` on public overlays.
- `overlay/overlay-peers.cpp`: unverified peers pass timestamp/signature checks, then enter `pending_peers_` only up to `opts_.max_pending_peers_`; processing is rate-limited and failed pings remove entries.

Kill reason:

- Pending peers are capped (`max_pending_peers_`, default 50) and processing is rate-limited. No unbounded pre-auth allocation or validator-critical impact.

#### CN-DHT-STORE-01 — drop — DHT store/reverse-connection state

Source path:

- `dht/dht.cpp`: `dht_store` validates `DhtValue`, rejects too-large TTL, stores only sufficiently close keys, and GC trims `values_` by TTL and `MAX_VALUES`.
- `dht/dht.cpp`: reverse connections require signature and are trimmed by TTL and `MAX_REVERSE_CONNECTIONS`.

Kill reason:

- Public DHT path is bounded and not directly consensus-liveness critical. Not a strong validator Critical/High candidate.

#### CN-KEYBLOCKS-01 — drop — malicious `tonNode_keyBlocks` overlarge response

Source path:

- `validator/net/get-next-key-blocks.cpp`: requester asks a peer for next key blocks and appends every returned block id to `pending_`.
- `validator/full-node-shard.cpp` / `validator/full-node-master.cpp`: honest responders cap `max_size_` to 8.
- `overlay/overlay-manager.h`: default overlay query answer limit is `Adnl::huge_packet_max_size()`.

Kill reason:

- A malicious peer could ignore the requested count inside a bounded RLDP answer, but response size is capped by the query answer limit and subsequent proofs are validated sequentially. The likely impact is bounded transient memory/work, not Critical/High.

### Next action

Best next action: build a focused local PoC only for `CN-ARCHIVE-01`. Do not build broad infrastructure. The first gate is simply to force a clean target into archive network import, choose the attacker as archive-serving neighbour, and observe repeated `getArchiveSlice` writes with increasing temp-file size.
