# FNSERVE-MASTER-01 local ADNL `tonNode_query` client

This helper is a local-only PoC utility for `FNSERVE-MASTER-01`. It sends exactly one `tonNode_query` request to a configured full-node-master ADNL ext-server and exits. It is not a production component and does not patch target logic.

Supported request kinds:

- `downloadZeroState`
- `downloadBlockFull`

## Safety defaults

- Requires explicit `FNSERVE_MASTER_HOST` and `FNSERVE_MASTER_PORT`.
- Refuses public hosts by default; set `FNSERVE_ALLOW_PRIVATE_NONLOCAL=1` only for a private lab network.
- Sends exactly one request per invocation.
- Reads request parameters only from environment variables so `audit/run_fnserve_master_01_local.sh` can bound request count, parallelism, and runtime.

## Build

From the repository root:

```bash
cmake -S audit/fnserve_master_01_client -B audit/fnserve_master_01_client/build
cmake --build audit/fnserve_master_01_client/build --target fnserve_master_query_client -j"$(nproc)"
```

## Required environment

```bash
FNSERVE_REQUEST_KIND=downloadZeroState|downloadBlockFull
FNSERVE_MASTER_HOST=127.0.0.1
FNSERVE_MASTER_PORT=<configured-fullnodemaster-port>
FNSERVE_MASTER_PUBKEY_TL_HEX=<TL-serialized full ADNL public key as hex>
FNSERVE_ZERO_STATE_BLOCK='(workchain,shard_hex,seqno):root_hash_hex:file_hash_hex'
FNSERVE_BLOCK_ID='(workchain,shard_hex,seqno):root_hash_hex:file_hash_hex'
```

`FNSERVE_CLIENT_PRIVKEY_TL_HEX` is optional. If absent, the helper generates an ephemeral Ed25519 client key, which is suitable for testing non-trusted ADNL authentication because it is distinct from validator-engine-console/operator keys.

## Wrapper integration

After building, either let `audit/run_fnserve_master_01_local.sh` auto-detect the helper binary at `audit/fnserve_master_01_client/build/fnserve_master_query_client`, or set:

```bash
export FNSERVE_CLIENT_CMD='audit/fnserve_master_01_client/build/fnserve_master_query_client'
```

The wrapper passes `FNSERVE_REQUEST_KIND`, `FNSERVE_MASTER_HOST`, `FNSERVE_MASTER_PORT`, `FNSERVE_ZERO_STATE_BLOCK`, and `FNSERVE_BLOCK_ID` into each invocation.
