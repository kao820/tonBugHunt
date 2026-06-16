# FNSERVE-MASTER-01 local fullNodeMaster topology helper

This directory contains local/private-only topology tooling for `FNSERVE-MASTER-01`.
It does not send PoC traffic and does not mutate production configs.

## Modes

```bash
FNSERVE_TOPOLOGY_MODE=plan bash audit/fnserve_master_01_topology/setup_local_fullnodemaster.sh
```

Prints the setup plan only.

```bash
FNSERVE_TOPOLOGY_MODE=start \
FNSERVE_BUILD_DIR=/path/to/local/build \
bash audit/fnserve_master_01_topology/setup_local_fullnodemaster.sh
```

Starts a private `test/tontester` validator/fullnode topology under
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

The topology process is bounded by `FNSERVE_TOPOLOGY_MAX_SECONDS` and writes PID
and logs under the audit workdir.

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
or supplied local environment.

## Running the PoC wrapper after setup

The setup helper only prepares variables. To inspect the safe plan:

```bash
source "$HOME/ton-fnserve-master-01-topology/env/fnserve_master_01.env"
FNSERVE_MODE=plan bash audit/run_fnserve_master_01_local.sh
```

Only run bounded request traffic by explicitly setting `FNSERVE_MODE=run` after
reviewing the plan and safety limits.
