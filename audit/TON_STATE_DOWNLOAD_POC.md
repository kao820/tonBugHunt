# PoC plan: persistent-state download unbounded accumulation

Candidate: `DownloadState` retains every full-size `tonNode_downloadPersistentStateSliceV2` response from a selected Byzantine full-node neighbour until short read, timeout, or OOM.

This is **not** a bounty report. It is a staged reproduction artifact. Do not submit until Stage B is run against an unmodified target validator and the collected evidence confirms validator-level impact.

## Scope and non-goals

- Target vulnerable logic must remain unpatched.
- No DEBUG-only target injection.
- No public-overlay Sybil assumption: frame the attacker as one Byzantine full-node neighbour / selected `download_from_`.
- Stage A is a minimal harness for the retention sink only.
- Stage B is the product-path malicious peer reproduction plan.

## Relevant target code path

1. `validator/downloaders/wait-block-state.cpp::WaitBlockState::start()` creates `DownloadShardState` when a persistent-state description is available and state is missing.
2. `validator/downloaders/download-state.cpp::DownloadShardState::checked_proof_link()` calls `ValidatorManager::send_get_persistent_state_request()`.
3. `validator/manager.cpp::ValidatorManagerImpl::send_get_persistent_state_request()` sets the persistent-state download timeout to `3600 * 3`.
4. `validator/full-node-shard.cpp::FullNodeShardImpl::download_persistent_state()` selects `choose_neighbour()` and creates `DownloadState` with that neighbour as `download_from_`.
5. `validator/net/download-state.cpp::DownloadState::got_block_state_part()` appends every full-size chunk to `parts_`, increments `sum_`, and requests the next slice while `data.size() == requested_size`.

## Stage A: retention harness

### File

- `audit/poc_download_state_accumulation.py`

### What it proves

The harness reproduces the exact retention semantics of `DownloadState::got_block_state_part()`:

```cpp
bool last_part = data.size() < requested_size;
sum_ += data.size();
parts_.push_back(std::move(data));
```

It sends repeated malicious responses of exactly `requested_size` bytes, tracks RSS, and verifies that retained bytes can grow past a smaller declared `total_size_` because no cap is applied in the sink.

### Build

No build is required for Stage A. It uses Python 3 and `/proc/self/status` for RSS.

### Run

Safe default: 64 slices * 2 MiB = 128 MiB retained.

```bash
python3 audit/poc_download_state_accumulation.py --slices 64 --slice-size 2097152 --declared-total-size 4194304 --csv audit/poc_download_state_accumulation.csv
```

Larger run with safety stop near 1 GiB RSS:

```bash
python3 audit/poc_download_state_accumulation.py --slices 2048 --slice-size 2097152 --declared-total-size 4194304 --rss-stop-mib 1024 --csv audit/poc_download_state_accumulation_1g.csv
```

### Expected output

- Downloader-style progress lines:

```text
downloading state poc-block : 2.00 MiB/4.00 MiB (... rss=..., retained_chunks=1, last_part=false)
...
```

- Final JSON summary with:

```json
"pass": true,
"retained_chunks": <slices_completed>,
"sum_bytes": <slice_size * slices_completed>,
"malicious_bytes_sent": <same as sum_bytes>,
"last_part": false
```

### Stage A pass criteria

- `pass == true`.
- `sum_bytes > declared_total_size`.
- `retained_chunks == slices_completed`.
- `last_part == false` for every full-size response.
- RSS grows roughly with retained bytes.

### Stage A fail criteria

- The harness short-reads unexpectedly.
- RSS does not grow while chunks are retained.
- The summary reports `pass == false`.


## Stage B artifact status

Concrete Stage B artifacts are now split into:

- `audit/stage_b_malicious_fullnode.patch`: attacker-only patch for the malicious full-node checkout.
- `audit/STAGE_B_PRODUCT_PATH_RUNBOOK.md`: русскоязычный runbook с clean-target / attacker-checkout / seed-tool сборкой и donor/extractor flow без ручных BlockIdExt placeholders.
- `audit/stage_b_tontester_topology.py`: исполняемый tontester runner для donor/localnet extraction, stopped-target DB-seed, topology `clean target + attacker-only node` и сбора RSS/logs.
- `audit/stage_b_seed_tool.patch`: отдельный setup-tool patch для записи `PersistentStateDescription` в stopped target DB без patch target binary.
- `audit/collect_target_rss.sh`: one-second RSS sampler for the clean target process.

The target validator must be built from a clean checkout without the attacker patch. Apply the patch only in the attacker checkout.

## Stage B: product-path malicious full-node neighbour

Stage B should run an **unmodified target validator** and a separate malicious full-node peer binary/config. Only the attacker peer is modified to serve malicious persistent-state responses.

### Attacker implementation points

Implement attacker behavior in the malicious node only:

- `validator/full-node-shard.cpp::FullNodeShardImpl::process_query(ton_api::tonNode_preparePersistentState&)`
  - If malicious mode is enabled, return `tonNode_preparedState` without consulting DB.
- `validator/full-node-shard.cpp::FullNodeShardImpl::process_query(ton_api::tonNode_getPersistentStateSizeV2&)`
  - Return `tonNode_persistentStateSize(<large declared size>)`, for example 1 TiB.
- `validator/full-node-shard.cpp::FullNodeShardImpl::process_query(ton_api::tonNode_downloadPersistentStateSliceV2&)`
  - Return `BufferSlice(query.max_size_)` filled with deterministic bytes on every request.
  - Log `slice_no`, `query.offset_`, `query.max_size_`, and cumulative malicious bytes sent.
  - Do not short-read.

A minimal attacker-only guard can be an environment variable such as `TON_POC_MALICIOUS_STATE=1`. This is local attacker behavior, not a target-side DEBUG injection.

### Target setup requirement

Make the malicious peer the selected persistent-state source without relying on a Sybil assumption. In local reproduction, use one of these approaches:

1. Configure the local test network so the target full-node shard overlay has the malicious peer as the only eligible neighbour for the relevant shard; or
2. In a controlled integration network, start the malicious node first/only as the persistent-state-serving neighbour and verify target logs show `downloading state ... from <malicious_adnl>`; or
3. If a temporary routing aid is used, apply it only to the local topology/peer selection harness and not to the vulnerable `DownloadState` logic. The final evidence must still show `FullNodeShardImpl::download_persistent_state()` creating `DownloadState` with the malicious `download_from_`.

### Stage B commands to build

Use the repository's normal CMake flow for the target and attacker builds. Example:

```bash
cmake -S . -B build-poc -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build-poc --target validator-engine -j"$(nproc)"
```

If using an attacker-only patch, build the attacker binary from the patched checkout and the target binary from a clean checkout of the same `testnet` commit.

### Stage B runtime metrics to collect

Collect all of the following:

- Target process RSS over time:

```bash
while kill -0 "$TARGET_PID" 2>/dev/null; do date +%s; awk '/VmRSS|VmHWM/ {print}' /proc/"$TARGET_PID"/status; sleep 1; done | tee target_rss.log
```

- Target downloader progress logs containing `downloading state`.
- Attacker logs:
  - `slice_no`;
  - requested `offset`;
  - requested/returned `max_size`;
  - cumulative malicious bytes sent.
- Outcome classification:
  - target aborts;
  - switches peer;
  - times out;
  - OOMs/restarts;
  - or stays healthy.

### Stage B pass criteria

- Target log shows `DownloadState` started from the malicious ADNL peer.
- Target repeatedly issues `tonNode_downloadPersistentStateSliceV2` with increasing offsets.
- Attacker responds exactly `requested_size` bytes each time.
- Attacker `malicious_bytes_sent` equals target retained-progress `sum_` within transport overhead expectations.
- Target RSS grows approximately linearly with the number of successful full-size slice responses.
- Growth continues beyond the declared/realistic state size or until OOM/timeout.
- No target-side vulnerable logic is patched.

### Stage B fail/close criteria

- Target cannot be made to select the malicious neighbour in a product-path local network.
- Target quickly aborts or switches peer before meaningful RSS growth.
- A global token/memory limiter not visible in Stage A caps the download.
- RSS remains bounded despite repeated full-size responses.
- The only working reproduction requires DEBUG-only target injection.

## Archive contents for TON submission if Stage B passes

Create an archive containing:

- Clean target commit hash and branch name.
- Attacker-only patch or malicious peer source files.
- Exact target and attacker build commands.
- Local network configuration files.
- Target logs with `downloading state ... from <malicious_adnl>` and progress lines.
- Attacker logs with slice counters and bytes sent.
- `target_rss.log`.
- A short `README.md` explaining pass/fail and how to re-run.
- Optional Stage A CSV/summary as supporting evidence, not primary proof.
