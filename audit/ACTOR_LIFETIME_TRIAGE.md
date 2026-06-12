# Actor lifetime / async-state triage

Дата: 2026-06-12.

Цель pass: consensus / validator actor-lifetime, promise/callback, stale async state, certificate-vote-candidate resolver paths. Не PoC, не report draft, не production patch.

## Closed context

- `persistent-state Stage B`: `drop`, product-path failed.
- `CAND-01`: `drop`, twostep FEC allocation after precheck/cap, one accepted broadcast per slot.
- `CAND-02 consensus/private`: `drop`; fast-sync/custom legacy-FEC remains weak and not pursued here.
- `CAND-06`: `drop`, empty fast-sync/custom `check_broadcast` does not leave unresolved promise.
- `HS-03`: only `maybe/drop`; no runtime gate started without a stronger fact.

## Areas checked

Focused grep/review over:

- consensus async actors and bus events: `Promise`, `set_value`, `set_error`, `td::actor`, `send_closure`, `alarm`, `timeout`, `pending`, `postponed`, `wait`, `callback`, `finish`, `abort`, `destroy`, `stop`;
- candidate/certificate/vote/resolver paths: `certificate`, `vote`, `candidate`, `resolver`, `Precheck`, `Final`, `Notar`, `Skip`, `validate`, `from_tl`, `parse`;
- concrete files inspected manually: `validator/consensus/simplex/pool.cpp`, `validator/consensus/simplex/candidate-resolver.cpp`, `validator/consensus/simplex/state-resolver.cpp`, `validator/consensus/block-validator.cpp`, `validator/consensus/private-overlay.cpp`, `validator/consensus/block-sync-overlay.cpp`, `validator/downloaders/*`, `validator/net/download-block-new.cpp`.

Initial grep counts:

- async/promise/lifetime grep: 4207 hits;
- certificate/vote/candidate/resolver grep: 1568 hits;
- focused pending/wait/promise grep: 2347 hits.

## Rejected clusters

- Downloader callbacks (`WaitBlockData`, `DownloadBlockNew`, `DownloadShardState`): timeouts/abort paths are explicit; malformed peer data is rejected by hash/proof/state checks before later invariant checks.
- Private-overlay request callbacks: `OutgoingOverlayRequest` uses query timeout; inbound `on_query` wraps bus processing and returns either response or `requestError`.
- CAND-01/CAND-02/CAND-06-related FEC callbacks were not reopened.
- Generic candidate validation waiters from HS-03 remain bounded by slot/window/pending-block constraints; no new stronger fact found.

## Candidate shortlist

### AL-01 — too-new valid certificate creates far-future slot before being rejected

Verdict: `maybe/drop`; best available in this pass, not `pursue` and not report-ready.

Affected path:

- `PoolImpl::handle(IncomingProtocolMessage)` certificate branch.
- `Certificate<Vote>::from_tl(...)` validation.
- `ConsensusState::slot_at(...)` lazy slot creation.
- `PoolImpl::alarm()` standstill logging / tracked-slots iteration.

Exact functions:

- `validator/consensus/simplex/pool.cpp`: certificate handling branch computes `is_too_new`, skips slot/cert-needs checks for too-new raw votes, validates `Certificate<Vote>::from_tl(...)`, then calls `state_->slot_at(raw_vote.referenced_slot())` and `handle_certificate(...)`.
- `validator/consensus/simplex/state.h`: `slot_at(slot)` creates a slot for any `slot >= first_non_finalized_slot_`.
- `validator/consensus/simplex/pool.cpp`: `alarm()` iterates `state_->tracked_slots_interval()` and calls `state_->slot_at(i)` for every slot in `[begin, end)`.

State inserted:

- A far-future `SlotState` entry can be inserted into `ConsensusState::slots_` for `raw_vote.referenced_slot()` after the certificate passes signature/weight validation.
- `handle_certificate(...)` can also set `certs.*.being_saved = true` before async `SaveCertificate`.

Cleanup path:

- Normal cleanup is `state_->notify_finalized(id.slot)`, which erases slots below finalized slot.
- For a far-future too-new slot, cleanup appears delayed until finalization catches up to that slot.
- Standstill alarm uses tracked interval ending at `slots_.rbegin()->first + 1`; a single far-future slot can make the interval huge if it is inserted.

Attacker model:

- Not a single ordinary Byzantine validator. To pass `Certificate<Vote>::from_tl(...)`, attacker needs a threshold-valid certificate for that far-future slot in the same session.
- This likely requires Byzantine quorum or an already-existing valid future certificate; that is much stronger than the desired one-Byzantine-validator model.

Product reachability:

- Inbound certificate messages are product-path consensus overlay messages.
- However, a threshold-valid certificate for an arbitrarily far-future slot is not shown to be realistically obtainable by a small attacker.

Potential impact:

- If such a cert is product-valid, one message could create a far-future slot and later make `alarm()` iterate/allocate across a huge tracked interval, causing CPU/RSS spike or validator availability loss.
- Current impact remains conditional on an unrealistically strong certificate precondition.

Tiny gate:

- Static/unit-level gate only unless a realistic certificate source is found: in a controlled tiny validator set, deliver one threshold-valid certificate with `referenced_slot` far beyond `first_too_new_slot`, then observe whether `tracked_slots_interval().end` jumps and `alarm()` iterates over the gap.
- No large network harness until realistic certificate acquisition is proven.

PASS:

- Clean target accepts a product-valid too-new certificate from an in-scope attacker model, creates far-future slot state, and standstill alarm causes measurable CPU/RSS/availability impact without prior cap/cleanup.

BLOCKER:

- Certificate cannot be produced by one/few Byzantine validators; future cert requires Byzantine quorum; or slot/window checks are added/confirmed before state insertion in actual product path.

Reason:

- This is a real-looking lifecycle ordering smell with potentially severe impact, but the attacker prerequisite is too strong for `pursue` now.

### AL-02 — WaitForParent request can remain pending after missing/not-yet-notarized parent

Verdict: `maybe/drop`.

Affected path:

- `CandidateReceived` → `Simplex::try_notarize(...)` → `WaitForParent` → `PoolImpl::process(WaitForParent)`.

Exact functions:

- `validator/consensus/simplex/consensus.cpp`: `try_notarize(...)` awaits `WaitForParent` before validation/notarization.
- `validator/consensus/simplex/pool.cpp`: `process(WaitForParent)`, `maybe_resolve_request(...)`, `maybe_resolve_requests()`.

State inserted:

- `PoolImpl::requests_` gets a `Request` with candidate id, parent id, promise and candidate proof data.

Cleanup path:

- Request is removed when `maybe_resolve_request(...)` returns true.
- `maybe_resolve_requests()` is called after saved certificates and can resolve parent/skips/finalization conditions.
- `tear_down()` cancels outstanding promises.

Attacker model:

- Expected collator / Byzantine validator for a slot sends a candidate with a parent that is not yet notarized or whose parent chain is delayed.

Product reachability:

- Candidate broadcast is product path and prechecked by private/block-sync overlay expected-collator rules.

Potential impact:

- A pending parent request can keep a candidate notarization task waiting.
- But consensus can skip slots, and candidate entry is constrained by future-slot cap and one pending candidate per slot.

Tiny gate:

- One Byzantine expected collator sends one signed candidate whose parent points to an unresolved earlier slot; observe whether `requests_` persists after skip/finalization events.

PASS:

- Request remains stuck after expected skip/finalization cleanup and blocks progress/availability beyond bounded slot behavior.

BLOCKER:

- Request resolves on later cert/skip/finalization, or the only impact is the expected ability of a Byzantine leader to make its slot skipped.

Reason:

- Product path is good, but current code suggests bounded/expected consensus behavior, not Critical/High.

### AL-03 — CandidateResolver indefinite resolve loop for missing candidate/cert

Verdict: `drop/maybe`.

Affected path:

- `ResolveCandidate` → `CandidateResolverImpl::process(...)` → `resolve_candidate_task(...)` → repeated `OutgoingOverlayRequest`.

Exact functions:

- `validator/consensus/simplex/candidate-resolver.cpp`: `process(ResolveCandidate)`, `resolve_candidate_inner(...)`, `maybe_resume_resolve_awaiters(...)`.
- `validator/consensus/private-overlay.cpp`: `process(OutgoingOverlayRequest)` query timeout path.
- `validator/consensus/simplex/state-resolver.cpp`: `finalize_blocks_inner(...)` calls `ResolveCandidate` for finalized candidate IDs.

State inserted:

- `state_[candidate_id]` and `resolve_awaiters` entries are created for unresolved candidates.

Cleanup path:

- Awaiters resolve only when both candidate and notarization cert are available, or on actor teardown/cancel.
- Each outgoing request has a timeout and cooldown; no immediate memory leak from a single request.

Attacker model:

- Peer presents references/certificates that cause target to resolve a candidate it does not have.

Product reachability:

- Product path exists through finalization/notarization/candidate resolution.
- To force truly missing candidate with valid final/notar cert, attacker likely needs threshold-valid cert material or relies on honest peers failing to provide data.

Potential impact:

- Resolver task may retry indefinitely with cooldown until candidate/cert appears.
- Current impact is bounded by per-candidate state and request timeout/cooldown, and requires strong cert preconditions for product-valid trigger.

Tiny gate:

- Trigger one `ResolveCandidate` for a valid id whose candidate is unavailable and confirm only one resolver loop exists with bounded retry cadence.

PASS:

- Product-valid single Byzantine input creates unresolved resolver state that blocks consensus progress and persists beyond timeout/cooldown without cap or cleanup.

BLOCKER:

- Requires threshold cert / honest data unavailability; per-candidate retry is bounded and expected; peers eventually return candidate/cert or request remains non-critical.

Reason:

- This is an expected resolver behavior unless tied to a stronger reachable finalization/cert bug.

## Best next candidate

No pursue candidate found.

Best available: `AL-01 — too-new valid certificate creates far-future slot before being rejected` as `maybe/drop`.

Reason:

- Better than HS-03 because it is a single-message lifecycle ordering issue: a too-new certificate is validated before the too-new slot cap is applied, and a valid one can mutate `ConsensusState` far ahead of the current window.
- Worse than a real `pursue` because the message must be threshold-valid for the far-future slot; a single Byzantine validator cannot normally produce it.

Next recommended search area:

- Continue in `validator/consensus/simplex/pool.cpp` and certificate/vote paths, specifically looking for state mutation before slot-window checks that does **not** require threshold-valid certificates.
- A promising next grep is “too-new branch validates/parses before slot cap” across candidate/vote/cert handling.

## Tiny gate plan

For AL-01 only if the certificate precondition can be made realistic:

1. Static micro-check: confirm `PoolImpl::handle(IncomingProtocolMessage)` validates a too-new certificate before calling `state_->slot_at(...)` and before any too-new rejection.
2. Controlled unit/lab gate, not full network harness: minimal validator set where the attacker can produce a threshold-valid certificate for `slot = now + large_delta` in the same session.
3. Send exactly one certificate message to a clean target.
4. Observe:
   - `state_->tracked_slots_interval().end` jumps to far-future slot + 1;
   - next `alarm()` spends time iterating the gap or creates many slots;
   - RSS/CPU/log timing changes are measurable.
5. PASS only if this is achievable under an in-scope attacker model smaller than Byzantine quorum or via a realistic product-path future certificate.
6. BLOCKER if threshold certificate precondition is not in-scope; then AL-01 remains drop/maybe and no harness should be built.

## Commands run

```bash
git status --short
git log --oneline -7
sed -n '1,260p' audit/HIGH_SIGNAL_TRIAGE.md 2>/dev/null || true
sed -n '1,260p' audit/NEXT_CANDIDATES.md 2>/dev/null || true
rg -n "Promise|promise|set_value|set_error|td::actor|send_closure|send_closure_later|alarm|timeout|pending|postponed|wait|waiting|callback|completed|finish|finish_query|abort_query|destroy|stop|hangup" validator/consensus validator/downloaders validator/full-node* validator/manager* validator/net -S
rg -n "certificate|Cert|cert|vote|Vote|candidate|Candidate|resolver|Resolver|Precheck|precheck|Final|Notar|Skip|BlockSignature|validate|from_tl|parse" validator/consensus validator/downloaders validator/full-node* validator/manager* -S
rg -n "pending|postponed|wait|Promise|set_value|set_error|timeout|alarm|candidate|certificate|vote" validator/consensus/simplex validator/consensus validator/downloaders validator/full-node* validator/net -S
sed -n '120,430p' validator/consensus/simplex/candidate-resolver.cpp
sed -n '1,260p' validator/consensus/simplex/state-resolver.cpp
sed -n '360,570p' validator/consensus/simplex/pool.cpp
sed -n '720,900p' validator/consensus/simplex/pool.cpp
sed -n '1,180p' validator/consensus/simplex/certificate.cpp
sed -n '1,260p' validator/consensus/private-overlay.cpp
sed -n '1,170p' validator/consensus/block-validator.cpp
```

## Current verdict

No pursue candidate found.

Best available: `AL-01` as `maybe/drop`, because it has an exact state mutation before effective too-new rejection but currently needs a threshold-valid far-future certificate.

Changed files: `audit/ACTOR_LIFETIME_TRIAGE.md`.

Next action: do **not** build a harness yet; first decide whether a threshold-valid future certificate is an in-scope realistic attacker input. If not, drop AL-01 and continue searching for pre-cap lifecycle mutation reachable from one Byzantine validator.
