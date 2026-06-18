# FNSERVE-MASTER-01 local fullNodeMaster topology helper

This directory contains local/private-only topology tooling for `FNSERVE-MASTER-01`.
It does not send PoC traffic and does not mutate production configs.

## Modes

### Reproducible matching build and start

Use the current worktree with Clang and Python 3.14 or newer. This avoids the
GCC 13 C++20 coroutine/chrono compatibility failures and the Python 3.12 eager
annotation failures without patching product sources:

```bash
FNSERVE_TOPOLOGY_MODE=build-start \
FNSERVE_BUILD_DIR="$HOME/ton-fnserve-master-01-build" \
FNSERVE_BUILD_JOBS=12 \
bash audit/fnserve_master_01_topology/setup_local_fullnodemaster.sh
```

`build-start` invokes `build_matching_binaries.sh`, which configures a clean
Clang build and builds the exact binaries used by `test/tontester`:

* `validator-engine`
* `validator-engine-console`
* `create-state`
* `fift`
* `lite-client`
* `dht-server`
* `generate-random-id`
* `tonlibjson`

The build preflight requires initialized direct submodules plus `cmake`,
`ninja`, `clang`, `clang++`, `autoconf`, `automake`, and `libtool`. Generated
smart-contract Fift files are consumed from the matching build or source
generation directory; no copied production configuration is modified.

```bash
FNSERVE_TOPOLOGY_MODE=plan bash audit/fnserve_master_01_topology/setup_local_fullnodemaster.sh
```

Prints the setup plan only.

```bash
FNSERVE_TOPOLOGY_MODE=start \
FNSERVE_BUILD_DIR=/path/to/local/build \
bash audit/fnserve_master_01_topology/setup_local_fullnodemaster.sh
```

Generates repo-local Python TL bindings (`tonapi.ton_api` and `tonapi.tonlib_api`) under
`${FNSERVE_TOPOLOGY_WORKDIR:-$HOME/ton-fnserve-master-01-topology}/python/tonapi`, validates
`from tonapi import ton_api, tonlib_api` and `from tontester.install import Install`,
then starts a private `test/tontester` validator/fullnode topology under
`${FNSERVE_TOPOLOGY_WORKDIR:-$HOME/ton-fnserve-master-01-topology}`, injects an
`engine.validator.fullNodeMaster` entry into the copied local test config before
`validator-engine` starts, waits for a local masterchain block, and writes:

```bash
$HOME/ton-fnserve-master-01-topology/env/fnserve_master_01.env
```

The env file contains:

* `FNSERVE_CONFIG`
* `FNSERVE_MASTER_HOST=127.0.0.1`
* `FNSERVE_MASTER_PORT`
* `FNSERVE_MASTER_PUBKEY_TL_HEX`
* `FNSERVE_ZERO_STATE_BLOCK`
* `FNSERVE_BLOCK_ID`
* `FNSERVE_TARGET_PID`
* `FNSERVE_VALIDATOR_ENGINE`

The topology process is bounded by `FNSERVE_TOPOLOGY_MAX_SECONDS` and writes PID,
logs, generated Python bindings, and import-check output under the audit workdir.
Each start uses a unique `runs/<UTC timestamp>-<pid>/tontester-topology`
directory, so a stale keyring from an older bounded run is never reused or
destructively deleted.

## Reuse/extract mode

If a local/private validator-engine config already contains `fullnodemasters`, run:

```bash
FNSERVE_TOPOLOGY_MODE=reuse \
FNSERVE_CONFIG=/path/to/config.json \
FNSERVE_VALIDATOR_ENGINE=/path/to/validator-engine \
bash audit/fnserve_master_01_topology/setup_local_fullnodemaster.sh
```

The extractor refuses non-local hosts and reports `FORMAT FNSERVE_TOPOLOGY_BLOCKED`
if any required run variable cannot be derived from the config, logs, live process,
or supplied local environment. The start path does not rely on external `pip install tonapi`;
it uses `test/tontester/src/tl/gen.py` against `tl/generate/scheme/{lite_api,ton_api,tonlib_api}.tl`.

## Running the PoC wrapper after setup

The setup helper only prepares variables. To inspect the safe plan:

```bash
source "$HOME/ton-fnserve-master-01-topology/env/fnserve_master_01.env"
FNSERVE_MODE=plan bash audit/run_fnserve_master_01_local.sh
```

Only run bounded request traffic by explicitly setting `FNSERVE_MODE=run` after
reviewing the plan and safety limits.
