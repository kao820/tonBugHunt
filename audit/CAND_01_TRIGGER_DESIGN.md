# CAND-01 trigger design — twostep FEC incomplete-broadcast runtime gate

Candidate: `CAND-01 — private-overlay twostep FEC incomplete-broadcast state accumulation`.

Current status: **sender-side path found, but still not report-ready**. The path can be reached by a private-overlay member, but static review found an important cap candidate: `PrecheckCandidateBroadcast` stores one `broadcast_id` per slot and rejects a different `broadcast_id` for the same slot. The runtime gate must first prove whether enough unique slots can be accepted to create meaningful state/RSS/CPU impact. If not, this candidate should be downgraded to `maybe/drop`.

## Sender-side path

Outgoing twostep FEC is created by `BroadcastsTwostep::send()` when all of these are true:

- caller uses `OverlayImpl::send_broadcast_fec()` / `Overlays::send_broadcast_fec_with_extra()`;
- overlay options have `send_twostep_broadcast_ = true` and no `BroadcastFlagNoTwostep`;
- `data_size >= FEC_MIN_BYTES`;
- `other_nodes.size() >= FEC_MIN_OTHER_NODES`.

Sender flow:

1. `PrivateOverlayImpl::handle(CandidateGenerated)` calls `Overlays::send_broadcast_fec_with_extra(local_id_.adnl_id, overlay_id_, local_id_.short_id, 0, candidate->serialize(), extra)`.
2. `OverlayImpl::send_broadcast_fec()` selects twostep when `opts_.send_twostep_broadcast_` is true.
3. `BroadcastsTwostep::send()` computes `data_hash`, `date`, `other_nodes`, `part_size`, then computes `broadcast_id`.
4. It creates one FEC `part` per destination with `td::raptorq::Encoder`.
5. For each part it creates `overlay_broadcastTwostepFec_toSign` and asks keyring to sign.
6. `BroadcastsTwostep::signed_fec()` serializes `overlay_broadcastTwostepFec` and sends it via `Overlays::send_message_via()`.

The block-sync overlay has an analogous `handle(CandidateReceived)` sender path through `send_broadcast_fec_with_extra()`.

## Signing path

The existing code already provides the correct signing path; no manual crypto is needed:

- `to_sign = create_serialize_tl_object<ton_api::overlay_broadcastTwostepFec_toSign>(broadcast_id, seqno, part.clone())`;
- `overlay->keyring()->sign_add_get_public_key(send_as, to_sign, promise)`;
- callback enters `OverlayImpl::broadcast_twostep_signed_fec()`;
- `BroadcastsTwostep::signed_fec()` serializes `overlay_broadcastTwostepFec` using returned public key and signature.

This means the safest attacker-only trigger should reuse `send_broadcast_fec_with_extra()` or `BroadcastsTwostep::send()`, not construct signatures manually.

## Required attacker identity

Minimum identity for product path:

- Byzantine validator / private-overlay member in the validator set;
- local ADNL id participating in the private overlay;
- source key matching `local_id_.short_id` / authorized validator key;
- membership/certificate accepted by overlay;
- for consensus/block-sync candidate broadcasts: attacker must be the expected collator for the slot in `consensus_broadcastExtra` / `tl::broadcastExtra`.

Important cap discovered:

- `PrivateOverlayImpl::precheck_broadcast()` and `BlockSyncOverlayImpl::precheck_broadcast()` both check `expected_collator_for(slot)`.
- `SimplexPool::process(PrecheckCandidateBroadcast)` allows only one `broadcast_id` per `slot`; a second different `broadcast_id` for the same slot is rejected as `Duplicate broadcast`.
- Therefore a simple “many unique broadcasts for one slot” spam is statically expected to hit BLOCKER before receiver-state allocation for the second unique id.

## Minimal attacker-only trigger point

Best first trigger: **attacker-only patch in `validator/consensus/private-overlay.cpp`, inside `PrivateOverlayImpl::handle(CandidateGenerated)`**, guarded by env flag `TON_POC_TWOSTEP_FEC_SPAM=1`.

Why this point:

- it already has `overlays_`, `adnl_sender_`, `overlay_id_`, `local_id_.adnl_id`, `local_id_.short_id`;
- it already uses the product sender API `send_broadcast_fec_with_extra()`;
- it reuses existing keyring/signing path in overlay twostep code;
- it only runs on the attacker validator when that validator legitimately generates a candidate / is expected collator;
- target remains clean.

Initial trigger design:

- read `TON_POC_TWOSTEP_FEC_SPAM_COUNT`, default small value such as `16`;
- only when `TON_POC_TWOSTEP_FEC_SPAM=1`;
- for the generated candidate slot, send the normal candidate once;
- then attempt additional sends with mutated serialized data and/or extra only if using different future slots where attacker is expected collator;
- log every attempted send: `sent_count`, chosen slot, expected collator status, source key, local ADNL, overlay id, payload size.

However, because of the per-slot `seen_broadcasts_` cap, the trigger must not assume N unique accepted broadcasts for one slot. The first gate should intentionally test and log this cap.

Alternative trigger point if consensus private overlay immediately caps by slot:

- `validator/consensus/block-sync-overlay.cpp`, inside `BlockSyncOverlayImpl::handle(CandidateReceived)`, also guarded by env flag.
- This path uses the same `send_broadcast_fec_with_extra()` sender and same expected-collator/slot precheck, so it is useful mainly to confirm whether block-sync behaves identically.

Not recommended for first gate:

- patching `overlay/broadcast-twostep.cpp` to bypass sender selection or fabricate parts: too low-level and risks moving away from consensus product path;
- standalone local debug tool: would need private overlay membership, ADNL, keyring and overlay id plumbing; too much harness before proving gate;
- clean target patch: not allowed for acceptance gate.

## Expected clean-target evidence

Target logs to collect:

- `twostep START receiver ... broadcast_id=...`;
- `twostep RECV_CHUNK receiver ...`;
- `twostep GC_INCOMPLETE receiver ...`;
- `Precheck failed: Broadcast is not from the expected collator`;
- `Duplicate broadcast`;
- `Broadcast rate limit ... exceeded`;
- signature/certificate errors.

Metrics:

- number of accepted unique `twostep START receiver` entries;
- number of rejected duplicate/precheck entries;
- target RSS once per second;
- target CPU during the burst;
- time until `GC_INCOMPLETE`.

## PASS criteria

PASS for continuing CAND-01 only if all hold:

- clean target receives valid twostep FEC messages from attacker private-overlay member;
- target creates multiple `BroadcastTwostep` receiver states, shown by repeated `twostep START receiver` with unique `broadcast_id`;
- accepted unique state count is not trivially capped by one slot / small future window;
- RSS or CPU grows meaningfully before age-based GC;
- no limiter/authorization/signature/dedup gate stops the burst early.

## BLOCKER criteria

BLOCKER / downgrade if any hold:

- authorization/signature/private-overlay membership fails;
- only the first broadcast for a slot is accepted and subsequent unique `broadcast_id`s are rejected by `seen_broadcasts_` / `Duplicate broadcast`;
- future-slot window and expected-collator schedule cap accepted entries to a small bounded number;
- `Decoder::create()` has negligible allocation and RSS/CPU does not move;
- target only accepts path in non-validator-relevant overlays.

## Files/functions to patch

Primary attacker-only patch location:

- `validator/consensus/private-overlay.cpp`
  - `PrivateOverlayImpl::handle(CandidateGenerated)`.

Possible secondary comparison location:

- `validator/consensus/block-sync-overlay.cpp`
  - `BlockSyncOverlayImpl::handle(CandidateReceived)`.

Do not patch clean target. Optional target instrumentation, only if separately agreed, should be logs/counters in:

- `overlay/broadcast-twostep.cpp`
  - `BroadcastsTwostep::process_broadcast(... overlay_broadcastTwostepFec ...)`;
  - `BroadcastsTwostep::gc()`.

## Exact next command/check

Before writing attacker patch, verify the static cap in code and capture line evidence:

```bash
sed -n '117,126p' validator/consensus/private-overlay.cpp
sed -n '199,219p' validator/consensus/private-overlay.cpp
sed -n '134,154p' validator/consensus/block-sync-overlay.cpp
sed -n '542,563p' validator/consensus/simplex/pool.cpp
sed -n '129,187p' overlay/broadcast-twostep.cpp
sed -n '252,269p' overlay/broadcast-twostep.cpp
```

If this cap is confirmed in the local branch, the first attacker-only patch should be explicitly a **cap-check trigger**, not a full DoS harness: attempt N sends, prove whether clean target accepts more than one unique broadcast per acceptable slot, and stop.

## Cap-check verdict

- Slot definition: `slot` is taken from broadcast `extra`, not from the FEC packet itself. In consensus private overlay sender it is serialized as `consensus_broadcastExtra(event->candidate->id.slot)`. In block-sync overlay it is serialized as `tl::broadcastExtra(event->candidate->id.slot)`. Receiver precheck parses this `extra` and uses the parsed `slot` for expected-collator and duplicate checks.
- Broadcast_id relation: `broadcast_id` is computed in `BroadcastsTwostep::send()`/receiver from `flags`, `date`, source validator key hash, source ADNL id, `data_hash`, `data_size`, `part_size`, and `extra`. It is not simply `candidate_id`, but because `extra` contains `slot`, changing `slot` changes `broadcast_id`; changing payload/date/data_hash can also create a different `broadcast_id` for the same slot.
- Receiver allocation before/after cap: allocation is **after** precheck/cap. In `BroadcastsTwostep::process_broadcast(Fec)`, the receiver computes `broadcast_id`, checks duplicate/delivered state, calls overlay `precheck_broadcast(..., signature_checked=false)`, verifies signature, calls `precheck_broadcast(..., signature_checked=true)`, and only then creates `td::raptorq::Decoder`, `BroadcastTwostep`, `lru_` entry and `broadcasts_` entry.
- One-broadcast-per-slot confirmed: yes. `SimplexPool::process(PrecheckCandidateBroadcast)` stores `seen_broadcasts_[slot] = broadcast_id` when `signature_checked=true`; if the same `slot` is later seen with a different `broadcast_id`, it returns `Duplicate broadcast`. With `signature_checked=false`, it also rejects a different `broadcast_id` if the slot was already seen. Therefore same-slot unique-broadcast spam is rejected before receiver-state allocation for the second unique id.
- Can attacker vary slot product-valid: only within tight consensus constraints. The broadcast source must be a validator of the current group and must equal `collator_schedule->expected_collator_for(slot)`. `SimplexPool` also rejects old finalized slots and slots beyond `now_ + max_leader_window_desync * slots_per_leader_window_`. So a Byzantine validator cannot arbitrarily choose unbounded slots; it can only target its scheduled collator slots inside the accepted future window.
- Upper bound per 25s GC window: statically bounded by the number of not-yet-seen slots in the accepted window for which the Byzantine validator is the expected collator. Using the Simplex schedule (`expected_collator_for(slot) = slot / slots_per_leader_window % leaders_count`), the bound is approximately `ceil((max_leader_window_desync + 1) / leaders_count) * slots_per_leader_window`, capped by the global accepted future window and already-seen slots. This is schedule/window bounded, not attacker-unbounded. In realistic multi-validator groups this is a small finite number compared with the thousands of receiver states needed for a credible RSS/OOM claim.
- Verdict: **drop for Critical/High resource-exhaustion**.
- Reason: the relevant receiver allocation happens after the consensus precheck that enforces one accepted `broadcast_id` per slot, and the attacker can only vary slots where it is the expected collator inside the bounded future window. This kills the hypothesized unbounded incomplete-broadcast state accumulation for one Byzantine validator in the validator/private-overlay product path.
- Next action: close CAND-01; do not spend time on a DoS harness. Only a tiny runtime cap-check would be useful if someone disputes the static reading: send two different valid broadcasts for the same slot from the expected collator and confirm the second gets `Duplicate broadcast` without a second `twostep START receiver` allocation.
