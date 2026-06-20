#!/usr/bin/env bash
set -euo pipefail

RLDP2_INBOUND_MODE="${RLDP2_INBOUND_MODE:-plan}"
RLDP2_WORKDIR="${RLDP2_WORKDIR:-$HOME/ton-rldp2-inbound-state-01-local}"
RLDP2_MAX_SECONDS="${RLDP2_MAX_SECONDS:-60}"
RLDP2_MAX_TRANSFERS="${RLDP2_MAX_TRANSFERS:-2000}"
RLDP2_MAX_RSS_DELTA_BYTES="${RLDP2_MAX_RSS_DELTA_BYTES:-268435456}"
RLDP2_SYMBOL_PAYLOAD_BYTES="${RLDP2_SYMBOL_PAYLOAD_BYTES:-768}"
RLDP2_TOTAL_SIZE="${RLDP2_TOTAL_SIZE:-7680}"
RLDP2_TARGET_HOST="${RLDP2_TARGET_HOST:-127.0.0.1}"
RLDP2_TARGET_PORT="${RLDP2_TARGET_PORT:-}"
RLDP2_TARGET_LOCAL_ID="${RLDP2_TARGET_LOCAL_ID:-}"
RLDP2_PEER_ID="${RLDP2_PEER_ID:-}"
RLDP2_KEY_MATERIAL="${RLDP2_KEY_MATERIAL:-}"
RLDP2_TARGET_PID="${RLDP2_TARGET_PID:-}"
RLDP2_ALLOW_NON_LOCAL="${RLDP2_ALLOW_NON_LOCAL:-0}"
RLDP2_TARGET_ADNL_PUBKEY_TL_HEX="${RLDP2_TARGET_ADNL_PUBKEY_TL_HEX:-}"
RLDP2_SENDER_BUILD_DIR="${RLDP2_SENDER_BUILD_DIR:-$RLDP2_WORKDIR/sender-build}"
RLDP2_SENDER_BIN="${RLDP2_SENDER_BIN:-$RLDP2_SENDER_BUILD_DIR/rldp2_adnl_sender}"
RLDP2_SEND_CMD="${RLDP2_SEND_CMD:-}"
RLDP2_HELPER_BUILD_DIR="${RLDP2_HELPER_BUILD_DIR:-$RLDP2_WORKDIR/helper-build}"
RLDP2_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RLDP2_LOG_DIR="$RLDP2_WORKDIR/logs"
RLDP2_METRIC_DIR="$RLDP2_WORKDIR/metrics"
RLDP2_RUN_DIR="$RLDP2_WORKDIR/run"
RLDP2_PACKET_DIR="$RLDP2_RUN_DIR/packets"
RLDP2_VERDICT_FILE="$RLDP2_RUN_DIR/final_verdict.txt"

log() { printf '[rldp2-inbound-state-01] %s\n' "$*"; }
fail_verdict() { mkdir -p "$RLDP2_RUN_DIR"; printf '%s\n' "$1" | tee "$RLDP2_VERDICT_FILE"; exit "${2:-1}"; }
need_tool() { command -v "$1" >/dev/null 2>&1 || { echo "missing tool: $1"; return 1; }; }

is_loopback_host() {
  case "$RLDP2_TARGET_HOST" in
    127.*|localhost|::1) return 0 ;;
    *) return 1 ;;
  esac
}

print_static_confirmation() {
  cat <<'STATIC'
STATIC_PATH_CONFIRMED:
- rldp2/rldp.cpp::RldpIn::add_id subscribes rldp2_messagePart / confirm / complete.
- rldp2/rldp.cpp::RldpIn::receive_message_part calls get_or_create_connection(local_id, source, true).
- rldp2/rldp.cpp::RldpIn::get_or_create_connection creates a per-peer RldpConnectionActor if get_peer_mtu(local_id, peer_id) is nonzero.
- rldp2/rldp.cpp::RldpConnectionActor::receive_raw forwards to RldpConnection::receive_raw.
- rldp2/RldpConnection.cpp::receive_raw parses ton_api::rldp2_MessagePart.
- rldp2/RldpConnection.cpp::receive_raw_obj(rldp2_messagePart&) validates total_size/fec/part/seqno and inserts InboundTransfer for new transfer_id.
- rldp2/RldpConnection.cpp::loop_limits times out inbound transfers and erases inbound_transfers_ through on_inbound_completed.
TL_SCHEMA_USED:
- tl/generate/scheme/ton_api.tl: rldp2.messagePart transfer_id:int256 fec_type:fec.Type part:int total_size:long seqno:int data:bytes = rldp2.MessagePart;
- tl/generate/scheme/ton_api.tl: fec.raptorQ data_size:int symbol_size:int symbols_count:int = fec.Type;
SERIALIZER_USED:
- Product code uses create_serialize_tl_object<ton_api::rldp2_messagePart>(...) in rldp2/RldpConnection.cpp.
- Helper generator uses the same generated TL constructor/serializer and does not hand-roll TL bytes.
ADNL_SESSION_REQUIREMENT:
- A packet must reach ADNL as an authenticated peer packet addressed to a target local id subscribed by RldpIn::add_id.
- The target must have nonzero peer MTU for the source peer, otherwise incoming RLDP2 connection creation is refused.
STATIC
}

preflight_common() {
  mkdir -p "$RLDP2_LOG_DIR" "$RLDP2_METRIC_DIR" "$RLDP2_RUN_DIR" "$RLDP2_PACKET_DIR"
  log "repo_root=$RLDP2_REPO_ROOT"
  log "branch=$(git -C "$RLDP2_REPO_ROOT" rev-parse --abbrev-ref HEAD)"
  log "commit=$(git -C "$RLDP2_REPO_ROOT" rev-parse HEAD)"
  local missing=0
  for tool in git cmake python3 awk sed date ps; do
    need_tool "$tool" || missing=1
  done
  if [[ "$missing" -ne 0 ]]; then
    fail_verdict "BLOCKER_MISSING_TOOLS" 2
  fi
  git -C "$RLDP2_REPO_ROOT" submodule status > "$RLDP2_LOG_DIR/submodule_status.txt" || true
  df -B1 "$RLDP2_WORKDIR" > "$RLDP2_METRIC_DIR/df_start.txt" 2>/dev/null || df -B1 "$HOME" > "$RLDP2_METRIC_DIR/df_start.txt"
  print_static_confirmation | tee "$RLDP2_LOG_DIR/static_confirmation.txt"
}

build_helper() {
  preflight_common
  cmake -S "$RLDP2_REPO_ROOT/audit/rldp2_inbound_state_01_client" -B "$RLDP2_HELPER_BUILD_DIR" \
    -DTON_SOURCE_ROOT="$RLDP2_REPO_ROOT"
  cmake --build "$RLDP2_HELPER_BUILD_DIR" --target rldp2_messagepart_generator -- -j1
  log "helper=$RLDP2_HELPER_BUILD_DIR/rldp2_messagepart_generator"
}

build_sender() {
  preflight_common
  cmake -S "$RLDP2_REPO_ROOT/audit/rldp2_inbound_state_01_sender" -B "$RLDP2_SENDER_BUILD_DIR" \
    -DTON_SOURCE_ROOT="$RLDP2_REPO_ROOT"
  cmake --build "$RLDP2_SENDER_BUILD_DIR" --target rldp2_adnl_sender -- -j1
  log "sender=$RLDP2_SENDER_BIN"
}

require_run_inputs() {
  if ! is_loopback_host && [[ "$RLDP2_ALLOW_NON_LOCAL" != "1" ]]; then
    fail_verdict "BLOCKER_NON_LOCAL_TARGET_REFUSED" 2
  fi
  [[ -n "$RLDP2_TARGET_PORT" ]] || fail_verdict "BLOCKER_EMPTY_TARGET_PORT" 2
  [[ -n "$RLDP2_TARGET_LOCAL_ID" ]] || fail_verdict "BLOCKER_EMPTY_TARGET_LOCAL_ID" 2
  [[ -n "$RLDP2_PEER_ID" ]] || fail_verdict "BLOCKER_EMPTY_PEER_ID" 2
  [[ -n "$RLDP2_KEY_MATERIAL" ]] || fail_verdict "BLOCKER_EMPTY_KEY_MATERIAL" 2
  [[ -n "$RLDP2_TARGET_PID" ]] || fail_verdict "BLOCKER_EMPTY_TARGET_PID" 2
  if [[ -z "$RLDP2_SEND_CMD" && -x "$RLDP2_SENDER_BIN" ]]; then
    RLDP2_SEND_CMD="$RLDP2_SENDER_BIN"
  fi
  [[ -n "$RLDP2_TARGET_ADNL_PUBKEY_TL_HEX" ]] || fail_verdict "BLOCKER_EMPTY_TARGET_ADNL_PUBKEY_TL_HEX" 2
  [[ -n "$RLDP2_SEND_CMD" ]] || fail_verdict "BLOCKER_EMPTY_RLDP2_SEND_CMD" 2
  [[ "$RLDP2_SYMBOL_PAYLOAD_BYTES" -le 1024 ]] || fail_verdict "BLOCKER_PACKET_SIZE_LIMIT" 2
  [[ "$RLDP2_TOTAL_SIZE" -le 7680 ]] || fail_verdict "BLOCKER_TOTAL_SIZE_LIMIT" 2
  ps -p "$RLDP2_TARGET_PID" >/dev/null || fail_verdict "BLOCKER_TARGET_NOT_RUNNING" 2
}

rss_bytes() {
  local pid="$1"
  local rss_kb
  rss_kb=$(ps -o rss= -p "$pid" | awk '{print $1+0}')
  echo $((rss_kb * 1024))
}

collect_process_snapshot() {
  local label="$1"
  ps -o pid,ppid,stat,rss,vsz,%cpu,%mem,etime,command -p "$RLDP2_TARGET_PID" > "$RLDP2_METRIC_DIR/process_${label}.txt" || true
}

run_bounded() {
  preflight_common
  require_run_inputs
  local helper="$RLDP2_HELPER_BUILD_DIR/rldp2_messagepart_generator"
  [[ -x "$helper" ]] || fail_verdict "BLOCKER_HELPER_NOT_BUILT" 2

  local started now elapsed base_rss current_rss delta sent accepted rejected errors
  started=$(date +%s)
  base_rss=$(rss_bytes "$RLDP2_TARGET_PID")
  sent=0; accepted=0; rejected=0; errors=0
  collect_process_snapshot start
  printf 'timestamp\ttransfer_id\tsend_result\tstatus\tresponse_or_error\telapsed_ms\n' > "$RLDP2_LOG_DIR/helper.tsv"

  while [[ "$sent" -lt "$RLDP2_MAX_TRANSFERS" ]]; do
    now=$(date +%s); elapsed=$((now - started))
    [[ "$elapsed" -lt "$RLDP2_MAX_SECONDS" ]] || break
    ps -p "$RLDP2_TARGET_PID" >/dev/null || fail_verdict "FAIL_TARGET_EXITED" 1
    current_rss=$(rss_bytes "$RLDP2_TARGET_PID"); delta=$((current_rss - base_rss))
    if [[ "$delta" -gt "$RLDP2_MAX_RSS_DELTA_BYTES" ]]; then
      fail_verdict "STOP_RSS_DELTA_LIMIT sent=$sent base_rss=$base_rss current_rss=$current_rss delta=$delta" 0
    fi

    local packet_file gen_log transfer_id start_ms end_ms send_status send_out
    packet_file="$RLDP2_PACKET_DIR/packet_${sent}.bin"
    gen_log="$RLDP2_PACKET_DIR/packet_${sent}.tsv"
    RLDP2_PACKET_OUT="$packet_file" RLDP2_SYMBOL_PAYLOAD_BYTES="$RLDP2_SYMBOL_PAYLOAD_BYTES" RLDP2_TOTAL_SIZE="$RLDP2_TOTAL_SIZE" "$helper" > "$gen_log"
    transfer_id=$(awk 'NR==2 {print $2}' "$gen_log")
    start_ms=$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)
    if send_out=$(RLDP2_PACKET_FILE="$packet_file" RLDP2_TARGET_HOST="$RLDP2_TARGET_HOST" RLDP2_TARGET_PORT="$RLDP2_TARGET_PORT" RLDP2_TARGET_LOCAL_ID="$RLDP2_TARGET_LOCAL_ID" RLDP2_TARGET_ADNL_PUBKEY_TL_HEX="$RLDP2_TARGET_ADNL_PUBKEY_TL_HEX" RLDP2_PEER_ID="$RLDP2_PEER_ID" RLDP2_KEY_MATERIAL="$RLDP2_KEY_MATERIAL" bash -c "$RLDP2_SEND_CMD" 2>&1); then
      send_status="ok"; accepted=$((accepted + 1))
    else
      send_status="error"; errors=$((errors + 1))
    fi
    end_ms=$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$transfer_id" "$sent" "$send_status" "${send_out//$'\t'/ }" "$((end_ms - start_ms))" >> "$RLDP2_LOG_DIR/helper.tsv"
    sent=$((sent + 1))
    if (( sent % 10 == 0 )); then
      collect_process_snapshot "$sent"
    fi
  done

  collect_process_snapshot end
  df -B1 "$RLDP2_WORKDIR" > "$RLDP2_METRIC_DIR/df_end.txt" 2>/dev/null || true
  current_rss=$(rss_bytes "$RLDP2_TARGET_PID"); delta=$((current_rss - base_rss))
  cat > "$RLDP2_VERDICT_FILE" <<EOF_VERDICT
NEEDS_REVIEW_RUNTIME_EVIDENCE
sent=$sent
accepted=$accepted
rejected=$rejected
errors=$errors
base_rss=$base_rss
end_rss=$current_rss
rss_delta=$delta
helper_tsv=$RLDP2_LOG_DIR/helper.tsv
metrics_dir=$RLDP2_METRIC_DIR
EOF_VERDICT
  cat "$RLDP2_VERDICT_FILE"
}

plan() {
  preflight_common
  cat <<EOF_PLAN
FORMAT RLDP2_INBOUND_STATE_PLAN
candidate_id: TRANSPORT-RLDP2-INBOUND-STATE-01
mode: plan/no-traffic
workdir: $RLDP2_WORKDIR
build_helper_command: RLDP2_INBOUND_MODE=build-helper bash audit/run_rldp2_inbound_state_01_local.sh
build_sender_command: RLDP2_INBOUND_MODE=build-sender bash audit/run_rldp2_inbound_state_01_local.sh
run_command_template: RLDP2_INBOUND_MODE=run RLDP2_TARGET_HOST=127.0.0.1 RLDP2_TARGET_PORT=<port> RLDP2_TARGET_LOCAL_ID=<target-local-id> RLDP2_TARGET_ADNL_PUBKEY_TL_HEX=<target-full-public-key-tl-hex> RLDP2_PEER_ID=ephemeral RLDP2_KEY_MATERIAL=ephemeral RLDP2_TARGET_PID=<pid> bash audit/run_rldp2_inbound_state_01_local.sh
required_run_inputs:
- RLDP2_TARGET_HOST must be loopback unless RLDP2_ALLOW_NON_LOCAL=1.
- RLDP2_TARGET_PORT must identify the private/local target ADNL endpoint.
- RLDP2_TARGET_LOCAL_ID must be the local id subscribed through RldpIn::add_id.
- RLDP2_TARGET_ADNL_PUBKEY_TL_HEX must be the target local id full public key TL bytes as hex so the repo-local sender can encrypt an ADNL packet.
- RLDP2_PEER_ID and RLDP2_KEY_MATERIAL may be set to ephemeral for the repo-local sender, which generates a non-trusted local ADNL identity.
- RLDP2_SEND_CMD defaults to the repo-local rldp2_adnl_sender binary when it exists; overrides must send the binary TL payload from \$RLDP2_PACKET_FILE as an ADNL message from the peer to the target local id.
no_traffic_sent: yes
EOF_PLAN
}

case "$RLDP2_INBOUND_MODE" in
  plan) plan ;;
  build-helper) build_helper; build_sender ;;
  build-sender) build_sender ;;
  run) run_bounded ;;
  *) echo "unknown RLDP2_INBOUND_MODE=$RLDP2_INBOUND_MODE" >&2; exit 2 ;;
esac
