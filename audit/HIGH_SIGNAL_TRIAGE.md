# High-signal triage

Дата: 2026-06-12.

Цель pass: искать только crash / consensus stall / validator availability / real Critical-or-High impact. Не строить harness до маленького product-path gate. Не переоткрывать закрытые ветки без нового факта.

## Closed context

- `persistent-state`: `drop`; Stage B product-path failed (`any_downloading_state=False`, `downloading_from_attacker_heuristic=False`, `attacker_slice_count=0`, `RUNNER_EXIT=2`).
- `CAND-01`: `drop`; private-overlay twostep FEC allocation после precheck/cap, один accepted `broadcast_id` на slot.
- `CAND-02`: `drop/maybe weak`; legacy FEC выключен для consensus/private overlays, fast-sync/custom only weak maybe.
- `CAND-06`: `drop`; empty fast-sync/custom `check_broadcast` не создаёт unresolved promise leak/hang из-за `Lost promise` destructor path.
- H7-A/B/C/D, external-message limiter bypass, public-overlay Sybil-only, local/trusted/debug-only и harness-only ветки не переоткрывались.

## Checked areas

### Crash/assert-like sweep

Проверены кластеры `CHECK`, `DCHECK`, `UNREACHABLE`, `LOG(FATAL)`, `.at(...)`, `.value()`, `narrow_cast` в:

- `validator/consensus`
- `validator/downloaders`
- `validator/full-node*`
- `validator/net`
- `overlay`
- `dht`
- `adnl`
- `rldp2`

High-signal grep дал 303 targeted crash/assert hits. Ручной triage сфокусирован на местах, где есть шанс на remote / Byzantine validator / malicious full-node reachability, а не на локальных invariant checks.

### Async/state/resource sweep

Проверены кластеры `from_tl`, `fetch`, `parse`, `validate`, `precheck`, `certificate`, `vote`, `candidate`, `pending`, `postponed`, `resolver`, `download`, `proof`, `state`, `archive`, `queue`, `cache`, `lru`, `timeout`, `promise`, `set_value`, `set_error` в consensus/full-node/download/overlay/DHT/ADNL paths.

Wide grep дал 4748 path hits; вручную отобраны только места с потенциальным crash/stall/pre-cap state.

## Candidate shortlist

### HS-01 — malicious full-node wrong block/proof causing downloader CHECK

Candidate ID: HS-01-download-block-wrong-data-check.

Verdict: `drop`.

Affected path:

- `FullNodeShardImpl::download_block(...)` → `DownloadBlockNew`.
- `DownloadBlockNew::got_ready_to_deserialize(...)`.
- `WaitBlockData::loaded_data(...)` / `loaded_block_data(...)`.

Exact functions:

- `validator/net/download-block-new.cpp`: `DownloadBlockNew::got_data(...)`, `got_ready_to_deserialize(...)`.
- `validator/downloaders/wait-block-data.cpp`: `WaitBlockData::loaded_data(...)`, `loaded_block_data(...)`, `checked_proof_link(...)`.
- `validator/impl/fabric.cpp`: `create_block(...)`.

Attacker model:

- Malicious full-node neighbour selected for block download.

Product-path reachability:

- Yes, block download from neighbour is product path.

Controlled input:

- `tonNode_DataFull` response: block id/proof/proof link/block bytes/compressed variants.

Dangerous operation:

- Several downloader `CHECK`s exist after block/proof state is expected to be consistent.

Precheck/auth before danger:

- `DownloadBlockNew::got_ready_to_deserialize(...)` rejects invalid TL, wrong block id, bad block data hash, missing proof, bad proof/proof link before returning `ReceivedBlock`.
- `create_block(...)` also rejects malformed block data before `WaitBlockData` continues.

Cap/cleanup:

- Bad peer response aborts query and can retry/switch via normal full-node path; no direct crash gate found.

Expected impact:

- Not Critical/High on current facts: bad data is rejected as `notready` / bad proof / bad hash before assert-like checks.

Tiny gate:

- Not recommended. A one-response gate with wrong `file_hash` should produce `received data with bad hash`, not crash.

PASS:

- Reopen only if a malicious full-node response can pass `DownloadBlockNew` hash/proof checks and still violate a later `CHECK` in `WaitBlockData`.

BLOCKER:

- Existing hash/proof validation before dangerous operations. Drop.

Why better/worse than previous drops:

- Better attacker model than public Sybil, but the static validation gate is strong and blocks the crash.

### HS-02 — private-overlay callback `.at(...)` crash on spoofed source

Candidate ID: HS-02-private-overlay-map-at-crash.

Verdict: `drop`.

Affected path:

- Consensus private-overlay callbacks map ADNL/source IDs through `.at(...)`.

Exact functions:

- `validator/consensus/private-overlay.cpp`: `on_overlay_message`, `on_overlay_broadcast`, `precheck_broadcast`, `on_query` callback-side mapping.
- `overlay/overlay.cpp`: receive path source/membership checks before callback dispatch.

Attacker model:

- Remote overlay sender attempting unknown/spoofed source key or ADNL id.

Product-path reachability:

- Current static result: not reachable as crash because overlay layer checks source/membership before invoking consensus callback.

Controlled input:

- Overlay envelope source identity and message/broadcast/query body.

Dangerous operation:

- `.at(...)` on `adnl_id_to_peer_` / `short_id_to_peer_` if callback received unknown source.

Precheck/auth before danger:

- Overlay source/membership validation is before callback entry; unknown source should be rejected before `.at(...)`.

Cap/cleanup:

- Not applicable; path blocked before dangerous operation.

Expected impact:

- No crash on current facts.

Tiny gate:

- Not recommended unless a concrete source-check bypass path is found.

PASS:

- Reopen only if a specific overlay message type reaches private-overlay callback without source membership validation.

BLOCKER:

- Source/membership gate before callback. Drop.

Why better/worse than previous drops:

- Direct crash class, but currently blocked by product-path auth gate.

### HS-03 — masterchain future-candidate validation waiter accumulation

Candidate ID: HS-03-masterchain-future-candidate-waiters.

Verdict: `maybe/drop`; best available weak candidate from this pass, but not `pursue`.

Affected path:

- `CandidateReceived` → `Simplex::handle(CandidateReceived)` → `try_notarize(...)` → `ValidationRequest` → `BlockValidatorImpl::process(...)`.

Exact functions:

- `validator/consensus/simplex/consensus.cpp`: `handle(CandidateReceived)`, `try_notarize(...)`.
- `validator/consensus/block-validator.cpp`: `BlockValidatorImpl::process(...)`, `next_block_promises_` wait loop.

Attacker model:

- Byzantine validator/collator in current consensus group sends product-valid-looking candidate within allowed future window.

Product-path reachability:

- Candidate broadcasts are product path, but Simplex drops candidates whose slot is too far ahead and keeps only one pending block per slot.

Controlled input:

- Candidate slot, parent/state reference, block candidate data, timing of candidate broadcast.

Dangerous operation:

- For masterchain block candidates, `BlockValidatorImpl::process(...)` can push a promise into `next_block_promises_` and await finalized predecessor progress while `last_accepted_block_ < expected_seqno`.

Precheck/auth before danger:

- Candidate must pass private-overlay/source checks and Simplex slot window checks.
- `Simplex::handle(CandidateReceived)` drops `slot_idx >= first_too_new_slot` and ignores slots absent from local state.
- Per-slot `pending_block` prevents many different candidates for the same slot from entering validation.

Cap/cleanup:

- Bounded by `max_leader_window_desync`, slots per leader window, one pending candidate per slot, and normal `on_new_accepted_block(...)` wakeup.
- No clear attacker-unbounded queue was found.

Expected impact:

- At most bounded validation waiters / temporary consensus work. No Critical/High impact demonstrated.

Tiny gate:

- If someone insists on checking: one Byzantine validator sends a candidate for the furthest still-accepted future slot. Clean target should either drop as too new or create at most one bounded waiter for that slot.

PASS:

- Only if a single Byzantine validator can create many `next_block_promises_` beyond slot/window caps and keep them across GC/finalization, with observable validator availability impact.

BLOCKER:

- Too-new candidate drop, slot absent, already pending slot, expected-collator/leader mismatch, or bounded waiter count. Current verdict stays `maybe/drop`.

Why better/worse than previous drops:

- Better than old-FEC branches because it is consensus product-path and Byzantine-validator model, but worse as a finding because visible caps likely bound state.

### HS-04 — overlay-manager unknown-overlay buffered request accumulation

Candidate ID: HS-04-overlay-manager-unknown-overlay-buffer.

Verdict: `drop`.

Affected path:

- `OverlayManager::receive_message(...)` / `receive_query(...)` when packet targets a local ADNL id but an overlay id not yet registered.

Exact functions:

- `overlay/overlay-manager.cpp`: unknown-overlay buffering for messages/queries.
- `validator-engine/validator-engine.cpp`: overlay manager buffer limits configured as `max_packets = 1024`, `max_data_size = 2 << 20`.

Attacker model:

- Remote peer sends overlay messages/queries to local ADNL with unknown overlay id.

Product-path reachability:

- Network path is real, but state is explicitly bounded before insertion.

Controlled input:

- Overlay id, query/message data size, packet cadence.

Dangerous operation:

- Pre-overlay buffering of request data and optional query promise.

Precheck/auth before danger:

- Buffering occurs after TL prefix parse and local-id lookup, before target overlay exists.

Cap/cleanup:

- Hard caps: max 1024 packets and 2 MiB total configured in validator-engine; old entries evicted before insertion.

Expected impact:

- Bounded memory; not Critical/High.

Tiny gate:

- Not needed; caps are explicit.

PASS:

- Reopen only if production config disables buffer caps or another path buffers unknown overlays without these limits.

BLOCKER:

- Hard packet/data-size caps and eviction. Drop.

Why better/worse than previous drops:

- Pre-auth state exists, but it is explicitly bounded and therefore not high impact.

### HS-05 — ADNL/DHT assert-like `ensure()` on malformed network input

Candidate ID: HS-05-adnl-dht-ensure-network-input.

Verdict: `drop`.

Affected path:

- ADNL decrypted packet handling and DHT query handling.

Exact functions:

- `adnl/adnl-local-id.cpp`: decrypt + `AdnlPacket::create(...)`.
- `adnl/adnl-peer-table.cpp`: `receive_decrypted_packet(...)`.
- `adnl/adnl-peer.cpp`: `receive_packet(...)`, `receive_packet_checked(...)`.
- `dht/dht.cpp`: DHT `process_query(...)` methods.

Attacker model:

- Remote ADNL/DHT peer sends malformed packet/query.

Product-path reachability:

- ADNL/DHT network path is real, but malformed packet/query errors are handled before assert-like invariants in the inspected paths.

Controlled input:

- ADNL packet flags/messages, DHT query/value/certificate fields.

Dangerous operation:

- `run_basic_checks().ensure()` and `R.ensure()` calls appear in network-adjacent code.

Precheck/auth before danger:

- `AdnlPacket::create(...)` runs `run_basic_checks()` and returns `Result`; decrypted malformed packets fail before actor dispatch.
- DHT `dht_store` uses `DhtValue::create(..., true)` and returns protocol errors for invalid values.
- DHT `ensure()` uses in inspected snippets are on internally produced `get_self_node(...)` / local invariants, not attacker-controlled malformed query fields.

Cap/cleanup:

- Not applicable; malformed inputs are dropped/error-returned.

Expected impact:

- No remote crash candidate found in this pass.

Tiny gate:

- Not recommended unless a concrete function is found where remote TL reaches `.ensure()` without a prior `Result` check.

PASS:

- Reopen only with exact malformed network input that reaches `.ensure()` directly.

BLOCKER:

- Prior parse/basic-check error handling. Drop.

Why better/worse than previous drops:

- Strong crash class in principle, but static gate did not find a remote-controlled path.

## Best next candidate

No `pursue` candidate found in this pass.

Best available: `HS-03-masterchain-future-candidate-waiters` as `maybe/drop`, not report-ready.

Reason:

- It is at least consensus product-path and Byzantine-validator model.
- It has an exact state point (`BlockValidatorImpl::next_block_promises_`) and a tiny gate.
- It is still weak because Simplex has too-new slot drop, one pending block per slot, expected leader/collator constraints and bounded window semantics.

Next recommended search area:

- Continue in consensus/Simplex inbound candidate/certificate/vote paths, but focus on exact pre-cap crash or actor-lifetime/promise bugs, not generic resource exhaustion.
- Prefer paths where dangerous operation happens before slot/window/duplicate/auth caps.

## Tiny gate plan

For HS-03 only if we decide to spend a small runtime check:

1. Local clean target + one Byzantine validator/member in a lab validator group.
2. Attacker sends exactly one candidate for a future slot that is still below `first_too_new_slot`.
3. Observe target logs/metrics for:
   - candidate accepted into `Simplex::handle(CandidateReceived)`;
   - whether `BlockValidatorImpl::process(...)` enters the `last_accepted_block_ < expected_seqno` wait loop;
   - size/count of `next_block_promises_` if instrumentation is allowed.
4. PASS only if repeated product-valid inputs create many waiters beyond slot/window caps and persist long enough to affect validator availability.
5. BLOCKER if target drops as too new, ignores absent slot, keeps one pending candidate per slot, or waiter count is bounded by small window size.

No runtime harness should be built before this single-gate check is justified.

## Commands run

```bash
git status --short
git log --oneline -5
sed -n '1,260p' audit/NEXT_CANDIDATES.md 2>/dev/null || true
rg -n "CHECK\(|DCHECK\(|UNREACHABLE|LOG\(FATAL\)|\.at\(|\.value\(\)|narrow_cast|fatal|abort" validator overlay dht rldp adnl tdutils crypto -S
rg -n "from_tl|fetch|parse|deserialize|validate|precheck|certificate|vote|candidate|pending|postponed|resolver|resolve|download|proof|state|archive|queue|cache|lru|timeout|promise|set_value|set_error" validator/consensus validator/downloaders validator/full-node* validator/net overlay dht rldp adnl -S
rg -n "CHECK\(|DCHECK\(|UNREACHABLE|LOG\(FATAL\)|\.at\(|\.value\(\)|narrow_cast" validator/consensus validator/downloaders validator/full-node* validator/net overlay dht adnl rldp2 -S
sed -n '80,190p' validator/downloaders/wait-block-data.cpp
sed -n '280,460p' validator/net/download-block-new.cpp
sed -n '140,250p' validator/consensus/simplex/consensus.cpp
sed -n '1,170p' validator/consensus/block-validator.cpp
sed -n '270,350p' overlay/overlay-manager.cpp
sed -n '240,270p' adnl/adnl-peer.cpp
sed -n '1,180p' adnl/adnl-packet.cpp
sed -n '260,340p' dht/dht.cpp
```

## Current verdict

No pursue candidate found in this pass.

Current verdict: `stopped/done` for this sweep, with `HS-03` as best available `maybe/drop` and no bounty/report-ready candidate.

Changed files: `audit/HIGH_SIGNAL_TRIAGE.md`.

Next action: either approve a tiny HS-03 static/runtime gate, or run another high-signal pass specifically over consensus certificate/vote parsing and actor lifetime before validation caps.
