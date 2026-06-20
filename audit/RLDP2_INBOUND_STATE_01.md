# TRANSPORT-RLDP2-INBOUND-STATE-01

Status: pursue / needs bounded local PoC / not report-ready.

## Hypothesis

An ADNL-reachable non-trusted peer can send many syntactically valid `rldp2_messagePart` packets with distinct `transfer_id` values to a target local id subscribed by RLDP2. `RldpIn` and `RldpConnection` create per-peer connection actor state and per-transfer `inbound_transfers_` state for unsolicited small transfers. The state is timeout-bounded, but no per-peer inbound-transfer count cap is visible in the inspected path.

## Static path confirmed

- `rldp2/rldp.cpp::RldpIn::add_id` subscribes `rldp2_messagePart`, `rldp2_confirm`, and `rldp2_complete` for a local ADNL id.
- `rldp2/rldp.cpp::RldpIn::receive_message_part` receives ADNL-delivered RLDP2 message parts and calls `get_or_create_connection(local_id, source, true)`.
- `rldp2/rldp.cpp::RldpIn::get_or_create_connection` creates a `RldpConnectionActor` when incoming peer MTU is nonzero and stores it in `connections_` with a 120-second connection timeout.
- `rldp2/rldp.cpp::RldpConnectionActor::receive_raw` forwards raw bytes to `RldpConnection::receive_raw`.
- `rldp2/RldpConnection.cpp::RldpConnection::receive_raw` parses `ton_api::rldp2_MessagePart`.
- `rldp2/RldpConnection.cpp::RldpConnection::receive_raw_obj(ton_api::rldp2_messagePart&)` checks `total_size`, FEC type, symbol size, `seqno`, `part`, and part size, then inserts a new `InboundTransfer` for unseen `transfer_id` values.
- `rldp2/RldpConnection.cpp::RldpConnection::loop_limits` expires inbound receive limits, calls `on_inbound_completed`, and erases `inbound_transfers_`.

## TL schema and serializer

TL schema:

```tl
fec.raptorQ data_size:int symbol_size:int symbols_count:int = fec.Type;
rldp2.messagePart transfer_id:int256 fec_type:fec.Type part:int total_size:long seqno:int data:bytes = rldp2.MessagePart;
```

Product serializer path:

```cpp
create_serialize_tl_object<ton::ton_api::rldp2_messagePart>(...)
```

The helper source under `audit/rldp2_inbound_state_01_client/` uses the generated TL object constructor and serializer. It does not hand-roll TL bytes.

## ADNL/session requirement

A packet must be delivered as an authenticated ADNL message to a target local id that has RLDP2 subscribed. Incoming RLDP2 connection creation requires `get_peer_mtu(local_id, peer_id) != 0`; otherwise the packet is dropped before `RldpConnectionActor` creation.

## Package files

- `audit/run_rldp2_inbound_state_01_local.sh`: dry-run-by-default plan/build/run wrapper.
- `audit/rldp2_inbound_state_01_client/rldp2_messagepart_generator.cpp`: local helper that generates one valid serialized `rldp2_messagePart` payload per invocation.
- `audit/rldp2_inbound_state_01_client/CMakeLists.txt`: helper build file.
- `audit/rldp2_inbound_state_01_sender/rldp2_adnl_sender.cpp`: repo-local product-path ADNL sender that reads `RLDP2_PACKET_FILE` and sends it with `Adnl::send_message` to a loopback target by default.
- `audit/rldp2_inbound_state_01_sender/CMakeLists.txt`: sender build file.
- `audit/RLDP2_INBOUND_STATE_01.md`: candidate and package status.

## Commands

Plan only, no traffic:

```bash
RLDP2_INBOUND_MODE=plan bash audit/run_rldp2_inbound_state_01_local.sh
```

Build helper and sender only:

```bash
RLDP2_INBOUND_MODE=build-helper bash audit/run_rldp2_inbound_state_01_local.sh
```

Build sender only:

```bash
RLDP2_INBOUND_MODE=build-sender bash audit/run_rldp2_inbound_state_01_local.sh
```

Bounded run template, local/private only:

```bash
RLDP2_INBOUND_MODE=run \
RLDP2_TARGET_HOST=127.0.0.1 \
RLDP2_TARGET_PORT=<private-target-adnl-port> \
RLDP2_TARGET_LOCAL_ID=<target-local-id-subscribed-by-rldp> \
RLDP2_TARGET_ADNL_PUBKEY_TL_HEX=<target-full-public-key-tl-hex> \
RLDP2_PEER_ID=ephemeral \
RLDP2_KEY_MATERIAL=ephemeral \
RLDP2_TARGET_PID=<target-process-pid> \
bash audit/run_rldp2_inbound_state_01_local.sh
```


## Sender resolution

The external `RLDP2_SEND_CMD` placeholder is replaced by a repo-local sender helper when built. The sender reads `RLDP2_PACKET_FILE`, requires `RLDP2_TARGET_HOST`, `RLDP2_TARGET_PORT`, and `RLDP2_TARGET_ADNL_PUBKEY_TL_HEX`, generates an ephemeral non-trusted local Ed25519 ADNL identity, adds the target full public key and UDP address to a local `Adnl` peer table, and sends the serialized `rldp2_messagePart` through `Adnl::send_message`. This is product-path ADNL delivery into the target's `AdnlLocalId::deliver` / `RldpIn::receive_message_part` subscription path, not a direct C++ call into `RldpConnection`.

The sender still requires the target full public key TL hex because ADNL encryption cannot be performed from only the short local id. If the local topology cannot export that full key, the candidate remains `PARKED_DELIVERY_BLOCKED`; if the full key and loopback port are available, run mode can exercise product-path delivery without an external sender command.

## Safety limits

Defaults:

- `RLDP2_INBOUND_MODE=plan`
- `RLDP2_WORKDIR=$HOME/ton-rldp2-inbound-state-01-local`
- `RLDP2_MAX_SECONDS=60`
- `RLDP2_MAX_TRANSFERS=2000`
- `RLDP2_SYMBOL_PAYLOAD_BYTES=768`
- `RLDP2_TOTAL_SIZE=7680`
- `RLDP2_MAX_RSS_DELTA_BYTES=268435456`

The wrapper refuses non-loopback targets unless `RLDP2_ALLOW_NON_LOCAL=1` is explicitly set, refuses empty target/peer/key/PID variables in run mode, requires `RLDP2_TARGET_ADNL_PUBKEY_TL_HEX`, defaults `RLDP2_SEND_CMD` to the repo-local sender when built, never runs `git clean`, and stores logs/metrics only under the workdir.

## PASS criteria

- Many distinct transfer ids are accepted far enough to create receiver-side RLDP2 transfer state.
- Memory, CPU, or actor-loop work scales with distinct `transfer_id` count under fixed small packet size.
- Cleanup after about 10 seconds is visible.
- Existing ADNL/RLDP2 limiters do not reject before transfer-state creation at bounded rates.
- The effect is stronger than ordinary bounded packet processing.

## FAIL / CLOSE criteria

- Packets cannot reach RLDP2 state from a non-trusted local peer.
- Existing limiter rejects before transfer-state insertion at low bounded rates.
- A hidden cap exists on `inbound_transfers_`, `limits_set_`, per-peer transfers, or connection actors.
- Invalid or incomplete small transfers are immediately discarded and not retained.
- Resource impact is low/ordinary and does not scale meaningfully.
