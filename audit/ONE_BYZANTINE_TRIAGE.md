# One-Byzantine validator triage

Дата: 2026-06-12.

Цель pass: только one-Byzantine-validator / one-authorized-private-overlay-member inputs, без threshold/quorum certificates, public Sybil, local/debug, resource spam и старых закрытых веток.

## Closed context

- `persistent-state Stage B`: `drop`, product-path failed.
- `CAND-01`: `drop`, twostep FEC capped by precheck/one broadcast id per slot.
- `CAND-02 consensus/private`: `drop`.
- `CAND-06`: `drop`.
- `HS-03`: `maybe/drop`, no runtime gate.
- `AL-01`: reviewed below and closed for now for one-Byzantine model.

## AL-01 verdict

Question: can one Byzantine validator create a threshold-valid far-future certificate in a realistic in-scope model?

Answer: no / not shown. `Certificate<Vote>::from_tl(...)` requires enough unique validator signatures to exceed the two-thirds threshold. A single Byzantine validator can sign its own vote, but cannot produce a threshold-valid far-future certificate without Byzantine quorum, compromised keys, or an already-existing threshold certificate. Therefore AL-01 is `drop for now` for the requested one-Byzantine model. Do not build a gate/harness for AL-01 unless a new product-path fact shows realistic threshold-valid future cert availability.

## Areas checked

Focused one-validator grep/review over:

- candidate broadcast from expected collator;
- vote / notarize / skip / finalize vote handling;
- candidate precheck and private/block-sync overlay authorization;
- certificate branch only to close threshold-cert paths;
- resolver and pending state triggered by one candidate/vote;
- assert/promise/callback paths in consensus, downloaders, full-node and net files.

Initial grep counts:

- one-validator path grep: 2810 hits;
- assert/promise/async grep: 1914 hits.

## Rejected clusters

- Threshold certificate paths: dropped for this pass because one Byzantine validator cannot create a valid threshold cert.
- Public/full-node broadcast and legacy FEC paths: not revisited; not one-validator consensus lifecycle.
- Downloader and full-node peer paths: not relevant to one-Byzantine-validator consensus message model in this pass.
- Generic resource-spam paths: ignored unless a single/few product-valid messages mutate state before cap and can stall/crash.

## Candidate shortlist

### OB-01 — rejected candidate remains as `pending_block` for its slot

Verdict: `maybe/drop`; best next candidate, but not `pursue` and not report-ready.

Affected path:

- Expected collator sends candidate broadcast.
- Clean target stores `slot->state->pending_block = candidate` before parent resolution and block validation.
- If validation rejects, `pending_block` is not cleared in the visible rejection path.

Exact functions:

- `validator/consensus/private-overlay.cpp`: candidate broadcast callback deserializes candidate from the expected private-overlay source and publishes `CandidateReceived`.
- `validator/consensus/block-sync-overlay.cpp`: same product path for block-sync overlay candidate broadcast.
- `validator/consensus/types.cpp`: `Candidate::deserialize(...)` enforces expected slot/source and candidate signature before publishing.
- `validator/consensus/simplex/consensus.cpp`: `Simplex::handle(CandidateReceived)` sets `slot->state->pending_block = candidate`, then starts `try_notarize(...)`.
- `validator/consensus/simplex/consensus.cpp`: `try_notarize(...)` logs `CandidateReject` and returns without clearing `pending_block`.

Input type:

- One signed candidate broadcast from the expected collator for a currently accepted slot.

Can one Byzantine validator produce it:

- Yes, if that validator is the expected collator for the slot. It can sign a syntactically valid candidate whose block validation later rejects.

Required role for slot:

- Expected collator/leader for that slot, enforced by overlay precheck and `Candidate::deserialize(...)`.

Precheck/auth before mutation:

- Private/block-sync overlay membership and expected-collator precheck.
- Candidate TL parse, max size checks, source field check, leader signature check.
- Slot too-new cap and one pending candidate per slot are checked before `pending_block` insertion.

State mutation:

- `pending_block` is set before `WaitForParent`, `ResolveState`, and `ValidationRequest` complete.
- On `CandidateReject`, the observed code returns without clearing `pending_block`.

Caps/cleanup:

- One pending block per slot; same-slot alternatives are ignored.
- Slot/window caps reject too-future candidates.
- Consensus timeout can still produce skip votes for the window; finalization/skips eventually advance state.

Impact:

- A Byzantine leader can poison its own slot with an invalid candidate and prevent later replacement for that slot.
- Current impact appears equivalent to expected Byzantine collator failure for that slot; likely skip/fallback handles liveness. Not Critical/High unless it blocks beyond normal skip/finalization.

Tiny gate:

- In a local small validator group, make the expected collator send exactly one signed candidate that passes `Candidate::deserialize(...)` but is rejected by `validate_block_candidate`.
- Observe whether target logs `Candidate ... is rejected`, keeps `pending_block`, ignores a later valid same-slot candidate, and still proceeds via skip/finalization.

PASS:

- `pending_block` persists after rejection, blocks same-slot recovery, and prevents skip/finalization/progress beyond normal Byzantine leader assumptions.

BLOCKER:

- Slot is skipped/finalized normally; bounded one-slot effect; or protocol intentionally treats a bad leader candidate as slot failure.

Reason:

- This is the best one-validator lifecycle mutation found, but it is probably expected consensus behavior and bounded to the attacker's leader slot.

### OB-02 — invalid/duplicate one-validator vote creates slot before signature verification

Verdict: `drop`.

Affected path:

- `PoolImpl::handle(IncomingProtocolMessage)` vote branch.

Exact functions:

- `validator/consensus/simplex/pool.cpp`: incoming vote branch parses unsigned vote, checks too-new/too-old, calls `state_->slot_at(referenced_slot)`, checks `votes[source].wants(...)`, then verifies the signed vote via `Signed<Vote>::from_tl(...)`.
- `validator/consensus/simplex/state.h`: `slot_at(...)` lazily creates slot state.

Input type:

- One vote-like protocol message from a validator source.

Can one Byzantine validator produce it:

- Yes, but meaningful mutation is limited.

Required role for slot:

- Any validator can vote; no collator role required.

Precheck/auth before mutation:

- Source is a consensus private-overlay member.
- Too-new and finalized-slot checks happen before `slot_at(...)`.
- Signature verification happens after `slot_at(...)`.

Mutation/danger:

- A slot can be lazily created for a within-window referenced slot before signature verification.

Caps/cleanup:

- Too-new cap before mutation bounds the slot range.
- One vote type per validator per slot; duplicate/conflict handling is bounded by validator-set size.
- Slots are cleaned by finalization.

Impact:

- Bounded slot creation within current desync window. No crash/stall/availability impact beyond normal consensus state.

Tiny gate:

- Not recommended. One invalid signed vote should at most create bounded slot state and then be rejected/banned.

PASS:

- Reopen only if a single validator can create unbounded slots or state beyond the too-new cap.

BLOCKER:

- Window cap before mutation and bounded validator/slot state. Drop.

Reason:

- This is a real mutation-before-signature pattern, but the effective window cap makes impact weak.

### OB-03 — unresolved parent candidate leaves `WaitForParent` request pending

Verdict: `maybe/drop`.

Affected path:

- Candidate from expected collator with parent not yet notarized.
- `Simplex::try_notarize(...)` awaits `WaitForParent` before validation/notarization.

Exact functions:

- `validator/consensus/simplex/consensus.cpp`: `try_notarize(...)` awaits `owning_bus().publish<WaitForParent>(candidate)`.
- `validator/consensus/simplex/pool.cpp`: `process(WaitForParent)` inserts a `Request` into `requests_` and calls `maybe_resolve_request(...)`.
- `validator/consensus/simplex/pool.cpp`: `maybe_resolve_requests()` rechecks pending requests when certificates/skips/finalization change.

Input type:

- One signed candidate from expected collator with a product-valid but currently unresolved parent chain.

Can one Byzantine validator produce it:

- Yes, if it is expected collator for the candidate slot and can choose the parent reference.

Required role for slot:

- Expected collator/leader for that slot.

Precheck/auth before mutation:

- Candidate source/slot/signature prechecks happen before `CandidateReceived`.
- Slot too-new and one `pending_block` checks happen before `try_notarize(...)`.

Mutation/danger:

- A `WaitForParent` request with promise is inserted into `requests_` if parent/skip conditions are not yet resolvable.

Caps/cleanup:

- One pending candidate per slot.
- Requests are re-evaluated on certificate/skip/finalization changes.
- `tear_down()` cancels outstanding promises.

Impact:

- Possible wait until parent/skip/finalization. Current code suggests expected bounded behavior, not availability loss.

Tiny gate:

- One candidate with unresolved parent; observe whether `requests_` remains after expected skip/finalization. Only useful with tiny read-only instrumentation.

PASS:

- Request persists after all relevant skip/finalization events and blocks progress beyond bounded slot behavior.

BLOCKER:

- Request resolves when certificates/skips arrive, or effect is just normal bad-collator slot skip.

Reason:

- Product path exists, but cleanup/resolution hooks are visible and the effect is likely bounded.

## Best next candidate

No pursue candidate found in one-Byzantine pass.

Best available: `OB-01 — rejected candidate remains as pending_block for its slot` as `maybe/drop`.

Reason:

- It is better than AL-01 because it only needs one Byzantine expected collator, not a threshold-valid certificate.
- It is worse than a real `pursue` because the effect appears bounded to one leader slot and likely reduces to normal Byzantine collator failure handled by skip/finalization.

Recommendation: stop automated grep-style search and switch to manual review of `validator/consensus/simplex/consensus.cpp::try_notarize` and `validator/consensus/simplex/pool.cpp::WaitForParent` interactions, specifically checking whether rejected or unresolved candidates can block progress beyond normal skip semantics.

## Current verdict

No pursue candidate found in one-Byzantine pass.

Current verdict: `done` with `OB-01` as best `maybe/drop` candidate.

Changed files: `audit/ONE_BYZANTINE_TRIAGE.md`.

Next action: do not write PoC/report. If continuing, do a tiny read-only instrumentation gate for OB-01, or manually audit whether `pending_block` should be cleared on `CandidateReject` and whether not clearing has any consensus-liveness consequence.

## Commands run

```bash
git status --short
git log --oneline -8
sed -n '1,260p' audit/ACTOR_LIFETIME_TRIAGE.md 2>/dev/null || true
sed -n '1,260p' audit/HIGH_SIGNAL_TRIAGE.md 2>/dev/null || true
sed -n '1,260p' audit/NEXT_CANDIDATES.md 2>/dev/null || true
rg -n "Precheck|precheck|Candidate|candidate|Vote|vote|BlockSignature|signature|Notar|Skip|certificate|Certificate|handle_.*vote|handle_.*candidate|handle_.*certificate|process\(|pending|postponed|wait|resolver|too_new|too_old|unknown|expected|collator|leader|slot" validator/consensus/simplex validator/consensus validator/downloaders validator/full-node* validator/net -S
rg -n "CHECK\(|DCHECK\(|UNREACHABLE|\.at\(|\.value\(|LOG\(FATAL\)|td::actor|Promise|set_value|set_error|send_closure|timeout|alarm" validator/consensus/simplex validator/consensus validator/downloaders validator/full-node* validator/net -S
sed -n '390,475p' validator/consensus/simplex/pool.cpp
sed -n '520,560p' validator/consensus/simplex/pool.cpp
sed -n '630,705p' validator/consensus/simplex/pool.cpp
sed -n '150,240p' validator/consensus/simplex/consensus.cpp
sed -n '780,830p' validator/consensus/simplex/pool.cpp
sed -n '100,245p' validator/consensus/types.cpp
```
