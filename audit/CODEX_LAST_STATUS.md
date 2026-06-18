# FNSERVE-MASTER-01 reproducible private topology — 2026-06-18

`FNSERVE-MASTER-01 = pursue / private-topology-ready / runtime-PoC-not-executed / not report-ready`.

## Reproducible harness result

- A clean current-worktree build succeeded with Clang 17 without product-source compatibility patches.
- Matching `validator-engine`, `validator-engine-console`, `create-state`, `fift`, and `lite-client` binaries were built; the topology-required `dht-server`, `generate-random-id`, and `tonlibjson` artifacts were built in the same tree.
- The setup uses Python 3.14 or newer rather than patching Python 3.12 annotation sites.
- Generated smart-contract Fift files are taken from the matching CMake generation output instead of copied into a production config.
- Every topology start uses a new workdir run directory, preventing stale `keyring` collisions without destructive cleanup.
- The private `test/tontester` topology started on `127.0.0.1`, produced masterchain block 2, and generated `$HOME/ton-fnserve-master-01-topology/env/fnserve_master_01.env` with all eight required variables.
- `FNSERVE_MODE=plan` completed without sending request traffic. `FNSERVE_MODE=run` was not executed.

## Reproducible commands

```bash
FNSERVE_TOPOLOGY_MODE=build-start \
FNSERVE_BUILD_DIR="$HOME/ton-fnserve-master-01-build" \
FNSERVE_BUILD_JOBS=12 \
bash audit/fnserve_master_01_topology/setup_local_fullnodemaster.sh

source "$HOME/ton-fnserve-master-01-topology/env/fnserve_master_01.env"
FNSERVE_MODE=plan bash audit/run_fnserve_master_01_local.sh
```

## Safety status

- Local/private host only: `127.0.0.1`.
- No public TON network configuration is loaded.
- No production config is mutated; tontester writes a copied config under the audit workdir.
- Topology lifetime is bounded by `FNSERVE_TOPOLOGY_MAX_SECONDS` and PID/log/env files stay under `$HOME/ton-fnserve-master-01-topology`.
- No `git clean`, destructive topology cleanup, or PoC request traffic was used.

---

# FNSERVE-MASTER-01 topology tonapi fix — 2026-06-16

`FNSERVE-MASTER-01 = pursue / confirmed-for-bounded-local-PoC / topology-tonapi-generation-added / not report-ready`.

## Fix for `ModuleNotFoundError: No module named 'tonapi'`

The correct repo-local source for Python TL bindings is the tontester generator:

- generator: `test/tontester/src/tl/gen.py`
- schemas: `tl/generate/scheme/lite_api.tl`, `tl/generate/scheme/ton_api.tl`, `tl/generate/scheme/tonlib_api.tl`
- existing repo entrypoint: `test/tontester/generate_tl.py`, which normally generates into `test/tontester/src/tonapi`

The audit topology package now generates the same `tonapi` package under the topology workdir instead of mutating the source tree:

- generated/located `tonapi` path: `$HOME/ton-fnserve-master-01-topology/python/tonapi`
- `PYTHONPATH` prefix used by the harness: `$HOME/ton-fnserve-master-01-topology/python:/workspace/tonBugHunt/test/tontester/src`

## Files updated

- `audit/fnserve_master_01_topology/ensure_tonapi.py` — new helper that generates `lite_api.py`, `ton_api.py`, and `tonlib_api.py` from repo TL schemas into the audit workdir and validates imports.
- `audit/fnserve_master_01_topology/setup_local_fullnodemaster.sh` — now calls `ensure_tonapi.py` before topology start, records import validation in `logs/python_import_check.log`, exports the generated package path in `PYTHONPATH`, and includes the generated `tonapi` path in `FORMAT FNSERVE_TOPOLOGY_READY` output.
- `audit/fnserve_master_01_topology/README.md` — documents local TL generation, import validation, and no external `pip install tonapi` dependency.
- `audit/CODEX_LAST_STATUS.md` — this status update.

## Exact setup command

```bash
FNSERVE_TOPOLOGY_MODE=start \
FNSERVE_BUILD_DIR=/path/to/local/build \
bash audit/fnserve_master_01_topology/setup_local_fullnodemaster.sh
```

## Exact plan command

```bash
source "$HOME/ton-fnserve-master-01-topology/env/fnserve_master_01.env"
FNSERVE_MODE=plan bash audit/run_fnserve_master_01_local.sh
```

## Expected env variables

- `FNSERVE_CONFIG`
- `FNSERVE_MASTER_HOST=127.0.0.1`
- `FNSERVE_MASTER_PORT`
- `FNSERVE_MASTER_PUBKEY_TL_HEX`
- `FNSERVE_ZERO_STATE_BLOCK`
- `FNSERVE_BLOCK_ID`
- `FNSERVE_TARGET_PID`
- `FNSERVE_VALIDATOR_ENGINE`

## What was not executed

No topology start, public TON network access, PoC request traffic, or report generation was executed by this Codex task.

---

# FNSERVE-MASTER-01 topology setup update — 2026-06-16

`FNSERVE-MASTER-01 = pursue / confirmed-for-bounded-local-PoC / BLOCKER_LOCAL_TOPOLOGY until private topology env is produced / not report-ready`.

## Local topology package created

Created a repo-local, private-only setup path for the missing full-node-master run variables:

- `audit/fnserve_master_01_topology/setup_local_fullnodemaster.sh`
  - `FNSERVE_TOPOLOGY_MODE=plan` prints the setup/run plan only.
  - `FNSERVE_TOPOLOGY_MODE=start` starts a private `test/tontester` validator/fullnode topology under `${FNSERVE_TOPOLOGY_WORKDIR:-$HOME/ton-fnserve-master-01-topology}`.
  - The generated topology injects one `engine.validator.fullNodeMaster` entry into the in-memory copied tontester local config before validator-engine writes its workdir config; production configs are not mutated.
  - The topology is bounded by `FNSERVE_TOPOLOGY_MAX_SECONDS` and writes PID/log/env files under the audit workdir.
- `audit/fnserve_master_01_topology/extract_fullnodemaster_env.py`
  - Reuse/extract mode for an existing local/private config that already contains `fullnodemasters`.
  - Refuses non-local master hosts.
  - Emits `FORMAT FNSERVE_TOPOLOGY_BLOCKED` if any required run variable cannot be derived.
- `audit/fnserve_master_01_topology/README.md`
  - Documents plan/start/reuse modes and how to feed the generated env file into the bounded PoC wrapper.
- `audit/run_fnserve_master_01_local.sh`
  - Now auto-loads `${FNSERVE_TOPOLOGY_ENV:-$HOME/ton-fnserve-master-01-topology/env/fnserve_master_01.env}` when present.
  - Plan output now includes the topology setup command.

## Variables produced on successful topology start

The setup helper writes `$HOME/ton-fnserve-master-01-topology/env/fnserve_master_01.env` with:

- `FNSERVE_CONFIG`
- `FNSERVE_MASTER_HOST=127.0.0.1`
- `FNSERVE_MASTER_PORT`
- `FNSERVE_MASTER_PUBKEY_TL_HEX`
- `FNSERVE_ZERO_STATE_BLOCK`
- `FNSERVE_BLOCK_ID`
- `FNSERVE_TARGET_PID`
- `FNSERVE_VALIDATOR_ENGINE`

## Exact setup command

```bash
FNSERVE_TOPOLOGY_MODE=start \
FNSERVE_BUILD_DIR=/path/to/local/build \
bash audit/fnserve_master_01_topology/setup_local_fullnodemaster.sh
```

## Exact plan command after setup

```bash
source "$HOME/ton-fnserve-master-01-topology/env/fnserve_master_01.env"
FNSERVE_MODE=plan bash audit/run_fnserve_master_01_local.sh
```

## What was not executed

No topology start, build, public network access, PoC traffic, or report-generation was executed by this Codex task.

## Safety guarantees

- Local/private only: full-node-master host is `127.0.0.1`.
- No public IPs or public network.
- No production config mutation; generated configs live under `$HOME/ton-fnserve-master-01-topology`.
- No destructive cleanup and no `git clean`.
- Strict timeout via `FNSERVE_TOPOLOGY_MAX_SECONDS`.
- PID and logs are written under the audit workdir.
- The topology setup script sends no `downloadZeroState` or `downloadBlockFull` PoC traffic; traffic is only possible if the operator separately runs `FNSERVE_MODE=run` in the bounded wrapper.

---

FULLNODE_SERVE_PASS_MARKER_20260612
# CODEX_LAST_STATUS

STATUS: parked / runtime-trigger-blocked / not closed / not report-ready / no-runtime-executed

Candidate: CN-ARCHIVE-01




## FNSERVE-MASTER-01 client helper update (2026-06-12)

Status: `FNSERVE-MASTER-01 = pursue / client-helper-prepared / confirmed-for-bounded-local-PoC / not report-ready / no-runtime-executed`.

### Tooling discovery result

No existing repo-local command-line tool was found that sends arbitrary or selected `tonNode_query` requests to a full-node-master ext-server as a non-trusted ADNL-authenticated client. The reusable pieces exist (`adnl::AdnlExtClient`, `tonNode.downloadZeroState`, `tonNode.downloadBlockFull`, and `create_serialize_tl_object_suffix<tonNode_query>`), but existing binaries are not sufficient: `validator-engine-console` and `tonlib::EngineConsoleClient` wrap requests as `engine_validator_controlQuery`, while `lite-client` and `proxy-liteserver` wrap requests as `liteServer_query`.

### Files created/updated

- `audit/fnserve_master_01_client/README.md` — local-only helper documentation, build command, required environment, and wrapper integration.
- `audit/fnserve_master_01_client/fnserve_master_query_client.cpp` — minimal single-request ADNL ext-client helper for `downloadZeroState` and `downloadBlockFull`.
- `audit/fnserve_master_01_client/CMakeLists.txt` — standalone helper build snippet that imports the repository CMake tree and builds `fnserve_master_query_client`.
- `audit/run_fnserve_master_01_local.sh` — updated to auto-detect `audit/fnserve_master_01_client/build/fnserve_master_query_client`, pass `FNSERVE_MASTER_PUBKEY_TL_HEX` and optional `FNSERVE_CLIENT_PRIVKEY_TL_HEX`, and require the full master ADNL public key before run mode.
- `audit/CODEX_LAST_STATUS.md` — this status update.

### Exact build command

```bash
cmake -S audit/fnserve_master_01_client -B audit/fnserve_master_01_client/build
cmake --build audit/fnserve_master_01_client/build --target fnserve_master_query_client -j"$(nproc)"
```

### Exact `FNSERVE_CLIENT_CMD`

```bash
export FNSERVE_CLIENT_CMD="audit/fnserve_master_01_client/build/fnserve_master_query_client"
```

The wrapper also auto-detects this path if it is executable.

### Exact plan command

```bash
FNSERVE_MODE=plan bash audit/run_fnserve_master_01_local.sh
```

### Exact bounded run template

```bash
FNSERVE_MODE=run \
FNSERVE_CONFIG=/path/to/local-validator-engine-config.json \
FNSERVE_MASTER_HOST=127.0.0.1 \
FNSERVE_MASTER_PORT=<configured-fullnodemaster-port> \
FNSERVE_MASTER_PUBKEY_TL_HEX='<TL-serialized full master ADNL public key as hex>' \
FNSERVE_CLIENT_CMD='audit/fnserve_master_01_client/build/fnserve_master_query_client' \
FNSERVE_ZERO_STATE_BLOCK='(workchain,shard_hex,seqno):root_hash_hex:file_hash_hex' \
FNSERVE_BLOCK_ID='(workchain,shard_hex,seqno):root_hash_hex:file_hash_hex' \
FNSERVE_TARGET_PID=<validator-engine-pid> \
bash audit/run_fnserve_master_01_local.sh
```

### Helper safety and request behavior

- The helper refuses public hosts by default and requires explicit `FNSERVE_MASTER_HOST` and `FNSERVE_MASTER_PORT`.
- The helper sends exactly one request per invocation.
- The helper supports only `downloadZeroState` and `downloadBlockFull`.
- The helper requires `FNSERVE_MASTER_PUBKEY_TL_HEX` because ADNL ext-client setup needs the full server public key, not just the short ADNL hash stored in `fullnodemasters` config entries.
- The helper uses an ephemeral Ed25519 client key unless `FNSERVE_CLIENT_PRIVKEY_TL_HEX` is provided, so it does not require validator-engine-console or trusted operator control access.
- The wrapper remains responsible for request count, parallelism, timeout, disk, process, and shard-limiter comparison safety limits.

### What was not executed

- No helper build was run.
- No repository tests were run.
- No dependency installation was run.
- No local or public traffic was sent.
- No PoC runtime was executed.

### BLOCKER/CLOSE criteria after helper update

- `BLOCKER_LOCAL_TOPOLOGY`: helper binary is not built, no configured full-node-master port exists, no full master ADNL public key is available, or no zero-state/known-block target is available.
- `BLOCKER_REACHABILITY`: the local/private master ext-server cannot be reached by the helper using non-trusted ADNL authentication.
- `BLOCKER_UPSTREAM_LIMITER`: future runtime evidence shows an upstream limiter equivalent to shard `limiter_->check_in(...)` fires before master heavy processing.
- `CLOSE_LOW_IMPACT`: helper traffic succeeds but metrics show only normal full-node bandwidth serving without meaningful CPU/DB/actor pressure or shard limiter contrast.

### Logs to send back after a bounded local run

- `${FNSERVE_WORKDIR}/run/final_verdict.txt`.
- `${FNSERVE_WORKDIR}/run/request_counts.tsv` and `${FNSERVE_WORKDIR}/run/summary_counts.tsv`.
- `${FNSERVE_WORKDIR}/logs/client_*` request stdout/stderr files.
- `${FNSERVE_WORKDIR}/metrics/df_*`, `du_*`, `ps_*`, `proc_io_*`, and `proc_status_*` files, when present.
- Target full-node-master logs and any shard limiter comparison logs.

## FNSERVE-MASTER-01 local PoC package (2026-06-12)

Status: `FNSERVE-MASTER-01 = pursue / confirmed-for-bounded-local-PoC / not report-ready / no-runtime-executed`.

### Exact local PoC package created

- `audit/run_fnserve_master_01_local.sh` — safe bounded local plan/run wrapper for `FNSERVE-MASTER-01`.
- The script creates its own workdir at `${FNSERVE_WORKDIR:-$HOME/ton-fnserve-master-01-local}` with `logs/`, `metrics/`, `plan/`, and `run/` subdirectories.
- No production code is patched. No target logic patch is generated. No report draft is created.

### What was not executed

- No build was run.
- No tests were run.
- No dependency installation was run.
- No public-network traffic was sent.
- No bounded PoC traffic was sent by this update.

### Run command

Plan mode, safe and non-traffic:

```bash
FNSERVE_MODE=plan bash audit/run_fnserve_master_01_local.sh
```

Bounded local run mode template, only for a local/private topology with a configured `fullnodemasters` entry and a non-trusted ADNL `tonNode_query` client command:

```bash
FNSERVE_MODE=run \
FNSERVE_CONFIG=/path/to/local-validator-engine-config.json \
FNSERVE_MASTER_HOST=127.0.0.1 \
FNSERVE_MASTER_PORT=<configured-fullnodemaster-port> \
FNSERVE_MASTER_PUBKEY_TL_HEX='<TL-serialized full master ADNL public key as hex>' \
FNSERVE_CLIENT_CMD='audit/fnserve_master_01_client/build/fnserve_master_query_client' \
FNSERVE_ZERO_STATE_BLOCK='<zero-state block id>' \
FNSERVE_BLOCK_ID='<known received block id>' \
FNSERVE_TARGET_PID=<validator-engine-pid> \
bash audit/run_fnserve_master_01_local.sh
```

The script refuses run mode unless required tools, initialized submodules, a local validator-engine artifact, a full-node-master config/port, a non-trusted ADNL client command, and at least one zero-state or known-block target are identified.

### Safety limits

- `FNSERVE_WORKDIR="${FNSERVE_WORKDIR:-$HOME/ton-fnserve-master-01-local}"`.
- `FNSERVE_MAX_SECONDS="${FNSERVE_MAX_SECONDS:-120}"`.
- `FNSERVE_MAX_REQUESTS="${FNSERVE_MAX_REQUESTS:-200}"`.
- `FNSERVE_MAX_PARALLEL="${FNSERVE_MAX_PARALLEL:-4}"`.
- `FNSERVE_MIN_FREE_BYTES="${FNSERVE_MIN_FREE_BYTES:-1073741824}"`.
- Public-network targets are refused by default; `FNSERVE_MASTER_HOST` must be localhost/private unless explicitly overridden for private non-local lab networks.
- The script never runs `git clean` and only writes logs/metrics/plan/run files under its own workdir.

### Required static checks documented by the package

- Identifying configured `fullnodemaster`: parse `FNSERVE_CONFIG` for `fullnodemasters`/`full_node_masters`, or set `FNSERVE_MASTER_PORT`/`FNSERVE_MASTER_ADNL`; source references are `validator-engine/validator-engine.cpp::config_add_full_node_master` and `ValidatorEngine::start_full_node_masters`.
- Identifying ext-server port: `FullNodeMasterImpl::start_up()` calls `adnl::Adnl::create_ext_server({adnl_id_}, {port_}, ...)`; `AdnlExtServerImpl::add_tcp_port()` creates the TCP listener for that port.
- Identifying client tool: the original static review did not find an existing non-trusted ADNL `tonNode_query` CLI, so this package now includes `audit/fnserve_master_01_client/fnserve_master_query_client.cpp`; `validator-engine-console` is still not treated as sufficient because it is an operator/control tool. Run mode auto-detects the helper binary or accepts `FNSERVE_CLIENT_CMD` and returns `BLOCKER_LOCAL_TOPOLOGY` if neither is available.
- Identifying known block: set `FNSERVE_BLOCK_ID` from local/private validator DB/log/console output for a received block; unknown/unreceived blocks are cheap rejected by `BlockFullSender` before DB data/proof reads.
- Identifying zero-state request: set `FNSERVE_ZERO_STATE_BLOCK` from the local/private validator zero-state id/config.
- Shard comparison: provide `FNSERVE_SHARD_COMPARE_CMD` or `FNSERVE_SHARD_LIMITER_LOG` if a comparable shard-path limiter run is available.

### PASS criteria

The script may print `PASS_RUNTIME_EVIDENCE` only if the bounded local run shows all of the following: the configured product/local-testnet master full-node port accepts a non-trusted ADNL-authenticated client; no upstream limiter fires before `FullNodeMasterImpl::receive_query`; repeated master `downloadZeroState` and/or `downloadBlockFull` requests trigger sustained DB/state/proof/serialization work; comparable shard-path requests show limiter rejection or materially different throttling; and the impact is visible under strict local safety caps.

### BLOCKER/CLOSE criteria

- `BLOCKER_LOCAL_TOPOLOGY`: local config/tooling cannot expose a master full-node path, no build artifact is present, no non-trusted ADNL client command is identified, or no zero-state/known-block target is identified.
- `BLOCKER_REACHABILITY`: the master path is local/trusted-only, public-network-safe host checks fail, or the target process disappears/restarts before evidence can be collected.
- `BLOCKER_UPSTREAM_LIMITER`: use if future local evidence finds an upstream limiter equivalent to shard `limiter_->check_in(...)` before master heavy processing.
- `CLOSE_LOW_IMPACT`: traffic is accepted, but metrics show only normal full-node bandwidth serving without meaningful CPU/DB/actor pressure or shard-path limiter contrast.

### Logs/metrics to collect

- Target logs and optional shard limiter logs.
- Client request stdout/stderr per request.
- `request_counts.tsv` with request kind, index, exit code, and latency timestamps.
- `df -B1` and `du -sb` snapshots for the workdir.
- Optional `ps`, `/proc/<pid>/status`, and `/proc/<pid>/io` snapshots for `FNSERVE_TARGET_PID`.
- Final verdict in `${FNSERVE_WORKDIR}/run/final_verdict.txt`.

## FNSERVE-MASTER-01 focused confirmation pass (2026-06-12)

Status: `FNSERVE-MASTER-01 = confirmed-for-local-poc / needs bounded local confirmation / not report-ready / no-runtime-executed`.

### Candidate summary

Possible serving-cost mismatch in the master full-node TCP/ADNL serving path: the shard full-node path parses `tonNode_query`, computes `request_cost_for_limiter(...)`, calls `limiter_->check_in(...)`, and only then dispatches to `process_query(...)`; the master full-node path parses `tonNode_query` and dispatches directly to `FullNodeMasterImpl::process_query(...)` without an equivalent limiter before heavy DB/proof/state/archive serving work.

### Gate 1 — master path reachability

- Product creation: `validator-engine/validator-engine.cpp` imports `fullnodemasters_` from engine config, validates that the ADNL id exists, rejects duplicate ports, and records `(port, adnl)` in `Config::full_node_masters`. During normal startup, after validator/full-node/lite-server/collator startup, `ValidatorEngine::start_full_node_masters()` creates a `FullNodeMaster` actor for every configured full-node master.
- External listener: `FullNodeMasterImpl::start_up()` subscribes the configured ADNL id to `tonNode_query` and calls `adnl::Adnl::create_ext_server({adnl_id_}, {port_}, ...)`. The ext-server implementation creates a `TcpInfiniteListener` for the configured port; the code path passes only a port, not a localhost-only bind address.
- Peer/authentication: the ext-server requires ADNL TCP authentication by a remote public key/signature, then delivers queries to the ADNL local-id callback. The reviewed master receive path does not apply an allowlist or trusted-operator check after ADNL authentication.
- Reachability verdict: reachable in product/local-testnet configurations that include `fullnodemasters`; not an always-on default path. The attacker model is an ADNL-authenticated network peer able to connect to the configured full-node-master port, not a local-only operator.

### Gate 2 — upstream limiter/rate-limit before master handler

No shard-equivalent limiter was found before `FullNodeMasterImpl::receive_query(...)` dispatches to `process_query(...)`.

- `adnl/adnl-ext-server.cpp::AdnlInboundConnection::process_packet(...)` parses `adnl_message_query` and forwards it through `AdnlPeerTable::deliver_query(...)`.
- `adnl/adnl-local-id.cpp::AdnlLocalId::deliver_query(...)` selects the registered callback by prefix and calls `receive_query(...)`.
- `FullNodeMasterImpl::receive_query(...)` checks the `tonNode_query` prefix and TL-parses a `ton_api::Function`, then immediately `downcast_call`s to `process_query(...)`.
- By contrast, `FullNodeShardImpl::receive_query(...)` calls `limiter_->check_in(fun_id, request_cost_for_limiter(*fun_ptr))` before dispatch.

### Gate 3 — master vs shard limiter mismatch

| Request family | Master handler and expensive operation | Shard equivalent | Shard limiter cost | Master limiter |
| --- | --- | --- | --- | --- |
| `downloadBlockFull` | `FullNodeMasterImpl::process_query(downloadBlockFull)` creates `BlockFullSender`; for known blocks it reads block data plus proof/proof-link and serializes `tonNode_dataFull`. | `FullNodeShardImpl::process_query(downloadBlockFull)` creates the same `BlockFullSender`. | medium method limit via `FullNodeImpl::make_limiter`, default request cost `1`. | none found before `process_query`. |
| `downloadNextBlockFull` | Master creates `BlockFullSender(next=true)`, resolves the next block, then reads block data plus proof/proof-link and serializes. | Shard creates same sender with `next=true`. | medium method limit, default request cost `1`. | none found. |
| `downloadZeroState` | Master calls `ValidatorManagerInterface::get_zero_state`; manager forwards to DB/rootdb/archive manager; archive manager reads the whole zero-state file. | Shard calls the same manager method. | heavy cost derived from `FullNode::max_zerostate_size()` through `request_cost_for_limiter`. | none found. |
| `downloadPersistentStateSliceV2` | Master rejects `max_size < 0 || max_size > (1 << 24)`, then calls `get_persistent_state_slice`. | Shard performs the same max-size check and same manager call. | heavy cost `ceil(max_size / 2 MiB)`. | no per-peer/per-method limiter; only the 16 MiB `max_size` check. |
| `getPersistentStateSizeV2` | Master calls `get_persistent_state_size`. | Shard calls same manager method. | default cost `1` under shard limiter/global window. | none found. |
| `getArchiveSlice` | Master rejects `max_size < 0 || max_size > (1 << 24)`, then calls `get_archive_slice`. | Shard performs the same max-size check and same manager call. | heavy cost `ceil(max_size / 2 MiB)`. | no per-peer/per-method limiter; only the 16 MiB `max_size` check. |
| `downloadBlockProof` | Master checks handle and `inited_proof()`, then calls `get_block_proof`. | Shard does the same handler sequence. | medium method limit, default request cost `1`. | none found. |
| `downloadBlockProofLink` | Master checks handle and `inited_proof_link()`, then calls `get_block_proof_link`. | Shard does the same handler sequence. | medium method limit, default request cost `1`. | none found. |

### Gate 4 — max_size / slice-boundary checks

- Master `getArchiveSlice` does reject `max_size < 0 || max_size > (1 << 24)` before forwarding to `get_archive_slice`.
- Master `downloadPersistentStateSliceV2` does reject `max_size < 0 || max_size > (1 << 24)` before forwarding to `get_persistent_state_slice`.
- These checks are present on both master and shard handlers. Therefore the strongest confirmed mismatch is not an unchecked slice size, but the absence of the shard-side per-method/per-window limiter on the master path.

### Gate 5 — expensive work before rejection

- `downloadBlockFull` / `downloadNextBlockFull`: `BlockFullSender` first rejects unknown, unreceived, proofless/proof-linkless, or deleted block handles before DB data reads. For known blocks, it sends separate requests for block data and proof/proof-link, then serializes `serialize_block_full(..., compression_enabled=false)`. Repeated requests for known blocks can therefore force repeated DB reads plus serialization; unknown blocks are cheap rejected.
- `downloadZeroState`: `FullNode::max_zerostate_size()` is 16 MiB and the shard limiter charges this as a heavy request. Master has no equivalent limiter before `ValidatorManagerImpl::get_zero_state(...)`, which forwards to DB/rootdb/archive manager; `ArchiveManager::get_zero_state(...)` verifies the zero-state is indexed in `perm_states_` and starts a `db::ReadFile` for the entire file (`offset=0`, `size=-1`). Repeated requests can re-read the zero-state from disk on the configured master path.
- `getArchiveSlice` / `downloadPersistentStateSliceV2`: master caps each requested slice to 16 MiB, but unlike shard receive it does not charge the request by `ceil(max_size / 2 MiB)` through `limiter_->check_in(...)` before the DB/archive read.

### Gate 6 — severity assessment

Verdict: pursue with one bounded local PoC; not report-ready yet.

- Validator/full-node impact: this is primarily serving-path CPU/DB/actor and outbound serialization pressure on a validator/full-node process that has a configured full-node-master external server. It is stronger than pure bandwidth serving because the missing master-side limiter allows repeated known-object DB/proof/state/archive work that shard peers would have method-window throttled before dispatch.
- Critical/High caveat: severity depends on how commonly/officially `fullnodemasters` ports are exposed in product/testnet deployments. If the master port is absent, localhost-only due to deployment firewall, or intended only for trusted full-node slaves, this falls to hardening/Medium/close. The local PoC must therefore prove the configured product/local-testnet master port accepts an untrusted ADNL-authenticated peer and that one peer can sustain heavy work beyond normal serving expectations.
- Not old/out-of-scope: this does not reopen downloader retry, archive import, persistent-state Stage B, VM proof poisoning, keyBlocks, external-message, or generic `VM-SERVE-05` read-only caps. The new fact is the master-vs-shard serving limiter mismatch on the same heavy request families.

### Minimal bounded local PoC plan (not executed)

1. Use a local/testnet validator-engine config with a `fullnodemasters` entry so `ValidatorEngine::start_full_node_masters()` creates `FullNodeMasterImpl` and `create_ext_server` listens on the configured port.
2. Connect from a separate ADNL ext client identity that is not in the target validator/operator trusted set but can complete ADNL TCP authentication.
3. Repeatedly issue bounded bursts of known-object master queries: `downloadZeroState`, then `downloadBlockFull`/`downloadNextBlockFull` for known blocks, then 16 MiB `getArchiveSlice` or `downloadPersistentStateSliceV2` requests if valid IDs are available.
4. Stop on `FNSERVE_MASTER_MAX_SECONDS` or `FNSERVE_MASTER_MAX_REQUESTS`; do not use public network and do not exceed local disk/network safety caps.
5. Compare against the shard path for the same request family and confirm shard logs/metrics show limiter rejection/throttling while master path continues to dispatch heavy work.

### Metrics/logs for PASS

- Target logs showing `FullNodeMasterImpl::receive_query`/handler-level acceptance for the relevant request family.
- Target CPU, actor mailbox/backlog, DB read count/bytes, and response serialization bytes during the bounded burst.
- Master-port request/response count and error count.
- Shard-path comparison showing `limiter_->check_in(...)` throttles equivalent heavy bursts.
- Evidence that the client was only ADNL-authenticated and not a trusted operator/full-node slave allowlisted identity.

### PASS criteria

PASS requires all of: configured product/local-testnet master port externally accepts an untrusted ADNL-authenticated peer; no upstream limiter fires before master heavy handler dispatch; repeated known-object master queries cause sustained DB/proof/state/archive reads and serialization; the same request family is throttled on shard via `limiter_->check_in(...)`; impact is measurable under strict local safety caps.

### FAIL/CLOSE criteria

Close or downgrade if any of: `fullnodemasters` is not reachable in product/local-testnet config; ext-server is deployment-local/trusted-only; an upstream ADNL, config, or firewall gate limits untrusted peers before `receive_query`; master has a hidden per-peer/per-method limiter outside the inspected path; repeated requests are served from a cheap cache without sustained CPU/DB/actor pressure; or impact is only normal bandwidth for an intentionally public serving endpoint.

### Proposed fix

Add a `RateLimiter<>` to the master serving path using the same `FullNodeImpl::make_limiter(...)` policy or a stricter master-specific policy, call `check_in(fun_id, request_cost_for_limiter(...))` before `FullNodeMasterImpl::process_query(...)`, and optionally restrict full-node-master ext-server peers to configured slave/trusted ADNL ids when the deployment intends the port to be private.

## Why runtime was not executed

The task explicitly prohibited PoC execution. During repo inspection, existing local tontester/build tooling was found, but the repository does not contain a confirmed archive-specific local topology command that makes a clean out-of-sync target enter the normal archive network import path and select a controlled malicious full-node neighbour for `tonNode_getArchiveSlice`. Running a guessed topology would risk fake evidence, so CN-ARCHIVE-01 is parked rather than closed or reported.

## Created/updated files

- `audit/run_cn_archive_01_local.sh` — concrete Stage 1 local runtime plan/runner gate for CN-ARCHIVE-01. It performs preflight checks, writes exact local checkout/build command files under its own workdir, generates an attacker-only patch under its own workdir, defines target/attacker log filtering, defines `du -b` and `df -B1` metrics collection for `db_root/tmp`, refuses to execute guessed runtime wiring, and parks the candidate without requesting user-supplied topology internals.
- `audit/CODEX_LAST_STATUS.md` — this status note.

## Files/functions inspected

- `audit/run_stage_b_local.sh` — existing clean target / attacker-only checkout and build command pattern.
- `audit/stage_b_tontester_topology.py` — existing local tontester DHT/donor/target/attacker full-node topology pattern for Stage B persistent-state testing.
- `test/tontester/src/tontester/install.py` — existing build artifact paths such as `validator-engine`, `generate-random-id`, and `validator-engine-console`.
- `test/tontester/src/tontester/network.py` — existing `Network`, `StartOptions`, `create_dht_node()`, `create_full_node()`, `make_initial_validator()`, `announce_to()`, and `run()` APIs.
- `validator/manager.cpp::ValidatorManagerImpl::prestart_sync()`.
- `validator/manager.cpp::ValidatorManagerImpl::download_next_archive()`.
- `validator/import-db-slice.cpp::ArchiveImporter::start_up()`.
- `validator/full-node.cpp::FullNodeImpl::download_archive()`.
- `validator/full-node-shard.cpp::FullNodeShardImpl::download_archive()`.
- `validator/full-node-shard.cpp::process_query(tonNode_getArchiveInfo / tonNode_getShardArchiveInfo / tonNode_getArchiveSlice)`.
- `validator/net/download-archive-slice.cpp::DownloadArchiveSlice`.

## How user should run

Plan/blocker mode, from the repository root:

```bash
CN_ARCHIVE_WORKDIR="${HOME}/ton-cn-archive-01-local" \
CN_ARCHIVE_MAX_BYTES=268435456 \
CN_ARCHIVE_MAX_SECONDS=180 \
CN_ARCHIVE_MODE=plan \
bash audit/run_cn_archive_01_local.sh
```

Run mode intentionally remains parked unless this repository later gains a repo-local, source-confirmed archive-import topology trigger. Do not ask the user to provide topology internals; continue autonomous triage instead.


## Final static trigger-map findings

- `prestart_sync()` is entered only after `finish_start_up()`/hardfork handling finds `out_of_sync()` true. `out_of_sync()` is based on `sync_upto()`, shard-client lag of more than 16 masterchain blocks, stale masterchain/key-block state, and validator-group status.
- `download_next_archive()` computes `seqno = min(last_masterchain_seqno_, shard_client_handle_->id().seqno())`. If matching `db_root/import/archive.*.pack` files exist, it uses `ArchiveImporterLocal`; only an empty local-import set creates network `ArchiveImporter`.
- `ArchiveImporter::start_up()` logs `Importing archive for masterchain seqno #... from net` and calls `send_download_archive_request(..., db_root + "/tmp/", timeout=3600s)`.
- `FullNodeImpl::download_archive()` routes by historical shard to `FullNodeShardImpl::download_archive()`, which calls `choose_neighbour()` and passes that selected ADNL to `DownloadArchiveSlice`.
- `choose_neighbour()` chooses among overlay neighbours with acceptable protocol version and weighted unreliability; existing tontester helpers can introduce full-node neighbours, but the reviewed repo files do not expose a deterministic product-path command that guarantees the attacker is selected for archive download.
- `DownloadArchiveSlice` opens a temp file with `mkstemp(tmp_dir)`, asks the selected peer for archive info, then repeatedly requests `tonNode_getArchiveSlice(archive_id, offset, slice_size())`; a full-size response advances `offset_` and continues, while only a short response finishes. The static path therefore remains interesting, but the local trigger/neighbour-control path is not confirmed.

## Expected PASS evidence

Do not claim PASS/report-ready unless bounded local runtime evidence includes all of the following:

1. Target log evidence containing `Importing archive for masterchain seqno #... from net`.
2. Target log evidence containing `downloading archive slice #... from <attacker ADNL>` or equivalent archive source/neighbour ADNL linkage.
3. Attacker log evidence for each served slice containing `archive_id`, `offset`, `requested_size`, `returned_size`, `slice_no`, and `cumulative_bytes`.
4. Evidence of repeated full-size `tonNode_getArchiveSlice` responses from the malicious full-node neighbour.
5. `du -b` and `df -B1` metrics showing target `db_root/tmp` growth during repeated full-size slices.
6. Safety-stop evidence showing the run stopped at `CN_ARCHIVE_MAX_BYTES` or `CN_ARCHIVE_MAX_SECONDS` before any real disk-fill risk.

## Expected BLOCKER/CLOSE evidence

Treat the candidate as blocked or close it if runtime evidence shows any of the following:

- Required tools or submodules, especially `third-party/openssl`, are missing.
- No confirmed local topology can drive `ValidatorManagerImpl::prestart_sync()` to `ArchiveImporter::start_up()` from-net archive import on a clean target.
- The clean target does not select the controlled attacker as the archive neighbour.
- The target rejects, truncates, rate-limits, or caps malicious archive slices before `db_root/tmp` growth.
- `db_root/tmp` remains bounded under `CN_ARCHIVE_MAX_BYTES` and `CN_ARCHIVE_MAX_SECONDS` despite repeated full-size attacker responses.

## Parked reason and autonomous continuation

CN-ARCHIVE-01 is parked because repo-local static review did not find a confirmed trigger that both enters from-net archive import on a clean out-of-sync target and deterministically selects the controlled attacker neighbour. CN-ARCHIVE-01 is not closed because the product path still writes archive slices to a temp file and repeats downloads while full-size slices are returned; only the safe local runtime trigger/neighbour-control wiring remains unconfirmed.

A new repo-local fact that would unpark it: an existing test/local config, DB seed path, validator-engine option, or script that reliably drives `prestart_sync()` to from-net `ArchiveImporter::start_up()` and constrains `FullNodeShardImpl::choose_neighbour()` to the attacker.

## Fresh autonomous triage closures

- `SIMPLEX-CANDIDATE-REQUEST-PARSE`: closed. `IncomingOverlayRequest` parsing in `candidate-resolver.cpp` uses typed TL parsing and later candidate/certificate validation; weak parse failures do not show a Critical validator-impact path without validator-authenticated reachability.
- `SIMPLEX-BROADCAST-EXTRA-AT`: closed. `private-overlay.cpp` maps ADNL sources through validator peer maps before candidate handling; malformed broadcast extras are rejected in precheck, and no fresh network-reachable CHECK was confirmed.
- `FULLNODE-BLOCK-DOWNLOAD-CONTINUATION`: closed. Non-archive block/proof download paths parse typed answers and abort on errors; no unbounded temp-file growth analogue was confirmed outside archive/persistent-state areas.
- `IMPORT-LOCAL-CHECKS`: closed. `import-db-slice-local.cpp` CHECKs sit behind local `.pack` import files under `db_root/import`, not a fresh unauthenticated network path.
- `DHT-ADNL-HANDLER-CHECKS`: closed for this pass. Found assertions are configuration/local-invariant heavy or already excluded by triage scope; no new realistic validator-impact product path was established.

## Deep pass: validator-manager and DB/state import/export paths (network-adjacent, non-archive-trigger)

Commit/branch at pass time: `d67550fa` / `work`.

### Candidate VM-DBSTATE-01 — remote block-full response causes unsafe DB block-data mutation

- Candidate ID: `VM-DBSTATE-01`
- Files/functions inspected: `validator/net/download-block-new.cpp::DownloadBlockNew::{got_node_to_download,got_data,got_ready_to_deserialize}`, `validator/downloaders/wait-block-data.cpp::WaitBlockData::{loaded_data,checked_proof_link}`, `validator/manager.cpp::ValidatorManagerImpl::set_block_data`.
- Entry point: full-node neighbour response to `tonNode_downloadBlockFull` / `tonNode_downloadNextBlockFull` requested by `send_get_block_request`.
- Attacker model: Byzantine full-node neighbour selected for block sync.
- Attacker-controlled input: serialized `tonNode_DataFull`, including proof/proof-link and block bytes.
- Product-path reachability: normal block sync uses this path through the validator manager full-node callback.
- State mutation / allocation point: block bytes are eventually written via `ValidatorManagerImpl::set_block_data` -> `Db::store_block_data`.
- Precheck / validation before mutation: `DownloadBlockNew` TL-parses the answer, checks block-id/prev-id, checks `sha256(block_.data) == id.file_hash`, validates proof or proof-link via `validate_block_proof(_link)`, and only then reaches `checked_block_proof` / `WaitBlockData::checked_proof_link` storage.
- Caps / limits / dedup / timeout / cleanup: outgoing query uses a 15s timeout and response limit `FullNode::max_proof_size() + FullNode::max_block_size() + 128`; `WaitBlockData` retries after network error but stores only after proof-link/proof preconditions.
- Expected impact: malformed data can waste a bounded request/validation attempt and trigger retry, but no unvalidated DB mutation was found.
- Why Critical/High or why not: not Critical/High because file-hash and proof/proof-link validation precede persistent block-data storage.
- Old-branch duplicate check: not H7, external limiter, persistent-state Stage B, CN-ARCHIVE-01, FEC/CAND-01/CAND-02/CAND-06, or excluded RLDP2/DHT/keyBlocks.
- Verdict: close.
- Exact kill reason: `got_ready_to_deserialize()` rejects wrong block id, bad file hash, and bad proof/proof-link before `WaitBlockData::checked_proof_link()` calls `set_block_data`.

### Candidate VM-PROOF-02 — remote proof/proof-link poisoning

- Candidate ID: `VM-PROOF-02`
- Files/functions inspected: `validator/net/download-proof.cpp::DownloadProof::{got_download_token,got_node_to_download,got_block_proof_description,got_block_proof,got_block_partial_proof}`, `validator/downloaders/download-state.cpp::{downloaded_proof_link,checked_proof_link}`.
- Entry point: Byzantine full-node neighbour response to `tonNode_prepareBlockProof`, `tonNode_downloadBlockProof`, or proof-link variants.
- Attacker model: selected overlay neighbour serving proof material.
- Attacker-controlled input: `tonNode_PreparedProof` selector and proof/proof-link bytes.
- Product-path reachability: normal state/block downloaders ask neighbours for proof links before applying state/block data.
- State mutation / allocation point: proof data can initialize block-handle proof/proof-link state only through validator-manager validation calls.
- Precheck / validation before mutation: prepared-proof TL parse is required; full proof/proof-link response is capped by `FullNode::max_proof_size()`; downstream `DownloadShardState::downloaded_proof_link()` constructs a proof link and calls `run_check_proof_link_query` before proceeding.
- Caps / limits / dedup / timeout / cleanup: 1s prepare timeout, 3s download timeout, max proof-size response cap, abort on invalid prepared proof or disallowed partial proof.
- Expected impact: bounded failed proof resolution / retry.
- Why Critical/High or why not: not Critical/High because proof bytes are not accepted into state/block mutation without proof-link/proof verification.
- Old-branch duplicate check: not excluded old candidates; also not a new RLDP2 finding because the relevant limit is at product request construction.
- Verdict: close.
- Exact kill reason: `got_block_proof_description()` caps proof downloads and `downloaded_proof_link()` must pass `run_check_proof_link_query`; invalid proof material aborts before state download/storage.

### Candidate VM-IMPORT-03 — downloaded archive/import package mutates DB before validation

- Candidate ID: `VM-IMPORT-03`
- Files/functions inspected: `validator/import-db-slice.cpp::ArchiveImporter::{process_package,processed_mc_archive,check_masterchain_block,abort_query,finish_query}`.
- Entry point: archive/import package bytes from network archive import or local import file.
- Attacker model: malicious archive source or malicious local `.pack` supplier.
- Attacker-controlled input: package file entries and block/proof references.
- Product-path reachability: archive import is product path, but CN-ARCHIVE-01 trigger remains parked; local `.pack` import is local operator input.
- State mutation / allocation point: `process_package()` indexes package references in memory; later block application paths mutate DB only after block/proof checks.
- Precheck / validation before mutation: `FileReference::create()` must parse each package entry; masterchain sequence must be contiguous/old-id-consistent (`check_old_mc_block_id` / equality with current state) before continuing.
- Caps / limits / dedup / timeout / cleanup: on abort before importing anything, all temp files in `files_to_cleanup_` are unlinked; finish also unlinks cleanup files.
- Expected impact: malformed package can abort or partially import only after prior blocks have been accepted.
- Why Critical/High or why not: not a fresh Critical/High because the only network-risk here is the already parked archive trigger; DB mutation is not reached just by malformed package indexing.
- Old-branch duplicate check: overlaps CN-ARCHIVE-01 only at archive download trigger; not reopened.
- Verdict: close for this deep pass / CN-ARCHIVE-01 remains parked separately.
- Exact kill reason: package parsing only populates in-memory offsets; `processed_mc_archive()` rejects non-contiguous/bad old masterchain IDs and `abort_query()` unlinks temp files if nothing was imported.

### Candidate VM-SPLITSTATE-04 — split persistent-state part writes before whole-state merge validation

- Candidate ID: `VM-SPLITSTATE-04`
- Files/functions inspected: `validator/downloaders/download-state.cpp::DownloadShardState::{downloaded_split_state_header,download_next_part_or_finish,downloaded_state_part,written_state_part_file,written_shard_state}`, `validator/manager.cpp::{store_persistent_state_file,store_block_state_part,set_block_state}`.
- Entry point: full-node neighbour serving split persistent-state header and parts.
- Attacker model: Byzantine selected full-node neighbour.
- Attacker-controlled input: split-state header and account-state parts.
- Product-path reachability: persistent-state sync/download path; excluded from reopening because persistent-state Stage B was already handled.
- State mutation / allocation point: header/part files are stored before final merged state is accepted; parts are also stored into cell DB after per-part hash checks.
- Precheck / validation before mutation: header BOC must parse; effective shards/root hashes are derived from header against expected `handle_->state`; each part BOC must parse and match the expected part root hash before storing; final merge then creates shard state and checks root hash before setting block state/archive handle.
- Caps / limits / dedup / timeout / cleanup: uses persistent-state request flow, per-part retry, and root-hash gates; however this area is old/excluded due Stage B.
- Expected impact: same family as persistent-state Stage B disk/storage pressure, not a new candidate under current rules.
- Why Critical/High or why not: not pursued because it reopens the excluded persistent-state branch; no new non-duplicate fact was found.
- Old-branch duplicate check: duplicate/adjacent to persistent-state Stage B; explicitly excluded.
- Verdict: close as duplicate/out-of-scope for this pass.
- Exact kill reason: excluded old branch; additionally part storage is gated by BOC parse and per-part root-hash equality before `store_persistent_state_file`/`store_block_state_part`.

### Candidate VM-SERVE-05 — inbound full-node DB/state export request exhausts serving validator

- Candidate ID: `VM-SERVE-05`
- Files/functions inspected: `validator/full-node-master.cpp::process_query(downloadBlock/downloadBlockProof/downloadBlockProofLink/downloadZeroState)`, `validator/full-node-shard.cpp::process_query(getArchiveSlice/downloadPersistentStateSliceV2/getPersistentStateSizeV2)`, `validator/db/archive-manager.cpp::get_archive_slice`.
- Entry point: inbound overlay/RLDP queries from peers asking this node to serve blocks/proofs/states/archive slices.
- Attacker model: remote full-node peer repeatedly requesting served data.
- Attacker-controlled input: requested block IDs, archive IDs, persistent-state IDs, offsets, and max sizes.
- Product-path reachability: normal full-node serving path.
- State mutation / allocation point: read/export path only; no validator DB mutation from attacker request.
- Precheck / validation before mutation: block/proof handlers require received data/proof/proof-link handles; archive and persistent-state slice handlers reject `max_size < 0` or `max_size > 1<<24`; archive lookup maps through known archive file descriptors.
- Caps / limits / dedup / timeout / cleanup: per-request max-size cap of `1<<24`; proof download serving depends on existing handles; persistent-state/archive slices are read from DB files.
- Expected impact: serving bandwidth/IO pressure, not direct consensus/DB corruption; no new Critical/High without a bypass of existing request limiting.
- Why Critical/High or why not: not Critical/High because it is read-only export with explicit max-size checks; reopening external limiter/RLDP throttling is out-of-scope without a new product fact.
- Old-branch duplicate check: would otherwise overlap external limiter/RLDP/overlay-peers; no genuinely new fact.
- Verdict: close.
- Exact kill reason: handlers reject oversize slice requests (`max_size > 1<<24`) and only read existing received/proof/state/archive data; no state mutation or new limiter bypass identified.

## Accepted status checkpoint before Simplex pass

- `CN-ARCHIVE-01 = parked / runtime-trigger-blocked / not closed / not report-ready`.
- `VM-DBSTATE-01 = closed`.
- `VM-PROOF-02 = closed`.
- `VM-IMPORT-03 = closed for this pass, except parked CN-ARCHIVE-01`.
- `VM-SPLITSTATE-04 = closed / duplicate persistent-state Stage B`.
- `VM-SERVE-05 = closed`.

## Deep pass: Consensus/Simplex network-reachable assertions and liveness paths

Commit/branch at pass time: `241caba6` / `work`.

### Candidate SIMPLEX-VOTE-01 — incoming signed vote reaches `slot.has_value()` CHECK

- Candidate ID: `SIMPLEX-VOTE-01`
- Exact files/functions: `validator/consensus/simplex/pool.cpp::PoolImpl::handle(IncomingProtocolMessage)`, `validator/consensus/simplex/votes.cpp::Signed<Vote>::from_tl`, `validator/consensus/simplex/state.h::ConsensusState::slot_at`.
- Exact assertion / liveness condition: `CHECK(slot.has_value())` after `state_->slot_at(referenced_slot)` for accepted vote messages.
- Entry point: authenticated validator overlay protocol message parsed as `tl::vote`.
- Attacker model: Byzantine validator; public peers/full-nodes cannot supply this path as a validator source.
- Attacker-controlled input: signed vote kind and referenced slot/candidate id.
- Product-path reachability: product Simplex vote gossip path.
- Authentication / overlay / signature requirements before branch: source is `PeerValidatorId` from consensus overlay; `Signed<Vote>::from_tl` checks the Ed25519 signature over `dataToSign(session_id, vote)` before applying the vote.
- Parse/validate gates before branch: TL parse as `tl::vote`; too-new votes are dropped before signature check; votes below `first_nonfinalized_slot_` return early.
- State mutation before branch: none for bad/old/too-new messages; after signature, `handle_vote` mutates per-validator vote state.
- Requires local DB/debug/impossible state: no crash path found; `slot_at()` returns `std::nullopt` only for slots below finalized, and those are returned before the CHECK.
- Duplicate check: not H7 Notarize+Skip; this is vote admission.
- Expected impact: bounded rejected packet or normal vote processing.
- Why Critical/High or why not: not Critical/High because the CHECK is guarded by `referenced_slot < first_nonfinalized_slot_` and `slot_at()` creates/tracks non-finalized slots.
- Verdict: close.
- Exact kill reason: line-level gate is `if (referenced_slot < first_nonfinalized_slot_) return;` immediately before `state_->slot_at(referenced_slot); CHECK(slot.has_value())`.

### Candidate SIMPLEX-CERT-02 — future or surprising certificate creates pending/future state

- Candidate ID: `SIMPLEX-CERT-02`
- Exact files/functions: `validator/consensus/simplex/pool.cpp::PoolImpl::handle(IncomingProtocolMessage)`, `PoolImpl::handle_certificate`, `PoolImpl::handle_prospective_certificate`, `validator/consensus/simplex/certificate.cpp::Certificate<Vote>::from_tl`.
- Exact assertion / liveness condition: too-new certificate path calls `state_->slot_at(raw_vote.referenced_slot()); CHECK(slot.has_value())`; prospective certificate then asynchronously saves and stores certificate state.
- Entry point: authenticated validator overlay protocol message parsed as `tl::certificate`.
- Attacker model: certificate requires Byzantine supermajority signatures; one Byzantine validator with an invalid certificate is rejected/banned.
- Attacker-controlled input: certificate vote kind, referenced slot, candidate id, and signature set.
- Product-path reachability: product certificate gossip path.
- Authentication / overlay / signature requirements before branch: `Certificate<Vote>::from_tl` rejects validator indexes outside the validator set, duplicate indexes, insufficient signed weight, and invalid Ed25519 signatures for `session_id` and the vote bytes.
- Parse/validate gates before branch: TL parse as `tl::certificate`; if not too-new, `slot_at` and `certs.needs` are checked before signature verification; if too-new, the expensive signature verification happens before creating a slot.
- State mutation before branch: none for invalid/insufficient certificates; valid certificates may set `being_saved` and later store a cert.
- Requires local DB/debug/impossible state: a far-future valid certificate requires a Byzantine supermajority; this overlaps the explicitly rejected/closed future-cert/far-future slot branch rather than a new single-validator crash.
- Duplicate check: duplicate of excluded far-future certificate amplification class unless a new non-majority path appears.
- Expected impact: with no Byzantine supermajority, rejected/banned packet; with Byzantine supermajority, normal protocol-level certificate effects or old far-future branch.
- Why Critical/High or why not: not a new Critical/High because the surprising state creation is gated by a valid >2/3 certificate, not a single Byzantine validator or public peer.
- Verdict: close.
- Exact kill reason: `Certificate::from_tl` enforces validator index bounds, duplicate rejection, threshold weight, and per-signature verification before the too-new `slot_at(...); CHECK(slot.has_value())` path.

### Candidate SIMPLEX-FINALCERT-03 — final certificate reaches `CHECK(!is_skipped())` or notarized-block CHECK

- Candidate ID: `SIMPLEX-FINALCERT-03`
- Exact files/functions: `validator/consensus/simplex/pool.cpp::PoolImpl::handle_typed_saved_certificate(FinalCertRef)`, `Tsentrizbirkom::check_invariants`, `Certificate<Vote>::from_tl`.
- Exact assertion / liveness condition: `CHECK(!slot.state->is_skipped())` and `CHECK(slot.state->notarized_block().value_or(id) == id)` when a final certificate is stored.
- Entry point: signed final certificate received over validator protocol or locally created after final-vote threshold.
- Attacker model: would require conflicting valid certificates/votes from Byzantine quorum, or the old H7 Notarize+Skip/FinalCert+Skip family.
- Attacker-controlled input: final certificate vote id and signatures.
- Product-path reachability: product certificate handling path.
- Authentication / overlay / signature requirements before branch: same `Certificate::from_tl` threshold/signature gates; conflicting per-validator votes become misbehavior reports in `Tsentrizbirkom::add_vote`.
- Parse/validate gates before branch: certificate parse and threshold signature validation; `handle_certificate` also checks slot exists/needs certificate.
- State mutation before branch: `handle_prospective_certificate` saves the certificate then applies each signer vote into per-validator `Tsentrizbirkom` state, reporting conflicts before `handle_saved_certificate`.
- Requires local DB/debug/impossible state: crash requires a skipped slot plus final certificate conflict state, which is the explicitly rejected H7-B/H7-A neighborhood or Byzantine supermajority equivocation.
- Duplicate check: duplicate/derivative of closed H7-A/H7-B; not reopened.
- Expected impact: rejected packet/misbehavior report for non-threshold conflicts; no new single-validator crash.
- Why Critical/High or why not: not Critical/High as a fresh candidate because it relies on closed Notarize+Skip/FinalCert+Skip assumptions or Byzantine quorum certificates.
- Verdict: close.
- Exact kill reason: final-certificate CHECKs are reached only after `Certificate::from_tl` threshold validation and per-signer `Tsentrizbirkom::check_invariants` conflict handling; the remaining crash theory duplicates H7.

### Candidate SIMPLEX-WAITPARENT-04 — candidate parent async wait causes CHECK or permanent pending state

- Candidate ID: `SIMPLEX-WAITPARENT-04`
- Exact files/functions: `validator/consensus/simplex/pool.cpp::PoolImpl::process(WaitForParent)`, `PoolImpl::maybe_resolve_request`, `validator/consensus/simplex/consensus.cpp::ConsensusImpl::handle(CandidateReceived)`.
- Exact assertion / liveness condition: `CHECK(!candidate->parent_id.has_value() || candidate->parent_id->slot < candidate->id.slot)`, `CHECK(first_nonfinalized_slot_ != 0)`, and `CHECK(parent.has_value())` inside parent resolution logic; possible pending `requests_` liveness.
- Entry point: candidate broadcast received from expected collator, then `try_notarize()` publishes `WaitForParent`.
- Attacker model: Byzantine expected collator for the slot.
- Attacker-controlled input: candidate parent id/slot and candidate block/empty data.
- Product-path reachability: product candidate broadcast and notarization path.
- Authentication / overlay / signature requirements before branch: candidate broadcast must come from expected collator and have a valid leader signature over candidate id; malformed parent slot `>= candidate slot` is rejected in `ConsensusImpl::handle(CandidateReceived)` before `WaitForParent`.
- Parse/validate gates before branch: `Candidate::deserialize` checks expected slot/source, candidate size caps, null `src_`, and candidate signature; `ConsensusImpl` drops too-new, finalized, already-voted, bad-parent, or duplicate pending candidates.
- State mutation before branch: `pending_block` is set only after the above gates; `requests_` entry is added only for accepted candidate.
- Requires local DB/debug/impossible state: CHECKs rely on invariants established by `ConsensusImpl` parent-slot guard and `first_nonfinalized_slot_`/`last_finalized_block_` relation.
- Duplicate check: H7-C parked idea touched skip intervals/available base, but no robust new repro or product-path violation found here.
- Expected impact: candidate waits until parent notar/skip evidence arrives, or returns misbehavior/conflict; no unbounded network unauthenticated pending state found.
- Why Critical/High or why not: not Critical/High because candidate admission is leader-authenticated and capped by slot/future-window checks; impossible-parent cases are returned before state mutation.
- Verdict: close.
- Exact kill reason: `ConsensusImpl::handle(CandidateReceived)` rejects `candidate->parent_id->slot >= candidate->id.slot` before `WaitForParent`, and `maybe_resolve_request` returns conflict/error for finalized or conflicting parent slots instead of crashing.

### Candidate SIMPLEX-CANDRES-05 — candidate resolver completion CHECK after async response merge

- Candidate ID: `SIMPLEX-CANDRES-05`
- Exact files/functions: `validator/consensus/simplex/candidate-resolver.cpp::CandidateAndCert::{from_tl,to_tl,as_resolution_result,merge}`, `CandidateResolverImpl::{process(IncomingOverlayRequest),process(ResolveCandidate),resolve_candidate_task,resolve_candidate_inner,try_load_candidate_data_from_db,store_candidate}`.
- Exact assertion / liveness condition: `CHECK(is_complete())` in `as_resolution_result()`/`resolve_candidate_task`, `CHECK((*candidate)->id == id)` in `to_tl`, and `CHECK(candidate.has_value())` in `store_candidate`.
- Entry point: candidate resolver overlay request/response between validators, and local `ResolveCandidate`/`StoreCandidate` events.
- Attacker model: Byzantine validator responding to candidate resolver requests.
- Attacker-controlled input: `candidateAndCert` response fields, candidate bytes, notar cert bytes, and omissions.
- Product-path reachability: product candidate resolution path for missing candidate/cert data.
- Authentication / overlay / signature requirements before branch: resolver requests are sent to validator peers; responses are parsed as `tl::candidateAndCert`; contained candidate uses `Candidate::deserialize`; contained notar cert uses `NotarCert::from_tl` threshold/signature checks.
- Parse/validate gates before branch: `CandidateAndCert::from_tl` rejects unrequested fields, candidate-id mismatch, malformed candidate, and malformed/invalid notar cert; merge only fills missing candidate/cert.
- State mutation before branch: `state.candidate_and_cert.merge()` only after `from_tl` succeeds; awaiters resume only when `is_complete()` is true.
- Requires local DB/debug/impossible state: DB load uses `move_as_ok()` and could crash on local DB corruption, but remote resolver responses cannot set `candidate_in_db` without local store path.
- Duplicate check: not H7; no new candidate.
- Expected impact: Byzantine peers can omit/return bad data causing retries with cooldown and capped timeout multiplier, not crash or permanent stall absent enough withholding to prevent normal consensus progress.
- Why Critical/High or why not: not Critical/High because invalid/mismatched responses are ignored; completion CHECK is reached only after `is_complete()`.
- Verdict: close.
- Exact kill reason: `resolve_candidate_task` executes `CHECK(state.candidate_and_cert.is_complete())` only when `resolve_candidate_inner` returned success, and success loop exits only after `while (!is_complete())` terminates.

### Candidate SIMPLEX-DB-06 — DB actor CHECK/fatal assertions from remote consensus messages

- Candidate ID: `SIMPLEX-DB-06`
- Exact files/functions: `validator/consensus/simplex/db.cpp::DbImpl::{process(BroadcastVote),process(SaveCertificate),process(LeaderWindowObserved),init_pool_state,init_votes}`.
- Exact assertion / liveness condition: `CHECK(result.is_ok() || result.error().code() == cancelled)`, `CHECK(first_nonannounced_window_ <= window)`, and `move_as_ok()` on persisted DB records.
- Entry point: local bus events caused by accepted votes/certificates/leader-window observation.
- Attacker model: indirect Byzantine validator messages may cause valid certificates/votes to be observed, but DB writes are local persistence operations.
- Attacker-controlled input: only valid signed/certified votes already accepted by pool; not raw DB bytes.
- Product-path reachability: local consensus persistence path.
- Authentication / overlay / signature requirements before branch: vote/certificate acceptance gates in pool and certificate/vote signature verification.
- Parse/validate gates before branch: DB initialization parse failures require local DB corruption or incompatible on-disk data, not remote packet syntax.
- State mutation before branch: saving votes/certs/pool state to local DB.
- Requires local DB/debug/impossible state: write failure or malformed persisted DB required for CHECK/move_as_ok crash; not a remote single-validator input path.
- Duplicate check: not H7; local DB corruption is explicitly out-of-scope.
- Expected impact: local DB failure crash/panic, not remotely triggerable Critical.
- Why Critical/High or why not: not Critical/High because remote messages cannot directly make `db->set` fail except through local environment/storage failure, and DB parse crashes require local DB corruption.
- Verdict: close.
- Exact kill reason: all DB CHECKs are after local `db->set`/`db->get_by_prefix`; remote input has already passed vote/cert signature gates and cannot control DB write status.

### Candidate SIMPLEX-BCAST-07 — candidate broadcast malformed TL reaches fatal assertion

- Candidate ID: `SIMPLEX-BCAST-07`
- Exact files/functions: `validator/consensus/types.cpp::Candidate::deserialize`, `validator/consensus/private-overlay.cpp::{on_overlay_broadcast,precheck_broadcast,on_query}`, `validator/consensus/block-sync-overlay.cpp::{on_overlay_broadcast,precheck_broadcast}`.
- Exact assertion / liveness condition: candidate constructor `CHECK(std::holds_alternative<BlockCandidate>(block) || parent_id.has_value())`, plus `fetch_tl_object(...).move_as_ok()` on broadcast extra in `on_overlay_broadcast` after overlay precheck.
- Entry point: private/block-sync overlay candidate broadcast from validator ADNL source.
- Attacker model: Byzantine expected collator for a slot; public/full-node source rejected by overlay peer maps/precheck.
- Attacker-controlled input: broadcast TL, candidate bytes, parent, slot, and signature.
- Product-path reachability: product candidate broadcast path.
- Authentication / overlay / signature requirements before branch: precheck parses broadcast extra, enforces expected collator for slot, deduplicates broadcast id via pool precheck, and `Candidate::deserialize` checks source/expected leader and signature.
- Parse/validate gates before branch: malformed TL rejected by precheck or deserialize; candidate sizes bounded by `max_block_size` and `max_collated_data_size`; candidate `src_` must be null; signature over candidate id must verify.
- State mutation before branch: none except broadcast dedup after signature_checked precheck; invalid candidate logs misbehavior and returns.
- Requires local DB/debug/impossible state: constructor CHECK would require creating an empty candidate without parent, but empty TL path uses mandatory `CandidateId::from_tl(empty_broadcast.parent_)`; malformed extras are rejected in precheck.
- Duplicate check: not H7; no new network-reachable CHECK.
- Expected impact: rejected/logged broadcast.
- Why Critical/High or why not: not Critical/High because malformed or semantically wrong candidates are rejected before consensus state mutation.
- Verdict: close.
- Exact kill reason: `Candidate::deserialize` enforces expected slot/source, size caps, null source, and leader signature before returning `Candidate`; overlay precheck rejects malformed extra or wrong collator before broadcast handling.

### Candidate SIMPLEX-STANDSTILL-08 — standstill resolution CHECK/liveness amplification

- Candidate ID: `SIMPLEX-STANDSTILL-08`
- Exact files/functions: `validator/consensus/simplex/pool.cpp::PoolImpl::{alarm,standstill_resolution_task,reschedule_standstill_resolution}`.
- Exact assertion / liveness condition: `CHECK(begin == begin_new || last_final_cert_ != last_final_cert_copy)` while iterating tracked slots during standstill resolution; possible egress amplification during standstill broadcast.
- Entry point: local standstill timer after lack of progress; not directly a packet handler.
- Attacker model: Byzantine validators can delay progress by withholding normal votes/certs, but not public peers.
- Attacker-controlled input: previously accepted votes/certs/candidates that populate tracked slots.
- Product-path reachability: product standstill resolution path.
- Authentication / overlay / signature requirements before branch: only signed/validated local votes/certs are serialized; egress is rate-limited by `standstill_max_egress_bytes_per_s`.
- Parse/validate gates before branch: state contents were admitted through prior vote/cert/candidate gates.
- State mutation before branch: none in the send loop except possible concurrent finalization from accepted final cert.
- Requires local DB/debug/impossible state: CHECK allows `begin` to change only if `last_final_cert_` changed; without finalization, tracked begin should not decrease/change due `notify_finalized` semantics.
- Duplicate check: not future-cert/far-future slot amplification; no new product fact beyond rate-limited standstill rebroadcast.
- Expected impact: logs and bounded rebroadcast of already accepted messages.
- Why Critical/High or why not: not Critical/High because it is timer-driven, rate-limited, and uses already validated state; no remote single-validator crash found.
- Verdict: close.
- Exact kill reason: standstill send path applies `standstill_max_egress_bytes_per_s` quota and the CHECK is tied to local finalized-slot progression, not raw remote input.

### Candidate SIMPLEX-STATE-09 — state resolver/finalization async CHECK from certificate/candidate mismatch

- Candidate ID: `SIMPLEX-STATE-09`
- Exact files/functions: `validator/consensus/simplex/state-resolver.cpp::StateResolverImpl::{resolve_state,resolve_state_inner,finalize_blocks,finalize_blocks_inner}`, `validator/consensus/simplex/candidate-resolver.cpp::CandidateAndCert::from_tl`.
- Exact assertion / liveness condition: `CHECK((*final_cert)->vote.id == id)` and candidate/cert resolution assumptions before applying/finalizing candidate state.
- Entry point: `FinalizationObserved` / `ResolveState` after final certificate handling.
- Attacker model: Byzantine validator(s) providing candidate/cert data or final certificate.
- Attacker-controlled input: candidate resolver response candidate and notar cert; final cert data if threshold-signed.
- Product-path reachability: product finalization/state resolution path.
- Authentication / overlay / signature requirements before branch: final cert requires threshold signatures; resolver `candidateAndCert` requires candidate id match and notar cert threshold signatures.
- Parse/validate gates before branch: `ResolveCandidate` returns a pair only after `CandidateAndCert::from_tl` has checked candidate id and notar cert validity; `finalize_blocks_inner` sets `final_candidate = candidate` when a final cert is present.
- State mutation before branch: cached resolver state only after validated merge; finalization recurses over parent chain and publishes `FinalizeBlock` with signature set derived from certificate.
- Requires local DB/debug/impossible state: mismatched final cert/id would require internal caller bug or local DB corrupted bootstrap cert, not a remote packet after `handle_typed_saved_certificate`.
- Duplicate check: not H7; no new remote CHECK path.
- Expected impact: none beyond rejected/ignored bad resolver response; valid finalization proceeds normally.
- Why Critical/High or why not: not Critical/High because remote candidate/cert mismatch is rejected in resolver before successful resolution, and final-cert id is the same id passed from finalization observation.
- Verdict: close.
- Exact kill reason: `CandidateAndCert::from_tl` rejects candidate-id mismatch and invalid notar cert, while `finalize_blocks_inner` obtains `candidate` through `ResolveCandidate(id)` and then assigns it to `final_candidate` for the same `final_cert` id before the CHECK.

## Accepted status checkpoint before candidate-validation pass

- `CN-ARCHIVE-01 = parked / runtime-trigger-blocked / not closed / not report-ready`.
- `VM-DBSTATE-01 = closed`.
- `VM-PROOF-02 = closed`.
- `VM-IMPORT-03 = closed for this pass, except parked CN-ARCHIVE-01`.
- `VM-SPLITSTATE-04 = closed / duplicate persistent-state Stage B`.
- `VM-SERVE-05 = closed`.
- `SIMPLEX-VOTE-01 = closed`.
- `SIMPLEX-CERT-02 = closed`.
- `SIMPLEX-FINALCERT-03 = closed / H7-adjacent duplicate`.
- `SIMPLEX-WAITPARENT-04 = closed`.
- `SIMPLEX-CANDRES-05 = closed`.
- `SIMPLEX-DB-06 = closed`.
- `SIMPLEX-BCAST-07 = closed`.
- `SIMPLEX-STANDSTILL-08 = closed`.
- `SIMPLEX-STATE-09 = closed`.

## Deep pass: candidate/block validation after successful candidate broadcast admission

Commit/branch at pass time: `d4a07dbd` / `work`.

### Candidate CANDVAL-PRESTORE-01 — accepted candidate persisted before semantic validation

- Candidate ID: `CANDVAL-PRESTORE-01`
- Exact files/functions: `validator/consensus/simplex/consensus.cpp::ConsensusImpl::{handle(CandidateReceived),try_notarize}`, `validator/consensus/simplex/candidate-resolver.cpp::CandidateResolverImpl::{process(StoreCandidate),store_candidate}`, `validator/consensus/block-validator.cpp::BlockValidatorImpl::process(ValidationRequest)`.
- Entry point after candidate admission: `CandidateReceived` after expected-collator/source, size caps, leader signature, and basic `Candidate::deserialize` already succeeded.
- Attacker model: Byzantine expected collator/validator for the slot.
- Attacker-controlled input: one admitted candidate for its slot, including block bytes, collated data bytes, parent reference, and timing/order.
- Product-path reachability: Simplex candidate broadcast path stores the candidate task before parent wait and deep validation complete.
- Size/cost caps before deep validation: candidate admission already enforced `data_.size() <= max_block_size` and `collated_data_.size() <= max_collated_data_size`; `ConsensusImpl` enforces not-too-new and one `pending_block` per slot.
- Parsing/deserialization gates: candidate TL, collator source, null candidate `src_`, size caps, block id/file hash construction, and leader signature were checked before `CandidateReceived`.
- State mutation / DB write / cache insertion point: `try_notarize()` starts `StoreCandidate` before `WaitForParent` and `ValidationRequest`; `StoreCandidate` writes serialized candidate data and an index entry to consensus DB.
- Async boundaries and stale-state checks: `try_notarize()` may return early on parent misbehavior or validation reject while the started store task can already have persisted the candidate; later notarization vote is only set after validation accept.
- Crash/liveness/resource condition: invalid admitted candidate can be persisted even if semantic validation later rejects it, but only one candidate is accepted per slot and payload is capped by the configured candidate data/collated-data size limits.
- Why it is or is not Critical/High: not Critical/High in this pass because the write is bounded by existing candidate size caps, limited by expected-collator slots and one pending candidate per slot, and does not produce a notarization vote or consensus DB state transition on reject.
- Old-branch duplicate check: not H7, not CN-ARCHIVE-01, not persistent-state Stage B; fresh but weak resource branch.
- Verdict: close.
- Exact kill reason: `ConsensusImpl::handle(CandidateReceived)` allows only one `pending_block` per slot and enforces too-new/parent guards, while validation accept is still required before `voted_notar` is set; the pre-validation DB write is bounded candidate archival, not unbounded Critical/High impact.

### Candidate CANDVAL-BLOCKBOC-02 — block BoC or collated-data expansion reaches fatal assertion

- Candidate ID: `CANDVAL-BLOCKBOC-02`
- Exact files/functions: `validator/impl/validate-query.cpp::ValidateQuery::{unpack_block_candidate,extract_collated_data,extract_collated_data_from}`, `validator/consensus/types.cpp::Candidate::deserialize`.
- Entry point after candidate admission: `BlockValidatorImpl::process(ValidationRequest)` calls manager `validate_block_candidate`, which starts `ValidateQuery` over the already-admitted candidate.
- Attacker model: Byzantine expected collator.
- Attacker-controlled input: `BlockCandidate::data` BoC and `BlockCandidate::collated_data` BoC within admission caps.
- Product-path reachability: normal post-admission block candidate validation path.
- Size/cost caps before deep validation: admission caps `candidate->data_.size() > max_block_size` and `candidate->collated_data_.size() > max_collated_data_size`; TLB block validation uses `t_Block.validate_ref(10000000, block_root_)`; collated data subtypes use `validate_ref(10000, croot)`.
- Parsing/deserialization gates: block file hash must match `id_.file_hash`, block BoC must deserialize with exactly one root, block root hash must equal `id_.root_hash`, collated data must deserialize with `std_boc_deserialize_multi`, and known collated data subtypes are validated before use.
- State mutation / DB write / cache insertion point: deep validator parses in memory; accepted candidates are cached only after `ValidateCandidateResult` is `CandidateAccept`.
- Async boundaries and stale-state checks: validation runs in `ValidateQuery` with a 60s ask timeout from `BlockValidator`; fatal errors are returned through the promise as errors, not process assertions.
- Crash/liveness/resource condition: malformed BoC/cell layouts reject; expensive validation is bounded by configured size caps, TLB validate limit, subtype validate limits, and validation timeout.
- Why it is or is not Critical/High: not Critical/High because candidate-controlled malformed/expanded data reaches reject paths (`reject_query`) rather than `CHECK`/process crash, and deeper validation has explicit limits/timeouts.
- Old-branch duplicate check: not SIMPLEX-BCAST-07; this starts after admission. Not old H7.
- Verdict: close.
- Exact kill reason: `unpack_block_candidate()` rejects file-hash mismatch, bad BoC, non-single-root block BoC, root-hash mismatch, invalid block header, bad collated-data BoC, duplicate/invalid Merkle proofs, and duplicate known collated data before accepted-candidate cache insertion.

### Candidate CANDVAL-FATAL-03 — `ValidateQuery::fatal_error` from candidate content crashes validator

- Candidate ID: `CANDVAL-FATAL-03`
- Exact files/functions: `validator/impl/validate-query.cpp::ValidateQuery::{fatal_error,try_validate,init_parse,process_mc_state,compute_prev_state}`, `validator/consensus/bridge.cpp::ManagerBridge::validate_block_candidate`.
- Entry point after candidate admission: deep validation stages after `ValidationRequest`.
- Attacker model: Byzantine expected collator controlling block/collated data and parent within admission guards.
- Attacker-controlled input: block header flags, state update cell, shard layout/config references, and candidate cell data under the cap.
- Product-path reachability: normal validate-query path.
- Size/cost caps before deep validation: same `max_block_size`, `max_collated_data_size`, `t_Block.validate_ref(10000000)`, and 60s validation ask timeout.
- Parsing/deserialization gates: many candidate inconsistencies return `reject_query`; some invariant failures call `fatal_error` and set the validation promise error.
- State mutation / DB write / cache insertion point: no accepted block cache insertion before `CandidateAccept`; validation stats may be logged.
- Async boundaries and stale-state checks: `ManagerBridge::validate_block_candidate` awaits the validate-query task; `BlockValidator` observes `CandidateReject` for reject results and does not notarize rejected candidates.
- Crash/liveness/resource condition: `fatal_error` sounds severe, but it logs and calls `main_promise.set_error`; it is not a `CHECK`, `LOG(FATAL)`, or process abort by itself.
- Why it is or is not Critical/High: not Critical/High without a path where candidate-controlled content turns promise error into validator crash or permanent liveness stall; the reviewed call path treats validation failure as no notarization rather than DB/consensus mutation.
- Old-branch duplicate check: not H7; not persistent-state Stage B.
- Verdict: close.
- Exact kill reason: `ValidateQuery::fatal_error(td::Status)` records stats and sets the validation promise error; no process-level fatal assertion was found on candidate-controlled fatal-error paths.

### Candidate CANDVAL-ASYNC-04 — validation result applies to stale slot/parent/candidate state

- Candidate ID: `CANDVAL-ASYNC-04`
- Exact files/functions: `validator/consensus/simplex/consensus.cpp::ConsensusImpl::{handle(CandidateReceived),try_notarize,process_notarization_observed,try_vote_final}`, `validator/consensus/block-validator.cpp::BlockValidatorImpl::process(ValidationRequest)`.
- Entry point after candidate admission: accepted `pending_block` begins async parent wait, state resolution, optional timestamp sleep, and validation.
- Attacker model: Byzantine expected collator for the slot plus timing/order control.
- Attacker-controlled input: validly admitted candidate timing, parent, and candidate bytes.
- Product-path reachability: normal Simplex candidate validation and notarization path.
- Size/cost caps before deep validation: one `pending_block` per slot; too-new window cap; candidate data/collated-data caps.
- Parsing/deserialization gates: already admitted candidate had source/leader signature and caps; `WaitForParent` rejects impossible parent order/conflicts.
- State mutation / DB write / cache insertion point: `pending_block` set before validation; `voted_notar` and `BroadcastVote(NotarizeVote)` occur only after validation accepted.
- Async boundaries and stale-state checks: after validation returns, code does not re-check whether the slot has since been finalized/skipped/notarized by another candidate before setting `voted_notar`; however `try_vote_final` only finalizes if `voted_notar == notar_cert` and `voted_skip` is false.
- Crash/liveness/resource condition: possible stale local notar vote after state progress was considered, but no Critical/High impact found without reopening H7 Notarize+Skip/finalization assumptions; conflicting votes become protocol-level misbehavior handling.
- Why it is or is not Critical/High: not Critical/High because a stale notar vote does not by itself finalize or crash; final vote requires matching notar cert and old H7 Notarize+Skip logic is excluded.
- Old-branch duplicate check: H7-adjacent if pursued as Notarize+Skip/finalization conflict; not reopened.
- Verdict: close.
- Exact kill reason: the only post-async mutation is `slot.state->voted_notar = candidate->id` followed by `BroadcastVote(NotarizeVote)`, and finalization still requires `voted_notar == notar_cert` inside `try_vote_final`; no new non-H7 crash/liveness path was proven.

### Candidate CANDVAL-MASTERWAIT-05 — masterchain validation waits indefinitely for previous accepted block

- Candidate ID: `CANDVAL-MASTERWAIT-05`
- Exact files/functions: `validator/consensus/block-validator.cpp::BlockValidatorImpl::{process(ValidationRequest),on_new_accepted_block}`.
- Entry point after candidate admission: block candidate validation for masterchain shard.
- Attacker model: Byzantine expected masterchain collator proposing a candidate based on a previous state not yet accepted locally.
- Attacker-controlled input: parent/reference that passed earlier guards and candidate timing.
- Product-path reachability: normal block validator path.
- Size/cost caps before deep validation: admission caps and one pending candidate per slot; validation ask timeout at 60s in `try_notarize` path.
- Parsing/deserialization gates: candidate parent has already passed parent-order guard and state resolution before validation request.
- State mutation / DB write / cache insertion point: before deep validation, candidate may have been stored by `StoreCandidate`; no notar vote until validation accept.
- Async boundaries and stale-state checks: for masterchain, block validator waits on `next_block_promises_` while `last_accepted_block_ < expected_seqno`; `on_new_accepted_block` wakes promises when finalized/accepted block advances.
- Crash/liveness/resource condition: a candidate can wait for local accepted-block progression, but the outer manager ask uses a 60s timeout; timeout aborts the validation attempt rather than permanent actor hang.
- Why it is or is not Critical/High: not Critical/High because waiters are bounded by the validation request timeout and normal chain progress; a single Byzantine collator cannot permanently stall consensus through this branch alone.
- Old-branch duplicate check: not H7; no old candidate reopened.
- Verdict: close.
- Exact kill reason: `validate_block_candidate(..., td::Timestamp::in(60.0))` bounds the masterchain wait, and `on_new_accepted_block` drains `next_block_promises_` when the expected block is accepted.

### Candidate CANDVAL-PARALLEL-06 — parallel account validation leaves pending/stale state after malicious account transaction set

- Candidate ID: `CANDVAL-PARALLEL-06`
- Exact files/functions: `validator/impl/validate-query.cpp::ValidateQuery::{check_transactions,CheckAccountTxs::try_check,after_check_account_finished,check_account_failures,try_validate}`.
- Entry point after candidate admission: stage-1 transaction validation over admitted block candidate data.
- Attacker model: Byzantine expected collator controls account transaction set inside candidate block.
- Attacker-controlled input: account blocks, transaction descriptions, old/new account states, messages, libraries inside candidate block/collated data.
- Product-path reachability: normal `ValidateQuery` stage 1/2 transaction validation.
- Size/cost caps before deep validation: candidate data/collated-data caps, automated `t_Block.validate_ref(10000000)`, and validation timeout; optional parallel account validation uses per-account checker actors and aggregates context back into `ValidateQuery`.
- Parsing/deserialization gates: account blocks are unpacked with TL-B helpers, address equality checks, account state unpacking, per-transaction checks, and later `check_account_failures()` before stage 2 continues.
- State mutation / DB write / cache insertion point: in-memory validation contexts are saved; accepted candidate cache only after full validation accept.
- Async boundaries and stale-state checks: `parallel_accounts_validation_pending_` suppresses alarm abort until account checks return; `after_check_account_finished` decrements pending and resumes `try_validate` after aggregating contexts.
- Crash/liveness/resource condition: malicious account sets can cause reject/fatal validation result or timeout-like work, but no unbounded actor leak or stale accept path found in this pass.
- Why it is or is not Critical/High: not Critical/High because failures are aggregated into reject/fatal validation result and no DB/consensus mutation occurs before full validation accept.
- Old-branch duplicate check: not H7; not persistent-state Stage B.
- Verdict: close.
- Exact kill reason: `check_transactions()` requires `check_account_failures()` before continuing when not parallel and uses `after_check_account_finished` to aggregate per-account contexts before resuming; accepted cache/notar vote occurs only after `CandidateAccept`.

### Candidate CANDVAL-CACHE-07 — accepted candidate cache insertion with invalid block

- Candidate ID: `CANDVAL-CACHE-07`
- Exact files/functions: `validator/consensus/block-validator.cpp::BlockValidatorImpl::process(ValidationRequest)`, `validator/consensus/manager-facade.h::ManagerFacade::cache_block_candidate`, `validator/consensus/bridge.cpp::ManagerBridge::validate_block_candidate`.
- Entry point after candidate admission: validation returns from manager bridge.
- Attacker model: Byzantine expected collator.
- Attacker-controlled input: candidate block and collated data.
- Product-path reachability: normal accepted-candidate cache path.
- Size/cost caps before deep validation: all validate-query caps and 60s validation request timeout.
- Parsing/deserialization gates: `cache_block_candidate` is called only if `validation_result.has<CandidateAccept>()`.
- State mutation / DB write / cache insertion point: candidate is cached after acceptance, not before validation, in this path.
- Async boundaries and stale-state checks: validation result is awaited before cache call; candidate clone cached only from the accepted result branch.
- Crash/liveness/resource condition: no invalid accepted cache path found.
- Why it is or is not Critical/High: not Critical/High because invalid candidates are `CandidateReject` or promise error, and `cache_block_candidate` is not called for them.
- Old-branch duplicate check: not old branch.
- Verdict: close.
- Exact kill reason: `BlockValidatorImpl::process` calls `cache_block_candidate(block.clone())` only inside `if (result.has<CandidateAccept>())`.

## Accepted status checkpoint before external/collation pass

- `CN-ARCHIVE-01 = parked / runtime-trigger-blocked / not closed / not report-ready`.
- `VM-DBSTATE-01 = closed`.
- `VM-PROOF-02 = closed`.
- `VM-IMPORT-03 = closed for this pass, except parked CN-ARCHIVE-01`.
- `VM-SPLITSTATE-04 = closed / duplicate persistent-state Stage B`.
- `VM-SERVE-05 = closed`.
- `SIMPLEX-VOTE-01 = closed`.
- `SIMPLEX-CERT-02 = closed`.
- `SIMPLEX-FINALCERT-03 = closed / H7-adjacent duplicate`.
- `SIMPLEX-WAITPARENT-04 = closed`.
- `SIMPLEX-CANDRES-05 = closed`.
- `SIMPLEX-DB-06 = closed`.
- `SIMPLEX-BCAST-07 = closed`.
- `SIMPLEX-STANDSTILL-08 = closed`.
- `SIMPLEX-STATE-09 = closed`.
- `CANDVAL-PRESTORE-01 = closed`.
- `CANDVAL-BLOCKBOC-02 = closed`.
- `CANDVAL-FATAL-03 = closed`.
- `CANDVAL-ASYNC-04 = closed`.
- `CANDVAL-MASTERWAIT-05 = closed`.
- `CANDVAL-PARALLEL-06 = closed`.
- `CANDVAL-CACHE-07 = closed`.

## Deep pass: external-message and block-collation admission paths

Commit/branch at pass time: `a44b6487` / `work`.

### Candidate EXTCOLL-LS-01 — public lite-server/full-node sendMessage duplicate or cache amplification

- Candidate ID: `EXTCOLL-LS-01`
- Exact files/functions: `validator/impl/liteserver.cpp::LiteQuery::{start_up,perform_sendMessage}`, `validator/impl/liteserver-cache.hpp::LiteServerCacheImpl::{process_send_message,drop_send_message_from_cache,alarm}`, `validator/full-node-master.cpp::FullNodeMasterImpl::process_query(tonNode_slave_sendExtMessage)`, `validator/manager.cpp::ValidatorManagerImpl::{run_ext_query,new_external_message_query}`.
- Entry point: public or semi-public lite-server `liteServer.sendMessage` or full-node master `tonNode_slave_sendExtMessage` forwarding to `run_ext_query` and then manager external-message admission.
- Attacker model: public lite-server client or full-node peer able to submit external-message bodies through normal product ingress.
- Attacker-controlled input: serialized lite-server query wrapper and external-message BoC body.
- Product-path reachability: `LiteQuery::perform_sendMessage` calls `ValidatorManager::new_external_message_query`; the full-node master slave query wraps the supplied message body into a `liteServer_sendMessage` query and calls `run_ext_query`.
- Old-branch duplicate check: not reopening the old same-address limiter bypass; this branch checked ingress duplicate/cache behavior and wrapper-level forwarding.
- Authentication / fee / account / signature / seqno gates: manager admission later creates and prechecks the external message against the current masterchain state; wallet messages must pass wallet seqno/valid-until parsing before allowed broadcast.
- Size / gas / block / message / queue limits: lite-server duplicate cache has `MAX_MSG_CACHE_SIZE = 1 << 17`; external message creation enforces current `ExtMsgLimits` max size and depth before account execution.
- Dedup / cache / limiter / timeout / cleanup: `LiteServerCacheImpl::process_send_message` rejects exact duplicate sendMessage query keys until the cache is cleared by `alarm`; manager/mempool dedup is by raw and normalized message hash after message parsing.
- State mutation / queue insertion / DB write point: no DB write found at lite-server ingress; cache insertion is an LRU entry keyed by query hash and is removed on error.
- Parsing/deserialization gates: lite-server TL function parse happens before `perform_sendMessage`; manager unwraps `liteServer_query` / `liteServer_queryPrefix` and external-message creation parses the BoC.
- CPU/memory/disk/liveness condition: exact duplicate sendMessage spam is rejected by lite-server cache; distinct valid messages proceed to normal external-message gates. No unbounded disk or persistent queue mutation was found before those gates.
- Why it is or is not Critical/High: not Critical/High because this branch does not bypass the manager external-message validation/limits and the lite-server duplicate cache is capped and periodically cleared.
- Verdict: close.
- Exact kill reason: `LiteServerCacheImpl::process_send_message` caps duplicate send-message tracking with `MAX_MSG_CACHE_SIZE = 1 << 17`, `LiteQuery::perform_sendMessage` drops the cache key on manager error, and `ValidatorManagerImpl::run_ext_query` still routes the body through normal lite-server parsing and `new_external_message_query` admission.

### Candidate EXTCOLL-PRECHECK-02 — expensive external-message account execution before mempool limiter/dedup

- Candidate ID: `EXTCOLL-PRECHECK-02`
- Exact files/functions: `validator/manager.cpp::ValidatorManagerImpl::{new_external_message_broadcast,new_external_message_query}`, `validator/impl/ext-message-pool.cpp::ExtMessagePool::{check_add_external_message,check_message,check_message_to_wallet,WalletInfo::process_messages}`, `validator/impl/external-message.cpp::ExtMessageQ::create_ext_message`.
- Entry point: external-message broadcast or query reaches `ExtMessagePool::check_add_external_message` before optional mempool insertion.
- Attacker model: public sender for lite-server query or Byzantine/full-node peer relaying an external-message broadcast.
- Attacker-controlled input: external-message BoC body and destination account.
- Product-path reachability: manager calls `check_add_external_message` for both broadcasts and queries; validators/collator nodes then add successful checks to mempool.
- Old-branch duplicate check: distinct from the old per-address limiter test only by asking whether expensive work occurs before mempool insertion; no new limiter bypass was found.
- Authentication / fee / account / signature / seqno gates: `check_message` fetches account state; wallet destinations use `WalletMessageProcessor` to parse seqno and valid-until, reject old, expired, too-new, and duplicate seqno messages, and run the message only after setting a simulated seqno.
- Size / gas / block / message / queue limits: `create_ext_message` rejects data larger than `limits.max_size`, depth greater than or equal to `limits.max_depth`, non-single-root BoC, non-zero-level cells, non-external-message tags, and invalid TL-B message shapes.
- Dedup / cache / limiter / timeout / cleanup: `CheckedExtMsgCounter` checks and increments per `(workchain,address)` with `MAX_EXT_MSG_PER_ADDR = 30` over the rolling 10-second window; wallet pending seqno acceptance is limited by `MAX_WALLET_SEQNO_DIFF = 16`.
- State mutation / queue insertion / DB write point: mempool insertion happens only after `check_message` succeeds and `add_to_mempool` is true; wallet pending promises are in-memory and cleaned by seqno advancement or valid-until expiry.
- Parsing/deserialization gates: BoC/message parse and TL-B validation happen in `create_ext_message`; wallet parser gates happen before wallet pending state insertion.
- CPU/memory/disk/liveness condition: one valid external message can trigger account-state fetch and pre-execution, but per-address rolling count, wallet seqno window, message size/depth limits, and mempool caps prevent a Critical/High unbounded path in this branch.
- Why it is or is not Critical/High: not Critical/High because the expensive check is tied to accepted external-message semantics and bounded per destination by `MAX_EXT_MSG_PER_ADDR` / wallet seqno window; cross-account amplification remains ordinary public message load, not a new validator-critical product bug.
- Verdict: close.
- Exact kill reason: `check_add_external_message` performs `create_ext_message` and a pre-check `checked_ext_msg_counter_.get_msg_count(...) >= MAX_EXT_MSG_PER_ADDR` before `check_message`, repeats the counter check after successful `check_message`, and only then calls `add_message_to_mempool`.

### Candidate EXTCOLL-MEMPOOL-03 — cross-account external-message mempool growth or delayed-message retention

- Candidate ID: `EXTCOLL-MEMPOOL-03`
- Exact files/functions: `validator/impl/ext-message-pool.hpp::ExtMessagePool::{MempoolMsg,ExtMessages,CheckedExtMsgCounter}`, `validator/impl/ext-message-pool.cpp::ExtMessagePool::{add_message_to_mempool,complete_external_messages,cleanup_external_messages,erase_message,alarm}`.
- Entry point: successfully checked external message is optionally inserted into the validator/collator-node mempool.
- Attacker model: public sender or peer able to submit many otherwise valid external messages across accounts.
- Attacker-controlled input: destination account, message body/hash, priority through product path constraints, and timing.
- Product-path reachability: `check_add_external_message(..., add_to_mempool = is_validator() || !collator_nodes_.empty())` reaches `add_message_to_mempool` for validator/collator-node operation.
- Old-branch duplicate check: not the closed per-address limiter bypass; this inspected cross-account growth and delayed-message retention.
- Authentication / fee / account / signature / seqno gates: only messages that pass `check_message` are inserted; wallet messages remain subject to valid-until, seqno, duplicate-seqno, and simulated execution gates.
- Size / gas / block / message / queue limits: global mempool insertion checks `msgs.ext_messages_.size() > opts_->max_mempool_num()` per priority, per-address mempool insertion checks `PER_ADDRESS_LIMIT = 256`, and each `MempoolMsg` has `delete_at = td::Timestamp::in(600)`.
- Dedup / cache / limiter / timeout / cleanup: raw hash duplicates are rejected or priority-upgraded by erasing the old entry; normalized-hash index supports applied-message cleanup; delayed messages can be postponed only while `generation <= 2` and otherwise are erased.
- State mutation / queue insertion / DB write point: insertion mutates in-memory treaps/maps and pushes to matching collator callbacks; no DB write is performed by the pool itself.
- Parsing/deserialization gates: only `td::Ref<ExtMessage>` objects already created and checked are inserted.
- CPU/memory/disk/liveness condition: cross-account memory use is capped by configured mempool count per priority, per-address limit, 600-second expiry, 250-second cleanup alarm, raw/normalized hash dedup, and limited postpone generations.
- Why it is or is not Critical/High: not Critical/High because the inspected state is in-memory and bounded by named limits/expiry/cleanup; no unbounded disk write or permanent liveness stall was found.
- Verdict: close.
- Exact kill reason: `add_message_to_mempool` refuses insertion when `msgs.ext_messages_.size() > opts_->max_mempool_num()` or per-address entries reach `PER_ADDRESS_LIMIT`, `MempoolMsg::expired()` removes entries after 600 seconds via `cleanup_external_messages`, and `complete_external_messages` erases delayed messages after the limited postpone window.

### Candidate EXTCOLL-COLLATOR-04 — collator external-message queue or block assembly stalls before block limits

- Candidate ID: `EXTCOLL-COLLATOR-04`
- Exact files/functions: `validator/impl/collator.cpp::Collator::{start_up,process_inbound_external_messages,process_external_message,register_external_message,wait_for_external_message}`, `validator/interfaces/validator-manager.h::ExtMsgQueue`, `validator/impl/ext-message-pool.cpp::ExtMessagePool::install_collator_queue`.
- Entry point: collator installs an external-message backpressure queue and processes queued messages during collation.
- Attacker model: public senders filling the external-message pool or Byzantine expected collator controlling inclusion/order in its own produced block.
- Attacker-controlled input: messages delivered to the collator queue, message order as observed from pool snapshots/live callbacks, and message bodies within prior limits.
- Product-path reachability: normal block collation path installs `ExtMsgQueue("ext_msg_queue", 500)`, requests external messages from manager, registers each external message, and calls `process_external_message`.
- Old-branch duplicate check: not old external limiter; this checked queue capacity, wait behavior, and collation assembly limits.
- Authentication / fee / account / signature / seqno gates: external messages have already passed pool creation/precheck; collator revalidates message shape, destination shard, duplicate block inclusion, and account transaction result.
- Size / gas / block / message / queue limits: queue capacity is 500; processing stops when `block_limit_status_->fits(cl_soft)` is false, `external_msg_timeout_` expires, collation attempt index is at least 2, or queue is empty/closed.
- Dedup / cache / limiter / timeout / cleanup: `registered_ext_msgs_` rejects duplicate message hashes inside a block; `bad_ext_msgs_` and `delay_ext_msgs_` are sent to manager via `complete_external_messages` after collation.
- State mutation / queue insertion / DB write point: successful processing mutates the in-progress block candidate; bad/delayed messages are reported to manager for in-memory pool cleanup/postpone after collation.
- Parsing/deserialization gates: `register_external_message` requires non-null zero-level cells, `ext_in_msg_info$10`, duplicate-free hash, automated and hand-written `Message Any` validation with depth 256, valid libs, unpacked header, valid destination, and shard containment.
- CPU/memory/disk/liveness condition: external-message collation work is bounded by queue capacity, soft block limits, collation external timeout, attempt-based skip, per-block duplicate set, and manager cleanup of bad/delayed entries.
- Why it is or is not Critical/High: not Critical/High because a sender cannot force unbounded collation work or queue growth before these named limits, and rejected account execution is converted to bad/delayed message handling rather than persistent consensus liveness failure.
- Verdict: close.
- Exact kill reason: `Collator::process_inbound_external_messages` stops on block soft limit, `external_msg_timeout_`, queue empty/closed, or attempt index at least 2; `ExtMsgQueue` capacity is 500, and `register_external_message` rejects duplicates and invalid/deep messages before `process_external_message`.

### Candidate EXTCOLL-BYZCOLL-05 — Byzantine collator-selected external-message set forces honest validators into disproportionate validation work

- Candidate ID: `EXTCOLL-BYZCOLL-05`
- Exact files/functions: `validator/impl/collator.cpp::Collator::{process_inbound_external_messages,process_external_message,return_block_candidate}`, `validator/impl/validate-query.cpp::ValidateQuery::{try_validate,check_in_msg_descr,check_transactions,check_new_state}`, `validator/consensus/block-validator.cpp::BlockValidatorImpl::process(ValidationRequest)`.
- Entry point: after candidate admission, honest validators validate a Byzantine expected collator's block candidate containing the chosen external-message effects.
- Attacker model: Byzantine expected collator/validator for a slot.
- Attacker-controlled input: block candidate bytes and collated data describing selected external-message transactions within consensus candidate caps.
- Product-path reachability: normal admitted-candidate validation path, already covered at the candidate-validation layer for candidate-wide resource/async/cache effects.
- Old-branch duplicate check: overlaps the just-closed `CANDVAL-*` branches; only a new external-message-specific disproportionate validation fact would make this fresh.
- Authentication / fee / account / signature / seqno gates: candidate admission still requires expected collator and leader signature; deep validation recomputes transaction/message/state validity before `CandidateAccept`.
- Size / gas / block / message / queue limits: collator-side candidate output checks `max_block_size` and `max_collated_data_size`; validator-side `BlockValidatorImpl` uses a 60-second validation ask timeout.
- Dedup / cache / limiter / timeout / cleanup: accepted-candidate cache is called only for `CandidateAccept`; invalid message sets lead to reject/fatal validation result without cache insertion.
- State mutation / queue insertion / DB write point: no accepted block cache insertion or notar vote before full validation accept in the reviewed validator path.
- Parsing/deserialization gates: validator-side validation checks inbound message descriptors, account transactions, message queues, and new state before accept.
- CPU/memory/disk/liveness condition: Byzantine collator can make validators spend normal bounded validation effort for its slot, but no external-message-specific unbounded retry/cache amplification or pre-accept DB mutation was found beyond closed candidate-validation branches.
- Why it is or is not Critical/High: not Critical/High as a fresh candidate because the relevant resource and stale-state concerns duplicate `CANDVAL-BLOCKBOC-02`, `CANDVAL-PARALLEL-06`, and `CANDVAL-CACHE-07` without a new product-path fact.
- Verdict: close.
- Exact kill reason: validator-side validation remains under the candidate-size caps and 60-second `validate_block_candidate` ask timeout, and `BlockValidatorImpl::process` calls `cache_block_candidate` only after `CandidateAccept`; this does not create a new external-message-specific Critical/High path.

### Candidate EXTCOLL-WALLETSEQ-06 — wallet pending seqno promises accumulate or block broadcast indefinitely

- Candidate ID: `EXTCOLL-WALLETSEQ-06`
- Exact files/functions: `validator/impl/ext-message-pool.hpp::ExtMessagePool::{WalletInfo,WalletMessageInfo}`, `validator/impl/ext-message-pool.cpp::ExtMessagePool::{check_message_to_wallet,WalletInfo::process_messages}`.
- Entry point: checked external message targets a recognized wallet contract and waits for contiguous seqno admission before rebroadcast.
- Attacker model: public sender with messages to one or many wallet addresses.
- Attacker-controlled input: wallet message seqno, valid-until, body, and target wallet.
- Product-path reachability: `check_message` calls `check_message_to_wallet` when `WalletMessageProcessor::get(acc.code->get_hash())` recognizes the account code.
- Old-branch duplicate check: not reopening same-address limiter; this checked pending wallet promise accumulation and seqno gaps.
- Authentication / fee / account / signature / seqno gates: wallet parser must return a seqno/valid-until; expired, old, too-new, and duplicate seqnos are rejected.
- Size / gas / block / message / queue limits: `MAX_WALLET_SEQNO_DIFF = 16`; per-address external check counter remains `MAX_EXT_MSG_PER_ADDR = 30` over the rolling window.
- Dedup / cache / limiter / timeout / cleanup: `WalletInfo::process_messages` resolves contiguous seqnos from current wallet seqno, erases entries that became too old, and erases expired valid-until entries; the `WalletInfo` destructor rejects remaining pending promises if the wallet entry is removed.
- State mutation / queue insertion / DB write point: only in-memory `wallets_[{wc,addr}].messages[msg_seqno]` state is inserted after wallet seqno is simulated and `run_message_on_account` succeeds.
- Parsing/deserialization gates: wallet-specific parser gates precede insertion; external-message creation gates precede wallet checking.
- CPU/memory/disk/liveness condition: a seqno-gap sender can hold a bounded in-memory set of pending promises per wallet, but cannot exceed the 16-seqno wallet window plus per-address checked-message counter without rejection.
- Why it is or is not Critical/High: not Critical/High because pending state is bounded and expires/rejects; no disk write, process crash, or permanent validator liveness impact was found.
- Verdict: close.
- Exact kill reason: `check_message_to_wallet` rejects `msg_seqno - wallet_seqno > MAX_WALLET_SEQNO_DIFF`, rejects duplicate seqno, and `WalletInfo::process_messages` erases too-old or expired entries while resolving contiguous pending broadcasts.

### Parked candidates after external/collation pass

- `CN-ARCHIVE-01` remains parked / runtime-trigger-blocked / not closed / not report-ready.
- New fact required to unpark `CN-ARCHIVE-01`: an existing repo-local local/testnet command or config that reliably enters `ArchiveImporter::start_up()` from-net import and a deterministic way to constrain `FullNodeShardImpl::choose_neighbour()` to a controlled attacker without target production patching, DB corruption, or harness-only assumptions.
- No new external-message or collation candidate is parked from this pass.

### Next highest-signal area

- Next autonomous Critical-only area: validator full-node download/state-proof paths outside CN-ARCHIVE, persistent-state Stage B, RLDP2/overlay-peers/DHT/keyBlocks, and the closed external/candidate-validation branches, focusing on network-adjacent downloader retries, proof/state validation boundaries, and pre-validation resource mutation.

## Accepted status checkpoint before downloader/retry pass

- `CN-ARCHIVE-01 = parked / runtime-trigger-blocked / not closed / not report-ready`.
- `VM-DBSTATE-01 = closed`.
- `VM-PROOF-02 = closed`.
- `VM-IMPORT-03 = closed for this pass, except parked CN-ARCHIVE-01`.
- `VM-SPLITSTATE-04 = closed / duplicate persistent-state Stage B`.
- `VM-SERVE-05 = closed`.
- `SIMPLEX-* = closed as recorded`.
- `CANDVAL-* = closed as recorded`.
- `EXTCOLL-LS-01 = closed`.
- `EXTCOLL-PRECHECK-02 = closed`.
- `EXTCOLL-MEMPOOL-03 = closed`.
- `EXTCOLL-COLLATOR-04 = closed`.
- `EXTCOLL-BYZCOLL-05 = closed`.
- `EXTCOLL-WALLETSEQ-06 = closed`.

## Deep pass: full-node / validator downloader retry and state-machine paths

Commit/branch at pass time: `11471ad9` / `work`.

### Candidate DLNEXT-01 — next-block downloader retry churn from a malicious selected neighbour

- Candidate ID: `DLNEXT-01`
- Exact files/functions: `validator/full-node-shard.cpp::FullNodeShardImpl::{get_next_block,try_get_next_block,got_next_block,choose_neighbour}`, `validator/net/download-block-new.cpp::DownloadBlockNew::{start_up,got_node_to_download,got_data,got_ready_to_deserialize,abort_query,alarm,finish_query}`.
- Entry point: normal full-node shard sync loop after `FullNodeShardImpl::set_handle()` calls `get_next_block()`.
- Attacker model: malicious full-node neighbour selected by normal product peer selection.
- Attacker-controlled input: `tonNode_downloadNextBlockFull` response, including empty/not-ready responses, wrong prev/id, malformed `tonNode_DataFull`, bad block data, bad proof/proof link, or timeout/no response.
- Product-path reachability: product sync loop creates one `DownloadBlockNew("downloadnext")` actor per attempt through `try_get_next_block(td::Timestamp::in(2.0), ...)`.
- Old-branch duplicate check: not CN-ARCHIVE-01 and not the closed non-archive block/proof poisoning branch; this checked retry/state-machine churn rather than proof acceptance.
- Request/response size cap: `send_query_via(..., "get_block_full", ..., td::Timestamp::in(15.0), ..., FullNode::max_proof_size() + FullNode::max_block_size() + 128, rldp_)`; the outer next-block attempt uses a 2-second timeout.
- Parse/deserialization gates: `DownloadBlockNew::got_data` requires `tonNode_DataFull`; `deserialize_block_full` is called with `overlay::Overlays::max_fec_broadcast_size()`; wrong block id / prev id / file hash is rejected before proof validation success.
- Proof/hash/identity validation gates: data file hash must match `id.file_hash`; proof/proof-link is validated through `validate_block_proof`, `validate_block_proof_link`, or `validate_block_is_next_proof` before `finish_query`.
- Retry/timeout/peer-switch limits: per attempt is time-bounded; failures schedule the next `get_next_block` after 0.1s; neighbour `unreliability` is increased for errors except `notready`/`cancelled`, and weighted `choose_neighbour` prefers lower-unreliability eligible peers.
- Pending state / promise / waiter mutation point: one `DownloadBlockNew` actor owns one promise; on success, downloaded data is validated into a `BlockHandle` through `ValidatorManagerInterface::validate_block` before `got_next_block` mutates `handle_`.
- Cleanup / abort / error handling: `DownloadBlockNew::abort_query` sets the promise error and stops; `alarm()` aborts with timeout; `finish_query()` sets the received block and stops.
- CPU/memory/disk/liveness condition: a bad neighbour can cause repeated 2-second attempts and 0.1-second retry scheduling, but the path has one actor/promise per attempt, response caps, proof/hash gates, and peer unreliability scoring; no unbounded memory/disk or single-peer permanent stall was found without assuming all available eligible peers are bad.
- Why Critical/High or why not: not Critical/High because retries are bounded per actor and no promise leak or pre-validation DB mutation was found; liveness degradation requires no honest eligible neighbour/progress, which is ordinary sync failure rather than a new single-neighbour product bug.
- Verdict: close.
- Exact kill reason: `try_get_next_block` passes a 2-second timeout to a single `DownloadBlockNew` actor, `DownloadBlockNew::abort_query` resolves the promise and stops on timeout/error, and `create_neighbour_promise` updates neighbour unreliability so `choose_neighbour` can de-prefer failing peers.

### Candidate DLBLOCKFULL-02 — block-full response expansion or DB mutation before proof/hash validation

- Candidate ID: `DLBLOCKFULL-02`
- Exact files/functions: `validator/net/download-block-new.cpp::DownloadBlockNew::{got_data,got_ready_to_deserialize,checked_block_proof}`, `validator/downloaders/wait-block-data.cpp::WaitBlockData::{loaded_data,loaded_block_data,checked_proof_link,failed_to_get_block_data_from_net}`, `validator/manager.cpp::ValidatorManagerImpl::{wait_block_data,finished_wait_data}`.
- Entry point: validator waits for block data and calls full-node `download_block`, or next-block sync downloads block full from a neighbour.
- Attacker model: malicious full-node neighbour or Byzantine full-node serving block-full responses.
- Attacker-controlled input: `tonNode_DataFull` payload, proof/proof link, block bytes, compressed full-data envelope, and response timing.
- Product-path reachability: normal `send_get_block_request` / `download_block` path reaches `DownloadBlockNew`, then `WaitBlockData` stores only after proof/hash checks.
- Old-branch duplicate check: excludes VM-DBSTATE-01 and VM-PROOF-02; this branch only checks downloader response expansion/DB mutation order.
- Request/response size cap: block-full query uses `FullNode::max_proof_size() + FullNode::max_block_size() + 128`; actor timeout is inherited from the wait/request timeout, and network subquery has 15 seconds.
- Parse/deserialization gates: `fetch_tl_object<tonNode_DataFull>` must parse; compressed-v2 state needs `extract_prev_blocks_from_proof` and matching requested `block_id_` or `prev_id_`; `deserialize_block_full` must succeed.
- Proof/hash/identity validation gates: downloaded block data hash must equal the block id file hash; block proof/proof link is validated before `DownloadBlockNew::finish_query`; `WaitBlockData` creates/validates proof link for non-masterchain cached candidates before `set_block_data`.
- Retry/timeout/peer-switch limits: bad network data routes through `failed_to_get_block_data_from_net`, which schedules restart after 0.1 seconds, while manager waiter entries have per-waiter timeouts and actor timeout `timeout + 10s`.
- Pending state / promise / waiter mutation point: `ValidatorManagerImpl::wait_block_data` coalesces waiters by block id into one `WaitBlockData` actor; `finished_wait_data` resolves all waiters or recreates the actor only while non-expired waiters remain.
- Cleanup / abort / error handling: `WaitList::check_timers_impl` sets timeout errors for expired waiters every 1 second from manager alarm; `finished_wait_data` erases the wait-list entry after final error/success.
- CPU/memory/disk/liveness condition: malicious block-full data can cause repeated parse/proof work until waiters expire, but the response size cap, hash/proof validation, one actor per block-id wait-list, and timeout cleanup prevent unbounded pending state or pre-validation DB write.
- Why Critical/High or why not: not Critical/High because bad data is rejected before `set_block_data`, waiters are coalesced and timed out, and resource use is capped by response size and timeout.
- Verdict: close.
- Exact kill reason: `DownloadBlockNew::got_ready_to_deserialize` rejects wrong id, bad file hash, and bad proof before resolving success, while `WaitBlockData::checked_proof_link` calls `set_block_data` only after masterchain proof or shard proof-link is initialized/validated; manager `finished_wait_data` erases or recreates wait actors only for still-live waiters.

### Candidate DLZEROSTATE-03 — zero-state download fragments accumulate before hash validation

- Candidate ID: `DLZEROSTATE-03`
- Exact files/functions: `validator/net/download-state.cpp::DownloadState::{start_up,got_node_to_download,got_block_state_description,got_block_state}`, `validator/downloaders/wait-block-state.cpp::WaitBlockState::{start,got_state_from_net,written_state_file,written_state,abort_query}`.
- Entry point: zero-state wait/download path for seqno-zero state when local DB/static file does not already contain the state.
- Attacker model: malicious full-node neighbour serving zero-state data.
- Attacker-controlled input: prepared-state descriptor, zero-state bytes, malformed state BoC, wrong root/file hash, or timeout.
- Product-path reachability: `WaitBlockState::start` calls `send_get_zero_state_request`, which uses full-node `download_zero_state` and `DownloadState` for seqno-zero state retrieval.
- Old-branch duplicate check: not persistent-state Stage B; this branch is zero-state only and excludes split/persistent-state disk-growth analysis.
- Request/response size cap: `DownloadState` uses `send_query_via(..., "download state", ..., td::Timestamp::in(3.0), ..., FullNode::max_zerostate_size(), rldp_)`; actor-level `alarm_timestamp()` is the caller timeout.
- Parse/deserialization gates: `got_block_state_description` parses `tonNode_PreparedState`; `WaitBlockState::got_state_from_net` deserializes cells, creates `ShardState`, and rejects bad state object construction.
- Proof/hash/identity validation gates: for zero-state, handle root hash is set from block id root hash, state root hash must match `handle_->state()`, and the raw state `sha256` must equal `handle_->id().file_hash` before store.
- Retry/timeout/peer-switch limits: bad state logs and calls `start()` to retry; overall actor alarm aborts at timeout, and manager waiters expire via `WaitList` checks.
- Pending state / promise / waiter mutation point: `WaitBlockState` stores no state file until after root/file hash checks; manager coalesces state waiters by block id in `wait_state_`.
- Cleanup / abort / error handling: `abort_query` resolves preliminary/final promises and stops; `finished_wait_state` clears wait lists on success/non-timeout error or recreates only for still-live waiters on timeout.
- CPU/memory/disk/liveness condition: malicious zero-state bytes can trigger bounded parse/hash work up to `max_zerostate_size`, but no DB write occurs before root/file hash checks and waiter cleanup is timeout-driven.
- Why Critical/High or why not: not Critical/High because the zero-state response is capped, identity/hash validation precedes `store_zero_state_file`, and retry/promise state is bounded by caller timeouts.
- Verdict: close.
- Exact kill reason: `WaitBlockState::got_state_from_net` rejects bad root/file hash before `store_zero_state_file`, `DownloadState` caps zero-state response by `FullNode::max_zerostate_size()`, and `WaitBlockState::alarm/abort_query` plus manager wait-list timeout checks resolve waiters.

### Candidate DLWAITERS-04 — downloader waiter/promise accumulation under repeated timeouts

- Candidate ID: `DLWAITERS-04`
- Exact files/functions: `validator/manager.hpp::ValidatorManagerImpl::{WaitList,WaitListPreliminary}`, `validator/manager.cpp::ValidatorManagerImpl::{wait_block_state,wait_block_data,finished_wait_state,finished_wait_data,alarm}`.
- Entry point: internal validator callers wait for block data or state while network downloaders retry underneath.
- Attacker model: malicious peer causing timeout/not-ready responses for data/state downloads so waiters remain pending.
- Attacker-controlled input: indirect network failure, not-ready responses, bad data causing retry, and timing of downloader completion.
- Product-path reachability: normal manager wait APIs back `WaitBlockData` and `WaitBlockState` downloader actors.
- Old-branch duplicate check: not archive, persistent-state Stage B, proof poisoning, or external/collation; this only checks promise/waiter lifecycle.
- Request/response size cap: inherited from underlying downloaders; this branch focuses on wait-list lifecycle rather than response bytes.
- Parse/deserialization gates: underlying wait actors perform block/state/proof parsing before success.
- Proof/hash/identity validation gates: underlying wait actors only resolve success after validation; waiter management does not bypass validation.
- Retry/timeout/peer-switch limits: each waiter stores its own timeout/priority; `get_timeout_impl` returns max waiter timeout plus 10 seconds for the actor; manager alarm calls `check_timers()` every 1 second.
- Pending state / promise / waiter mutation point: `wait_block_data` and `wait_block_state` append promises into vectors keyed by block id, coalescing one actor per id; preliminary and final state waiters are separated.
- Cleanup / abort / error handling: `check_timers_impl` sets timeout on expired waiters and compacts the vector; `finished_wait_state` and `finished_wait_data` erase map entries on success/non-timeout error, or recreate an actor only while non-expired waiters remain.
- CPU/memory/disk/liveness condition: a malicious network can keep a particular block/state unresolved until all requesters time out, but stale promises are pruned and no unbounded actor chain remains without fresh internal callers.
- Why Critical/High or why not: not Critical/High because pending state is keyed by requested block id, coalesced per id, and each waiter has an explicit timeout with 1-second cleanup; fresh internal demand is required for further growth.
- Verdict: close.
- Exact kill reason: `WaitList::check_timers_impl` sets timeout errors for expired waiters and resizes the vector, and `finished_wait_state` / `finished_wait_data` erase wait-map entries unless recreating a downloader for still-live waiters.

### Candidate DLOUTMSGQ-05 — out-message queue proof downloader response or proof-fetch amplification

- Candidate ID: `DLOUTMSGQ-05`
- Exact files/functions: `validator/full-node.cpp::FullNodeImpl::download_out_msg_queue_proof`, `validator/full-node-shard.cpp::FullNodeShardImpl::download_out_msg_queue_proof`, `validator/full-node-shard.cpp::FullNodeShardImpl::receive_query`, `validator/full-node.cpp::FullNodeImpl::get_out_msg_queue_query_token`.
- Entry point: validator/collator imports neighbour out-message queue proofs through full-node shard `download_out_msg_queue_proof`.
- Attacker model: malicious full-node neighbour serving `tonNode_getOutMsgQueueProof` responses.
- Attacker-controlled input: TL response bytes for `tonNode_OutMsgQueueProof`, proof contents, empty/not-found response, or timeout.
- Product-path reachability: product full-node path selects a neighbour requiring protocol version 3.0 and sends `tonNode_getOutMsgQueueProof` over overlay/RLDP2.
- Old-branch duplicate check: not keyBlocks, archive, persistent-state Stage B, or generic proof poisoning; this branch checks queue-proof downloader limits.
- Request/response size cap: outbound query response cap is `1 << 22`; serving side uses `get_out_msg_queue_query_token` with one token and incoming full-node query rate limiter before dispatch.
- Parse/deserialization gates: downloader parses `tonNode_OutMsgQueueProof`; empty proof maps to error; non-empty proof is passed to `OutMsgQueueProof::fetch(dst_shard, blocks, limits, x)`.
- Proof/hash/identity validation gates: `OutMsgQueueProof::fetch` is the semantic proof construction/validation boundary for destination shard, requested blocks, and imported message limits.
- Retry/timeout/peer-switch limits: call uses caller timeout and `create_neighbour_promise` updates peer stats for successes/failures; no internal unbounded retry loop is present in this function.
- Pending state / promise / waiter mutation point: one lambda owns the promise for one request; no persistent downloader-side cache or wait-list mutation occurs in the shard method.
- Cleanup / abort / error handling: parse errors and empty responses resolve the promise with error; successful parse schedules proof fetch immediately and resolves the same promise.
- CPU/memory/disk/liveness condition: a malicious neighbour can send up to the 4 MiB response cap and make `OutMsgQueueProof::fetch` run, but no unbounded response accumulation, retry loop, or DB write was found in the downloader wrapper.
- Why Critical/High or why not: not Critical/High because the downloader wrapper has a fixed response cap, one promise per request, no retry amplification, and relies on explicit `limits.max_bytes/max_msgs` when fetching semantic queue proof data.
- Verdict: close.
- Exact kill reason: `download_out_msg_queue_proof` rejects no eligible v3 neighbour, caps `send_query_via` responses at `1 << 22`, parses only `tonNode_OutMsgQueueProof`, and resolves the single promise through `OutMsgQueueProof::fetch` or an error without storing data to DB.

### Candidate DLPEERSEL-06 — neighbour scoring keeps choosing an attacker and prevents progress

- Candidate ID: `DLPEERSEL-06`
- Exact files/functions: `validator/full-node-shard.hpp::FullNodeShardImpl::create_neighbour_promise`, `validator/full-node-shard.cpp::FullNodeShardImpl::{choose_neighbour,update_neighbour_stats}`, `validator/full-node-shard.cpp::Neighbour::{query_success,query_failed}`.
- Entry point: all non-archive full-node downloader methods that call `choose_neighbour` and wrap the promise with `create_neighbour_promise`.
- Attacker model: malicious full-node neighbour among normal overlay neighbours.
- Attacker-controlled input: success/error timing and response status affecting neighbour stats through the promise result.
- Product-path reachability: `download_block`, `download_block_proof`, `download_block_proof_link`, `download_persistent_state`, `download_out_msg_queue_proof`, and next-block download all use `choose_neighbour` except zero-state, which initially lets `DownloadState` choose random overlay peers if no fixed peer is supplied.
- Old-branch duplicate check: not CN-ARCHIVE-01; no archive neighbour-selection trigger was reopened.
- Request/response size cap: inherited from each downloader (`max_block_size + max_proof_size`, `max_proof_size`, `max_zerostate_size`, `1 << 22`, etc.).
- Parse/deserialization gates: inherited from each downloader.
- Proof/hash/identity validation gates: inherited from each downloader.
- Retry/timeout/peer-switch limits: `create_neighbour_promise` increments unreliability for errors except `notready` and `cancelled`, decrements it on success, and `choose_neighbour` weights eligible peers by unreliability and protocol version.
- Pending state / promise / waiter mutation point: peer stats are in-memory neighbour fields; no request payload is retained by neighbour selection.
- Cleanup / abort / error handling: failed query results still resolve the original promise and update stats; lack of eligible neighbours returns zero and individual callers either error or query overlay random peers depending on the downloader.
- CPU/memory/disk/liveness condition: one malicious neighbour can delay/fail its own selected attempts, but repeated non-notready errors make it less likely to be selected relative to lower-unreliability peers; if all peers are bad or return `notready`, progress can stall but no unbounded resource growth or single-attacker deterministic capture was found.
- Why Critical/High or why not: not Critical/High because peer selection is probabilistic with failure feedback and no persistent payload accumulation; a no-honest-peer scenario is normal network failure, not a new product-path vulnerability.
- Verdict: close.
- Exact kill reason: `create_neighbour_promise` updates stats on every resolved query, `Neighbour::query_failed` increments `unreliability`, `query_success` decrements it, and `choose_neighbour` weights only eligible peers within `fail_unreliability()` of the best unreliability instead of pinning a single attacker.

### Parked candidates after downloader/retry pass

- `CN-ARCHIVE-01` remains parked / runtime-trigger-blocked / not closed / not report-ready.
- New fact required to unpark `CN-ARCHIVE-01`: an existing repo-local local/testnet command or config that reliably enters `ArchiveImporter::start_up()` from-net import and a deterministic way to constrain `FullNodeShardImpl::choose_neighbour()` to a controlled attacker without target production patching, DB corruption, or harness-only assumptions.
- No new downloader/retry candidate is parked from this pass.

### Next highest-signal area

- Next autonomous Critical-only area: validator full-node serving/query handlers for non-excluded block/state/proof/queue requests, focusing on inbound request caps, per-query rate-limit cost mismatches, expensive proof construction before token/rate checks, and CHECK/fatal paths reachable from authenticated overlay peers.

## FULLNODE_SERVE_PASS_MARKER_20260612 — full-node serving/query deep pass

Commit/branch at pass time: `5c36c133` / `work`.

### Accepted status checkpoint before full-node serving pass

- `CN-ARCHIVE-01 = parked / runtime-trigger-blocked / not closed / not report-ready`.
- `VM-DBSTATE-01 = closed`.
- `VM-PROOF-02 = closed`.
- `VM-IMPORT-03 = closed for this pass, except parked CN-ARCHIVE-01`.
- `VM-SPLITSTATE-04 = closed / duplicate persistent-state Stage B`.
- `VM-SERVE-05 = closed`.
- `SIMPLEX-* = closed as recorded`.
- `CANDVAL-* = closed as recorded`.
- `EXTCOLL-* = closed as recorded`.
- `DLNEXT-01 = closed`.
- `DLBLOCKFULL-02 = closed`.
- `DLZEROSTATE-03 = closed`.
- `DLWAITERS-04 = closed`.
- `DLOUTMSGQ-05 = closed`.
- `DLPEERSEL-06 = closed`.

### Candidate FNSERVE-MASTER-01 — master full-node query path serves heavy block/state/proof/archive requests without the shard limiter

- Candidate ID: `FNSERVE-MASTER-01`
- Exact files/functions: `validator/full-node-master.cpp::FullNodeMasterImpl::{receive_query,process_query(downloadBlockFull),process_query(downloadNextBlockFull),process_query(downloadZeroState),process_query(downloadPersistentStateSliceV2),process_query(getArchiveSlice)}`, `validator/full-node-shard.cpp::FullNodeShardImpl::{receive_query,request_cost_for_limiter}`, `validator/full-node.cpp::FullNodeImpl::make_limiter`, `validator/full-node-shard-queries.hpp::BlockFullSender`, `validator/manager.cpp::ValidatorManagerImpl::{get_zero_state,get_persistent_state_slice,get_block_data_from_db,get_block_proof_from_db,get_block_proof_link_from_db}`, `validator/db/rootdb.cpp::{get_block_data,get_block_proof,get_persistent_state_file_slice,get_zero_state_file,get_archive_slice}`, `validator/db/archive-manager.cpp::{get_persistent_state_slice,get_archive_slice}`, `validator/db/archive-slice.cpp::ArchiveSlice::get_slice`.
- Entry point: inbound `tonNode_query` received by the master full-node ADNL/ext-server callback and dispatched by `FullNodeMasterImpl::receive_query` to a concrete `process_query` handler.
- Attacker model: authenticated/full-node ADNL peer or externally reachable master full-node client able to send syntactically valid `tonNode_query` requests to the master full-node ADNL id/port.
- Attacker-controlled request fields: block ids for `downloadBlock`, `downloadBlockFull`, `downloadNextBlockFull`, proof/proof-link requests, zero-state block id, persistent-state `(block_id, masterchain_block_id, state_type, offset, max_size)`, archive `(archive_id, offset, max_size)`, and request timing/concurrency.
- Product-path reachability: `FullNodeMasterImpl::start_up` subscribes the ADNL id to `tonNode_query` and creates an ext server; `receive_query` parses the query prefix/object and directly downcasts to `process_query` without the `FullNodeShardImpl::receive_query` limiter gate.
- Old-branch duplicate check: not the downloader retry pass; not CN-ARCHIVE-01 archive download; not persistent-state Stage B/split-state disk growth; not VM-PROOF-02 proof poisoning; not VM-SERVE-05 as a generic capped read-only export. The new product-path fact is a serving-cost mismatch: shard full-node queries are costed/rate-limited before dispatch, while master full-node queries are not.
- Authentication / overlay / peer requirements: the peer must reach the master full-node ADNL/ext-server query interface; shard overlay handlers additionally require active shard overlay dispatch, but the master handler is registered directly via ADNL subscribe/create_ext_server.
- Request cap / max_size / token / rate-limit before expensive work: master `getArchiveSlice` and `downloadPersistentStateSliceV2` reject `max_size < 0 || max_size > (1 << 24)` before DB reads, but master `downloadBlockFull`/`downloadNextBlockFull` have no explicit per-query rate-limit/token gate before spawning `BlockFullSender`; master `downloadZeroState` has no per-query cost limiter before `get_zero_state`. In contrast, shard `receive_query` parses `ton_api::Function`, calls `limiter_->check_in(fun_id, request_cost_for_limiter(*fun_ptr))`, charges heavy requests by requested max size or zero-state max size, and only then dispatches to `process_query`.
- DB/proof/state construction point: `BlockFullSender` checks the block handle, then concurrently requests `get_block_data_from_db` and either `get_block_proof_from_db` or `get_block_proof_link_from_db`; zero-state and persistent/archive slice handlers call manager DB/archive wrappers that forward to `RootDb`/`ArchiveManager` and `db::ReadFile`/archive file actors.
- Serialization/BOC handling point: `BlockFullSender::finish_query` serializes `tonNode_DataFull` by calling `serialize_block_full(block_id_, proof_, data_, is_proof_link_, false)` after DB data and proof bytes arrive; persistent/archive slices return raw file bytes; proof handlers return proof bytes from DB/manager wrappers.
- Promise/state mutation point: each inbound query owns one promise and may create one `BlockFullSender` actor or one manager/archive read request; no persistent validator consensus state mutation was found, but repeated requests queue DB/archive read and serialization work without the shard limiter.
- Cleanup / abort / error handling: parse failure in master `receive_query` resolves the promise with protoviolation; `BlockFullSender::abort_query` returns `tonNode_dataFullEmpty` and stops; slice handlers set promise errors on invalid `max_size` or DB failures.
- CPU/memory/disk/liveness condition: repeated master full-node `downloadBlockFull`/`downloadNextBlockFull` requests for known blocks can force block-data and proof/proof-link DB reads plus full-block serialization without the shared `FullNodeImpl::make_limiter` per-query limits used by shard serving. Repeated `downloadZeroState` can force large zero-state DB reads through the master handler without the shard heavy-request cost of `FullNode::max_zerostate_size()`. The effect is availability/resource pressure on serving/DB actors rather than disk mutation.
- Why Critical/High or why not: pursue as potentially High because this is a concrete product-path cost mismatch before expensive work: the shard serving path has explicit global/per-method limits and max-size-based request cost, while the master serving path accepts the same heavy request family with no equivalent limiter before DB reads/serialization. Impact must still be confirmed locally because ADNL/ext-server exposure and default full-node master reachability determine exploitability.
- Verdict: pursue.
- Exact reason to pursue: `FullNodeMasterImpl::receive_query` dispatches heavy serving requests directly after TL parse, while `FullNodeShardImpl::receive_query` applies `limiter_->check_in(...)` using `request_cost_for_limiter`; `BlockFullSender` then performs DB block/proof reads and serializes a full response without a master-side token/rate gate.

### Candidate FNSERVE-SLICE-02 — offset/max_size boundary in persistent-state/archive slice serving

- Candidate ID: `FNSERVE-SLICE-02`
- Exact files/functions: `validator/full-node-master.cpp::FullNodeMasterImpl::{process_query(getArchiveSlice),process_query(downloadPersistentStateSliceV2)}`, `validator/full-node-shard.cpp::FullNodeShardImpl::{process_query(getArchiveSlice),process_query(downloadPersistentStateSliceV2)}`, `validator/manager.cpp::ValidatorManagerImpl::get_persistent_state_slice`, `validator/db/archive-manager.cpp::{get_persistent_state_slice,get_archive_slice}`, `validator/db/archive-slice.cpp::ArchiveSlice::get_slice`, `validator/db/files-async.hpp::db::ReadFile`.
- Entry point: inbound master or shard full-node slice query for archive or persistent-state bytes.
- Attacker model: authenticated full-node/overlay peer controlling `offset` and `max_size`.
- Attacker-controlled request fields: `archive_id`, state identifiers, `offset_`, and `max_size_`.
- Product-path reachability: both master and shard handlers forward valid max-size slice requests to manager/archive DB wrappers.
- Old-branch duplicate check: not CN-ARCHIVE-01 download-to-temp and not persistent-state Stage B split-state disk growth; this is serving-side slice bounds only.
- Authentication / overlay / peer requirements: master ADNL/ext-server path or shard overlay path; shard path passes the limiter first.
- Request cap / max_size / token / rate-limit before expensive work: both handlers reject `max_size < 0 || max_size > (1 << 24)` before calling DB/archive; shard handler also charges limiter cost by requested max size.
- DB/proof/state construction point: `ArchiveManager::get_persistent_state_slice` verifies the persistent state id is present in `perm_states_` before creating `db::ReadFile`; `ArchiveManager::get_archive_slice` resolves a package then calls `ArchiveSlice::get_slice`; `ArchiveSlice::get_slice` validates low archive id and package index before `db::ReadFile`.
- Serialization/BOC handling point: no BoC expansion; `db::ReadFile::start_up` calls `td::read_file(file_name_, max_length_, offset_)` and returns the slice bytes.
- Promise/state mutation point: one `ReadFile` actor owns the promise; no retained state or DB write occurs.
- Cleanup / abort / error handling: invalid max size is rejected before DB; missing state/archive/package returns error/notready; `ReadFile` sets result or notready error and stops.
- CPU/memory/disk/liveness condition: a peer can request repeated capped reads, but a single request is limited to 16 MiB and package/state existence is checked before read. The master no-limiter aspect is covered by `FNSERVE-MASTER-01`; the offset/max-size handling itself did not show a separate boundary bug.
- Why Critical/High or why not: not Critical/High as a standalone slice-boundary issue because the requested byte length is checked before read and the read actor does not loop, retain, or write data.
- Verdict: close.
- Exact kill reason: both master and shard slice handlers reject `max_size > (1 << 24)` before `get_persistent_state_slice`/`get_archive_slice`, and `ArchiveSlice::get_slice`/`ArchiveManager::get_persistent_state_slice` choose a known package/state before creating one `db::ReadFile` capped by the validated length.

### Candidate FNSERVE-OUTQ-03 — inbound getOutMsgQueueProof expensive proof construction before token/rate checks

- Candidate ID: `FNSERVE-OUTQ-03`
- Exact files/functions: `validator/full-node-shard.cpp::FullNodeShardImpl::process_query(tonNode_getOutMsgQueueProof)`, `validator/full-node-shard.cpp::FullNodeShardImpl::receive_query`, `validator/full-node.cpp::FullNodeImpl::{make_limiter,get_out_msg_queue_query_token}`.
- Entry point: inbound shard `tonNode_getOutMsgQueueProof` query.
- Attacker model: authenticated overlay peer requesting queue proofs.
- Attacker-controlled request fields: destination shard, block ids, imported-message queue limits.
- Product-path reachability: query id is included in the shard rate-limiter map, but the current handler returns `not supported yet` immediately.
- Old-branch duplicate check: not downloader `DLOUTMSGQ-05`; this is inbound serving handler work before proof construction.
- Authentication / overlay / peer requirements: active shard overlay query path.
- Request cap / max_size / token / rate-limit before expensive work: `FullNodeShardImpl::receive_query` applies `limiter_->check_in` before downcast; the handler then returns error before parsing block arrays or creating `BuildOutMsgQueueProof`. The commented implementation would request `get_out_msg_queue_query_token`, but it is not active code.
- DB/proof/state construction point: none in current product handler because proof construction is disabled/commented and `promise.set_error("not supported yet")` returns first.
- Serialization/BOC handling point: none beyond TL query parse.
- Promise/state mutation point: promise is resolved with an error; no retained actor/pending state.
- Cleanup / abort / error handling: immediate error.
- CPU/memory/disk/liveness condition: no proof construction or DB work is reachable from current inbound request fields.
- Why Critical/High or why not: not Critical/High because the expensive path is commented out and unreachable in current code.
- Verdict: close.
- Exact kill reason: current `process_query(tonNode_getOutMsgQueueProof)` executes `promise.set_error("not supported yet")` before the commented block-id parsing, token request, or `BuildOutMsgQueueProof` creation.

### Candidate FNSERVE-PREPARE-04 — prepare/proof handlers perform expensive proof construction before cheap rejection

- Candidate ID: `FNSERVE-PREPARE-04`
- Exact files/functions: `validator/full-node-master.cpp::FullNodeMasterImpl::{process_query(prepareBlockProof),process_query(prepareKeyBlockProof),process_query(downloadBlockProof),process_query(downloadBlockProofLink),process_query(downloadKeyBlockProof),process_query(downloadKeyBlockProofLink)}`, `validator/full-node-shard.cpp::FullNodeShardImpl::{process_query(prepareBlockProof),process_query(downloadBlockProof),process_query(downloadBlockProofLink)}`, `validator/manager.cpp::ValidatorManagerImpl::{get_block_proof,get_block_proof_link,get_key_block_proof}`.
- Entry point: inbound prepare/download proof queries.
- Attacker model: authenticated full-node peer requesting proof/proof-link objects by block id.
- Attacker-controlled request fields: block id and `allow_partial_`.
- Product-path reachability: master and shard handlers serve proof metadata and proof bytes for known blocks.
- Old-branch duplicate check: not VM-PROOF-02 poisoning; this checks serving cost/order only.
- Authentication / overlay / peer requirements: master ADNL/ext-server path or shard overlay path.
- Request cap / max_size / token / rate-limit before expensive work: shard path is limiter-gated; master path has no equivalent limiter, which is pursued under `FNSERVE-MASTER-01`. The proof handlers themselves perform cheap handle/existence checks before manager DB proof reads.
- DB/proof/state construction point: `downloadBlockProof` obtains `BlockHandle`, checks `inited_proof`/`inited_proof_link`, then calls manager `get_block_proof`/`get_block_proof_link`; key-block proof reads through `get_key_block_proof`/`get_key_block_proof_link`.
- Serialization/BOC handling point: manager unwraps `Proof`/`ProofLink` refs and returns existing `data()` bytes; no proof construction from request fields was found in these handlers.
- Promise/state mutation point: one callback per request resolves promise; no retained serving state.
- Cleanup / abort / error handling: unknown block/proof resolves with `protoviolation` or prepared-empty response; errors propagate through promise.
- CPU/memory/disk/liveness condition: repeated proof reads are DB/export load, but no request-field-triggered proof construction before existence checks was found; the missing master limiter is the only pursue-worthy cost mismatch.
- Why Critical/High or why not: close as a separate branch because the proof handlers check seqno/existence/inited proof flags before DB proof byte reads and do not construct new proofs in serving path.
- Verdict: close.
- Exact kill reason: `process_query(downloadBlockProof)` and `process_query(downloadBlockProofLink)` call `get_block_handle` and require `handle->inited_proof()` or `handle->inited_proof_link()` before `get_block_proof`/`get_block_proof_link`; prepare handlers return only prepared/empty descriptors.

### Parked candidates after full-node serving pass

- `CN-ARCHIVE-01` remains parked / runtime-trigger-blocked / not closed / not report-ready.
- New fact required to unpark `CN-ARCHIVE-01`: an existing repo-local local/testnet command or config that reliably enters `ArchiveImporter::start_up()` from-net import and a deterministic way to constrain `FullNodeShardImpl::choose_neighbour()` to a controlled attacker without target production patching, DB corruption, or harness-only assumptions.
- No full-node serving candidate is parked from this pass.
