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

## CAND-01 — pursue — private-overlay twostep FEC incomplete-broadcast state accumulation

Candidate ID: CAND-01-twostep-fec-incomplete-state.

Affected code path:

- `validator/consensus/private-overlay.cpp`: consensus private overlay включает `twostep_broadcast_sender_`, `send_twostep_broadcast_=true`, `allow_old_broadcasts_=false`.
- `overlay/broadcast-twostep.cpp`: `BroadcastsTwostep::process_broadcast(... overlay_broadcastTwostepFec ...)`.
- `overlay/overlays.h` + `tdutils/td/utils/RateLimiterWindow.h`: default auth/unauth broadcast limits равны нулевым params, а `duration == 0` означает `check() == true`.

Attacker model:

- Один Byzantine validator / authorized private-overlay member в текущем validator group или block-sync overlay.
- Не public-overlay Sybil-only: источник уже является участником private overlay и может подписывать twostep FEC parts своим ключом.

Why product-path reachable:

- Consensus private overlay создаётся как private overlay с authorized validator keys и twostep enabled.
- `OverlayImpl` принимает twostep broadcasts, если `twostep_broadcast_sender_` включён.
- `process_broadcast(Fec)` проверяет date, source/certificate, signature и затем создаёт receiver state для нового `broadcast_id`.

Input controlled by attacker:

- `data_hash`, `data_size`, `seqno`, `part`, `extra`, `date`, signature/certificate в `overlay_broadcastTwostepFec`.
- Для каждого сообщения attacker может выбирать новый `broadcast_id` через новый `data_hash`/`date`/`extra` и отправлять только один valid FEC symbol, чтобы state остался incomplete.

Expected impact:

- В памяти target появляются `BroadcastTwostep` + `td::raptorq::Decoder` + `seen_parts`/debug state для каждого нового incomplete broadcast.
- В `BroadcastsTwostep::gc()` нет count cap; state удерживается до age-based GC (`~25s`). Если per-state decoder allocation достаточно велика и rate не ограничен, Byzantine validator может вызвать RSS spike / CPU pressure / validator availability degradation.

Why this could be Critical/High:

- Вектор от Byzantine validator к другим validators в private consensus overlay.
- Potential impact — validator OOM/RSS spike или consensus liveness degradation, если рост state/CPU быстрее GC и без effective limiter.

Why it is not out-of-scope:

- Не local DB, не debug, не trusted operator, не public-overlay Sybil.
- Это нормальный private-overlay product-path от authorized peer.
- Пока не report-ready: надо доказать размер state, rate и observable impact.

Minimal PoC plan:

1. Small gate first, без большого harness: attacker-only patch в одном validator/full-node checkout, который после старта private overlay отправляет N valid `overlay_broadcastTwostepFec` с уникальными `broadcast_id`, `data_size=max_broadcast_size`, `part_size` минимально допустимым, `seqno=0`, корректной signature.
2. На clean target включить logs `twostep START receiver` и собрать RSS раз в секунду.
3. PASS gate: target log показывает тысячи `twostep START receiver`, RSS/CPU растёт заметно за <25s, затем `twostep GC_INCOMPLETE`; нет раннего limiter rejection.
4. BLOCKER: limiter rejects after small N, target does not create receiver state, decoder allocation negligible, or only public/Sybil path works.

Abort condition / what would disprove it:

- `precheck_new_broadcast()` реально ограничен configured params в validator consensus overlays.
- `Decoder::create()` почти не аллоцирует до нескольких symbols, RSS не растёт даже при high rate.
- Signature/certificate/product-path не достижимы без patch target or trusted config.

Files/functions to inspect next:

- `overlay/broadcast-twostep.cpp`: `BroadcastsTwostep::process_broadcast(Fec)`, `BroadcastsTwostep::gc()`.
- `validator/consensus/private-overlay.cpp`: private overlay options and authorized key setup.
- `validator/consensus/block-sync-overlay.cpp`: same pattern for block-sync overlay.
- `overlay/overlay.cpp`: `OverlayImpl::receive_broadcast_twostep_fec`, `get_broadcasts_limiter()`.

## CAND-02 — maybe — legacy FEC broadcast receiver state accumulation without count cap

Candidate ID: CAND-02-legacy-fec-incomplete-state.

Affected code path:

- `overlay/broadcast-fec.cpp`: `BroadcastsFec::process()` creates `BroadcastFec` receiver state for new incomplete FEC broadcasts.
- `BroadcastsFec::gc()` is age-based (`~60s`) and has no explicit count cap, unlike `BroadcastsSimple::gc()` which caps simple broadcasts at `MAX_BCASTS=100`.

Attacker model:

- Authorized private/custom/full-node overlay sender, depending on overlay type and configured certificates.

Why product-path reachable:

- Some overlays still use FEC broadcasts; custom overlays explicitly enable twostep but legacy FEC is still fallback/non-twostep path where allowed.

Input controlled by attacker:

- FEC broadcast hash, FEC type, broadcast size, first symbol.

Expected impact:

- Potential receiver-state accumulation for incomplete broadcasts over 60s window.

Why this could be Critical/High:

- Only if reachable from validator-relevant private overlay and if per-state allocation/rate can affect validator availability.

Why it is not out-of-scope:

- Potentially private overlay authorized peer, not public Sybil, but reachability must be re-verified.

Minimal PoC plan:

- Before writing a full harness, log whether validator consensus/block-sync overlays still accept legacy FEC when `allow_old_broadcasts_=false`; if rejected, drop.

Abort condition / what would disprove it:

- Only reachable in public overlay or old broadcasts disabled in relevant validator overlays.
- Per-state decoder allocation negligible or limiter configured.

Files/functions to inspect:

- `overlay/broadcast-fec.cpp`: `BroadcastsFec::process()`, `gc()`.
- `overlay/overlay.cpp`: old-broadcast allow checks.
- `validator/consensus/private-overlay.cpp`, `block-sync-overlay.cpp`.

## CAND-03 — maybe/drop — Simplex certificate signature verification CPU amplification

Candidate ID: CAND-03-simplex-cert-signature-cpu.

Affected code path:

- `validator/consensus/simplex/certificate.cpp`: `Certificate<T>::from_tl()` parses a vote signature set, rejects duplicate/out-of-range validators, accumulates weight, then verifies each signature.

Attacker model:

- Byzantine validator sends many invalid-but-structurally-valid certificates to peers over consensus overlay.

Why product-path reachable:

- Certificates/votes are normal consensus messages.

Input controlled by attacker:

- Number of signatures up to validator-set size, signature bytes, vote contents.

Expected impact:

- CPU load from Ed25519 checks if repeated invalid certificates are accepted for verification without adequate peer/message rate limits.

Why this could be Critical/High:

- Only if a single/few Byzantine validators can force sustained signature-verification CPU burn sufficient to stall consensus.

Why it is not out-of-scope:

- Byzantine validator in consensus overlay is in-scope; however challenge rules reject generic “misbehaving validator forces useless work validating incorrect candidates” unless a new severe impact is shown.

Minimal PoC plan:

- Static gate: trace inbound message rate limits and duplicate caches before certificate verification. If bounded, drop.

Abort condition / what would disprove it:

- Existing per-peer rate limits, duplicate suppression, or quorum/validator-count bounds make this normal expected Byzantine work.

Files/functions to inspect:

- `validator/consensus/simplex/certificate.cpp`, `pool.cpp`, overlay message dispatch.

## CAND-04 — drop for now — RLDP2 inbound small-transfer state churn

Candidate ID: CAND-04-rldp2-inbound-small-transfer-churn.

Affected code path:

- `rldp2/RldpConnection.cpp`: `receive_raw_obj()` creates `InboundTransfer` state for new transfer ids and sets default timeout for small inbound transfers.

Attacker model:

- Network peer capable of sending RLDP2 packets.

Why product-path reachable:

- RLDP2 is used by overlay/full-node queries.

Input controlled by attacker:

- Many transfer ids and small total sizes.

Expected impact:

- Potential churn of inbound transfer maps until timeout.

Why this could be Critical/High:

- Only if maps/decoder state can grow faster than timeout cleanup and peer limits.

Why it is not out-of-scope:

- Network path, but prior handoff already closed RLDP2 inbound-state as weak.

Minimal PoC plan:

- Do not pursue unless a new concrete fact shows missing cleanup/global limits.

Abort condition / what would disprove it:

- Existing ADNL/RLDP2 packet, peer, timeout, MTU and receive limits keep resource bounded.

Files/functions to inspect:

- `rldp2/RldpConnection.cpp`, `rldp2/InboundTransfer.cpp`, `rldp2/rldp.cpp`.
