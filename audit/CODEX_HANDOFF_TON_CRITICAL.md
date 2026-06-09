# TON Critical-Only Audit Handoff for Codex

Repository: `kao820/tonBugHunt` fork of `ton-blockchain/ton`  
Branch to audit: `testnet`  
Primary goal: find only reproducible Critical candidates affecting TON validator safety/liveness/availability.

This file is a working memory map for Codex. Treat it as guidance, not as proof. For any actual report, official TON rules and current `testnet` code override this handoff.

---

## 0. Mandatory official-rule check

At the start of every serious pass, re-check the current official rules if network access is available:

- TON Consensus Bug Bounty Challenge: https://contest.com/docs/TonConsensusChallenge
- TON security bug bounty README: https://github.com/ton-blockchain/bug-bounty
- Reference implementation: https://github.com/ton-blockchain/ton/tree/testnet

Use the current official rules as source of truth. If any instruction in this handoff conflicts with the official rules, follow the official rules.

### Rules that matter most for this task

From the TON Consensus Challenge rules:

- The current `testnet` branch is the reference implementation.
- Only issues reproduced by the participant should be submitted.
- Do not submit before reproducing.
- Each report must include a reproduction script or an archive with the full reproduction.
- Reports must be real, in scope, actionable, and verifiable.
- Speculative, unverifiable, incomplete, duplicate, low-quality, spam, or AI-generated slop reports may be ignored.
- LLM usage is allowed, but every claim must be validated before submission.
- Low-effort AI-generated reports may be ignored and can lead to suspension.

Resource-exhaustion candidates are only interesting if they satisfy the official bar, for example:

- superlinear resource growth under the admissible attacker model; or
- linear growth that can still realistically DoS an average validator, such as requiring more bandwidth than a 1 Gbps validator link can provide.

For general TON bug bounty scope, keep in mind:

- TON is interested in critical vulnerabilities such as crash, loss/theft of coins, and severe node/service impact.
- Local host compromise, local files, runtime parameters, environment variables, startup flags, trusted operator inputs, and local debug-only workflows are generally out of scope unless they clearly escalate to normal network impact.
- Behavior with no realistic exploitation path in normal network operation is not enough.
- Known design/implementation peculiarities are not enough unless a new real security impact is demonstrated.

---

## 1. AI / LLM compliance rules

Codex may use AI reasoning, but must not produce AI slop.

Rules for this audit:

1. Treat every model-generated idea as an untrusted hypothesis.
2. Do not claim a vulnerability exists until code path, attacker model, product-path reachability, and impact are verified.
3. Never submit or recommend submitting a report based only on static suspicion.
4. Always separate `hypothesis`, `verified fact`, `PoC result`, and `report-ready conclusion`.
5. If a candidate needs local runtime data, return one minimal test plan with exact metrics to collect.
6. If official rules changed, summarize the change and adjust the triage criteria.
7. If internet access is unavailable and official rules cannot be refreshed, state that limitation explicitly.

Output must be useful for a human triager, not padded. Prefer closing weak branches quickly and moving to the next area.

---

## 2. Critical-only bar

Only continue a branch if it could realistically produce one of these impacts:

- validator-engine crash reachable from network/product path;
- validator OOM or uncontrolled RSS growth;
- sustained CPU exhaustion that can DoS an average validator;
- consensus liveness failure or block production stall;
- persistent poisoning or unrecoverable bad state;
- invalid block/state acceptance with validator-level impact;
- bypass of a significant production limit with real validator impact.

Close the branch if it is only:

- a `LOG(ERROR)` or clean `Status::Error`;
- a rejected packet/message;
- a harness-only, debug-only, probe-only, or local-only behavior;
- import-db, hardfork, local tools, CLI-only, or trusted-operator path;
- a style, hygiene, status-code, or hardening issue without Critical impact;
- an expected protocol behavior;
- a known TON peculiarity without new impact;
- a duplicate of a rejected branch below.

---

## 3. Required evidence for a strong candidate

For every strong candidate, return:

1. exact source files and functions;
2. entry point and product-path reachability;
3. attacker model;
4. why the attacker can trigger it in normal network operation;
5. expected impact and why it meets the official Critical bar;
6. why it is not one of the rejected branches below;
7. minimal local PoC plan;
8. metrics to collect;
9. pass/fail criteria;
10. proposed fix.

Do not ask the user to run commands until a concrete strong candidate exists.

When asking for a local test, keep it minimal. The user prefers one focused test, not long fragile command chains.

---

## 4. Do-not-repeat map: rejected / weak / old branches

Do not reopen these unless there is a new concrete fact that changes reachability or impact.

### Simplex / certificates / voting

- H7-A: `Notarize + Skip` as a protocol violation.
  - Closed: TON Simplex permits `Notar + Skip` coexistence; not a report by itself.
- H7-B: `FinalCert + Skip` crash as a direct consequence of H7-A.
  - Closed unless separately proven; it does not follow from H7-A.
- H7-C: order-dependent `available_base` / `skip_intervals_` divergence.
  - Only interesting if a robust diff-state / liveness PoC proves stable harmful divergence.
- H7-D: bootstrap `voted_notar + voted_skip`.
  - Treated as expected behavior.
- Future certificate / far-future slot amplification.
  - Closed for product-path: prior evidence involved DEBUG ONLY simulated future slots / local injection.
- `cert_async_check`.
- `finalcert_state_resolver`.
- `candidate_resolver`.
- delegated source crash.

### External messages / broadcast

- External-message per-address limiter bypass.
  - Closed by product-path test: 60 unique same-seqno messages to one address produced 30 accepted and 30 `too many external messages to address`; final seqno stayed at one applied transaction for the batch.
- Sequential future-seqno external test.
  - Closed as invalid test design.
- `external_message_old_broadcast`.
- `external_message_precheck_side_effect`.
- External-message broadcast cache branch.
  - Closed as weak in Codex pass: parsed/deduped by hash and broadcast hash sets clear on alarm; not persistent enough for Critical without new facts.

### Overlay / broadcast / sync / observer

- private overlay broadcast/source.
- private overlay members.
- block broadcast.
- block candidate broadcast.
- block candidate cache DoS.
- block sync extra.
- observer actor routing.
- observer block sync.
- observer cache candidate.
- `runtime_route_diag` / `before_sync`.
- `sinks_round1`.
- `shard_block_description`.

### Compression / RLDP / QUIC / full-node

- compressed v2 DoS.
- QUIC direction-confusion TODO.
  - Closed as weak unless a new concrete validator crash/stall/RSS/CPU impact is found.
- RLDP2 inbound-state branch.
  - Closed as weak in Codex pass: inbound state exists, but ADNL/RLDP2 packet, peer, timeout, and MTU bounds were found; no single-path Critical OOM/RSS repro.
- Full-node query rate-limit gap.
  - Closed as hardening/non-Critical unless an unlisted query is shown to cause validator crash/OOM/liveness failure.
- `impact_blockdata`.
- `fetch_account_state`.
- liteserver block lookup.

### Local-only / out-of-scope

- hardfork paths.
- import-db paths.
- local tools / CLI-only / debug-only paths.
- stubs, preliminary testing implementations, deprecated components.

---

## 5. Important lessons from prior local testing

External-message runtime lessons:

- Product-path matters. A `sendfile` that does not reach `external message status is 1` does not prove impact.
- Before runtime tests, verify live cluster, fresh masterchain, and a working liteserver.
- In the prior local cluster, node4 was more reliable than node2 for liteserver calls.
- Stale DHT processes can interfere.
- `mode=2` with low amount proved the external path where earlier `mode=3` hit `invalid action 37`.
- Shell prompt `>` usually means broken shell quoting/heredoc, not a network hang.

Do not build a report from dirty/probe/debug patches. Dirty harness evidence can guide research but does not establish product-path impact.

---

## 6. Current candidate worth checking carefully

### `validator/net/download-state.cpp` memory accumulation

Status: candidate only, not a report.

Hypothesis:

`DownloadState::got_block_state_part()` accumulates downloaded persistent-state chunks in memory via `parts_` and `sum_`. Each individual chunk is bounded, but `sum_` may not be hard-capped against `total_size_` before `parts_.push_back`. A malicious state-download peer might send repeated full-size chunks and force the downloader to retain many chunks until timeout or OOM.

To make this strong, prove all of the following:

- a malicious peer can realistically become `download_from_`;
- an honest validator accepts repeated full-size state parts from that peer;
- RSS grows substantially before validation/hash rejection;
- timeout, concurrency, and global limits do not make it non-Critical;
- validator liveness/sync is affected;
- reproduction uses product-path behavior, not debug injection.

If any of those fail, close this branch and continue.

Likely fix if proven:

- enforce `sum_ <= total_size_` when `total_size_` is known;
- add a hard maximum downloaded state byte cap;
- reject chunks larger than requested;
- stream chunks to temp storage and validate incrementally instead of retaining all chunks in memory;
- abort on impossible progress or too many full-size chunks.

---

## 7. Suggested search strategy for next Codex pass

Do not spend the entire pass on old closed areas. Use a broad but strict triage sweep:

1. Search for network-reachable `CHECK`, `LOG_CHECK`, `UNREACHABLE`, `fatal`, `abort`, and unchecked `narrow_cast`.
2. Prioritize paths fed by ADNL / RLDP / overlay / full-node / validator session / consensus messages.
3. Exclude local tools, test code, debug paths, import-db, hardfork, and trusted operator inputs.
4. For every suspicious sink, trace backwards to an external or Byzantine-validator-controlled input.
5. For resource candidates, look for unbounded maps, vectors, queues, timers, caches, or per-peer state not tied to realistic limits.
6. For consensus candidates, verify against TON Simplex docs and the current `testnet` implementation, not generic protocol intuition.
7. Close weak candidates and continue; do not stop at the first hardening issue.

---

## 8. Output format for Codex

Return one of two formats.

### If a strong candidate is found

```text
STRONG CANDIDATE FOUND

Title:

Files/functions:

Product path:

Attacker model:

Impact:

Why this meets official TON rules:

Why this is not a duplicate of rejected branches:

Minimal local PoC plan:

Metrics to collect:

Expected pass/fail:

Proposed fix:
```

### If no strong candidate is found

```text
NO REPRODUCIBLE CRITICAL CANDIDATE FOUND IN THIS PASS

Official rules checked:
- URL/date or note if unavailable

Branches checked and closed:
1.
2.
3.

Why closed:
1.
2.
3.

Potential weak hardening findings, not report-ready:
1.
2.

Next recommended areas:
1.
2.
3.

Code changes:
- none, unless explicitly requested
```

---

## 9. Reminder

The goal is to help TON triage real Critical issues. Do not generate noise. A clean `no candidate found` pass is better than an AI-shaped speculative report.
