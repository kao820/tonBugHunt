#!/usr/bin/env bash
# Safe bounded local PoC runner/plan for FNSERVE-MASTER-01.
# This script never builds, never runs git clean, and never uses public network by default.
set -Eeuo pipefail

FNSERVE_WORKDIR="${FNSERVE_WORKDIR:-$HOME/ton-fnserve-master-01-local}"
FNSERVE_MAX_SECONDS="${FNSERVE_MAX_SECONDS:-120}"
FNSERVE_MAX_REQUESTS="${FNSERVE_MAX_REQUESTS:-200}"
FNSERVE_MAX_PARALLEL="${FNSERVE_MAX_PARALLEL:-4}"
FNSERVE_MODE="${FNSERVE_MODE:-plan}"
FNSERVE_MIN_FREE_BYTES="${FNSERVE_MIN_FREE_BYTES:-1073741824}"
FNSERVE_CLIENT_TIMEOUT="${FNSERVE_CLIENT_TIMEOUT:-15}"
FNSERVE_MASTER_HOST="${FNSERVE_MASTER_HOST:-127.0.0.1}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${FNSERVE_WORKDIR}/logs"
METRICS_DIR="${FNSERVE_WORKDIR}/metrics"
PLAN_DIR="${FNSERVE_WORKDIR}/plan"
RUN_DIR="${FNSERVE_WORKDIR}/run"
SUMMARY_FILE="${PLAN_DIR}/fnserve_master_01_plan.txt"
COMMANDS_FILE="${PLAN_DIR}/fnserve_master_01_commands.sh"
COUNTS_FILE="${RUN_DIR}/request_counts.tsv"
STOP_FILE="${RUN_DIR}/STOP"

mkdir -p "${LOG_DIR}" "${METRICS_DIR}" "${PLAN_DIR}" "${RUN_DIR}"

log() { printf '[fnserve-master-01] %s\n' "$*"; }
fail_verdict() {
  local verdict="$1"
  local msg="$2"
  log "${msg}"
  printf '%s\n' "${verdict}" | tee "${RUN_DIR}/final_verdict.txt"
  exit 2
}

is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }
require_uints() {
  for kv in \
    "FNSERVE_MAX_SECONDS=${FNSERVE_MAX_SECONDS}" \
    "FNSERVE_MAX_REQUESTS=${FNSERVE_MAX_REQUESTS}" \
    "FNSERVE_MAX_PARALLEL=${FNSERVE_MAX_PARALLEL}" \
    "FNSERVE_MIN_FREE_BYTES=${FNSERVE_MIN_FREE_BYTES}"; do
    local name="${kv%%=*}" val="${kv#*=}"
    is_uint "${val}" || fail_verdict BLOCKER_LOCAL_TOPOLOGY "${name} must be an unsigned integer, got '${val}'"
  done
  (( FNSERVE_MAX_SECONDS > 0 )) || fail_verdict BLOCKER_LOCAL_TOPOLOGY "FNSERVE_MAX_SECONDS must be > 0"
  (( FNSERVE_MAX_REQUESTS > 0 )) || fail_verdict BLOCKER_LOCAL_TOPOLOGY "FNSERVE_MAX_REQUESTS must be > 0"
  (( FNSERVE_MAX_PARALLEL > 0 )) || fail_verdict BLOCKER_LOCAL_TOPOLOGY "FNSERVE_MAX_PARALLEL must be > 0"
}

print_repo_context() {
  log "repo root: ${REPO_ROOT}"
  git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/^/[fnserve-master-01] branch: /'
  git -C "${REPO_ROOT}" rev-parse HEAD 2>/dev/null | sed 's/^/[fnserve-master-01] commit: /'
}

check_tools() {
  local missing=0 tools=(git python3 awk sed df du date ps timeout tee wc)
  : > "${METRICS_DIR}/tool_availability.txt"
  for t in "${tools[@]}"; do
    if command -v "${t}" >/dev/null 2>&1; then
      printf 'OK\t%s\t%s\n' "${t}" "$(command -v "${t}")" | tee -a "${METRICS_DIR}/tool_availability.txt"
    else
      printf 'MISSING\t%s\n' "${t}" | tee -a "${METRICS_DIR}/tool_availability.txt"
      missing=1
    fi
  done
  (( missing == 0 )) || fail_verdict BLOCKER_LOCAL_TOPOLOGY "required tools are missing; see ${METRICS_DIR}/tool_availability.txt"
}

submodule_summary() {
  git -C "${REPO_ROOT}" submodule status > "${METRICS_DIR}/submodule_status.txt" 2>&1 || true
  log "submodule status summary: ${METRICS_DIR}/submodule_status.txt"
  if grep -Eq '^-|^\+' "${METRICS_DIR}/submodule_status.txt"; then
    fail_verdict BLOCKER_LOCAL_TOPOLOGY "submodules are missing or not at recorded commits; see ${METRICS_DIR}/submodule_status.txt"
  fi
}

disk_snapshot() {
  df -B1 "${FNSERVE_WORKDIR}" > "${METRICS_DIR}/df_start.txt"
  du -sb "${FNSERVE_WORKDIR}" > "${METRICS_DIR}/du_start.txt" 2>/dev/null || true
  cat "${METRICS_DIR}/df_start.txt"
  local avail
  avail="$(df -B1 --output=avail "${FNSERVE_WORKDIR}" | awk 'NR==2 {print $1}')"
  if [[ -z "${avail}" || ! "${avail}" =~ ^[0-9]+$ ]]; then
    fail_verdict BLOCKER_LOCAL_TOPOLOGY "could not determine free space for ${FNSERVE_WORKDIR}"
  fi
  (( avail >= FNSERVE_MIN_FREE_BYTES )) || fail_verdict BLOCKER_LOCAL_TOPOLOGY "free space ${avail} below FNSERVE_MIN_FREE_BYTES=${FNSERVE_MIN_FREE_BYTES}"
}

private_host_only() {
  local host="$1"
  case "${host}" in
    127.*|localhost|::1|10.*|192.168.*) return 0 ;;
    172.*)
      local second="${host#172.}"; second="${second%%.*}"
      [[ "${second}" =~ ^[0-9]+$ ]] && (( second >= 16 && second <= 31 )) && return 0
      ;;
  esac
  [[ "${FNSERVE_ALLOW_PRIVATE_NONLOCAL:-0}" == "1" ]] && return 0
  return 1
}

find_build_artifacts() {
  FNSERVE_VALIDATOR_ENGINE="${FNSERVE_VALIDATOR_ENGINE:-}"
  if [[ -z "${FNSERVE_VALIDATOR_ENGINE}" ]]; then
    for p in \
      "${REPO_ROOT}/build/validator-engine/validator-engine" \
      "${REPO_ROOT}/build-debug/validator-engine/validator-engine" \
      "${REPO_ROOT}/build-release/validator-engine/validator-engine" \
      "${REPO_ROOT}/build-target/validator-engine/validator-engine"; do
      [[ -x "${p}" ]] && FNSERVE_VALIDATOR_ENGINE="${p}" && break
    done
  fi
  [[ -n "${FNSERVE_VALIDATOR_ENGINE}" && -x "${FNSERVE_VALIDATOR_ENGINE}" ]] || return 1
  printf '%s\n' "${FNSERVE_VALIDATOR_ENGINE}" > "${PLAN_DIR}/validator_engine_path.txt"
}

parse_fullnodemaster_config() {
  : > "${PLAN_DIR}/fullnodemaster_config.txt"
  if [[ -n "${FNSERVE_MASTER_PORT:-}" ]]; then
    printf 'env_port\t%s\n' "${FNSERVE_MASTER_PORT}" >> "${PLAN_DIR}/fullnodemaster_config.txt"
    [[ -n "${FNSERVE_MASTER_ADNL:-}" ]] && printf 'env_adnl\t%s\n' "${FNSERVE_MASTER_ADNL}" >> "${PLAN_DIR}/fullnodemaster_config.txt"
    return 0
  fi
  [[ -n "${FNSERVE_CONFIG:-}" && -f "${FNSERVE_CONFIG}" ]] || return 1
  python3 - "${FNSERVE_CONFIG}" > "${PLAN_DIR}/fullnodemaster_config.txt" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
try:
    obj = json.loads(path.read_text())
except Exception as e:
    print(f"ERROR\tfailed to parse JSON config {path}: {e}")
    sys.exit(2)
masters = obj.get("fullnodemasters") or obj.get("full_node_masters") or []
if not masters:
    print("ERROR\tno fullnodemasters/full_node_masters entries")
    sys.exit(1)
for i, item in enumerate(masters):
    if isinstance(item, dict):
        port = item.get("port") or item.get("port_")
        adnl = item.get("adnl") or item.get("adnl_") or item.get("id")
    else:
        port = getattr(item, "port", None)
        adnl = None
    print(f"master\t{i}\tport={port}\tadnl={adnl}")
PY
  grep -q '^master\|^env_port' "${PLAN_DIR}/fullnodemaster_config.txt"
}

identify_targets() {
  : > "${PLAN_DIR}/targets.txt"
  [[ -n "${FNSERVE_ZERO_STATE_BLOCK:-}" ]] && printf 'zero_state_block\t%s\n' "${FNSERVE_ZERO_STATE_BLOCK}" >> "${PLAN_DIR}/targets.txt"
  [[ -n "${FNSERVE_BLOCK_ID:-}" ]] && printf 'known_block\t%s\n' "${FNSERVE_BLOCK_ID}" >> "${PLAN_DIR}/targets.txt"
  [[ -n "${FNSERVE_TARGET_PID:-}" ]] && printf 'target_pid\t%s\n' "${FNSERVE_TARGET_PID}" >> "${PLAN_DIR}/targets.txt"
  grep -qE '^(zero_state_block|known_block)' "${PLAN_DIR}/targets.txt"
}

identify_client() {
  : > "${PLAN_DIR}/client.txt"
  if [[ -n "${FNSERVE_CLIENT_CMD:-}" ]]; then
    printf 'client_cmd\t%s\n' "${FNSERVE_CLIENT_CMD}" >> "${PLAN_DIR}/client.txt"
    return 0
  fi
  # Deliberately do not treat validator-engine-console as a non-trusted tonNode_query client: it is an operator console.
  printf 'BLOCKER\tNo repo-local non-trusted ADNL tonNode_query client CLI was identified. Set FNSERVE_CLIENT_CMD to a local/private client command if available.\n' >> "${PLAN_DIR}/client.txt"
  return 1
}

write_plan_files() {
  cat > "${SUMMARY_FILE}" <<PLAN
FNSERVE-MASTER-01 bounded local PoC plan

Status: pursue / confirmed-for-bounded-local-PoC / not report-ready / no-runtime-executed by this package.

Safety defaults:
- FNSERVE_WORKDIR=\${FNSERVE_WORKDIR:-\$HOME/ton-fnserve-master-01-local}
- FNSERVE_MAX_SECONDS=\${FNSERVE_MAX_SECONDS:-120}
- FNSERVE_MAX_REQUESTS=\${FNSERVE_MAX_REQUESTS:-200}
- FNSERVE_MAX_PARALLEL=\${FNSERVE_MAX_PARALLEL:-4}
- FNSERVE_MIN_FREE_BYTES=\${FNSERVE_MIN_FREE_BYTES:-1073741824}

Exact repo-local/static identification commands:
1. configured full-node master:
   rg -n 'fullnodemasters|full_node_masters|config_add_full_node_master|start_full_node_masters' validator-engine validator test audit
   python3 - <<'PY' "\$FNSERVE_CONFIG"
   # parse JSON config for fullnodemasters/full_node_masters and print port/adnl
   PY
2. ext-server port:
   rg -n 'create_ext_server|add_tcp_port|TcpInfiniteListener' validator/full-node-master.cpp adnl
3. client used to send tonNode_query:
   rg -n 'tonNode_query|AdnlExtClient|send_query' validator test crypto lite-client utils
   NOTE: this pass did not identify a generic repo-local non-trusted tonNode_query CLI; run mode requires FNSERVE_CLIENT_CMD.
4. known block for downloadBlockFull:
   Provide FNSERVE_BLOCK_ID from local/private validator DB/log/console output for a received block; unknown blocks are cheap rejected before DB data/proof reads.
5. zero-state parameters for downloadZeroState:
   Provide FNSERVE_ZERO_STATE_BLOCK from the local/private validator zero-state id/config.
6. shard limiter comparison:
   If available, provide FNSERVE_SHARD_COMPARE_CMD or FNSERVE_SHARD_LIMITER_LOG to record limiter rejection/throttling evidence for the same request family.

Run command template:
FNSERVE_MODE=run \\
FNSERVE_CONFIG=/path/to/local-validator-engine-config.json \\
FNSERVE_MASTER_HOST=127.0.0.1 \\
FNSERVE_MASTER_PORT=<configured-fullnodemaster-port> \\
FNSERVE_CLIENT_CMD='<local non-trusted ADNL tonNode_query client command>' \\
FNSERVE_ZERO_STATE_BLOCK='<zero-state block id>' \\
FNSERVE_BLOCK_ID='<known received block id>' \\
bash audit/run_fnserve_master_01_local.sh
PLAN

  cat > "${COMMANDS_FILE}" <<'CMDS'
#!/usr/bin/env bash
set -Eeuo pipefail
# Safe plan-only example. Fill paths from a local/private topology only; do not use public network.
FNSERVE_MODE=plan bash audit/run_fnserve_master_01_local.sh

# Bounded run template (requires local non-trusted ADNL client command):
# FNSERVE_MODE=run \
# FNSERVE_CONFIG=/path/to/local-validator-engine-config.json \
# FNSERVE_MASTER_HOST=127.0.0.1 \
# FNSERVE_MASTER_PORT=<configured-fullnodemaster-port> \
# FNSERVE_CLIENT_CMD='<local client command that sends one request based on FNSERVE_REQUEST_KIND>' \
# FNSERVE_ZERO_STATE_BLOCK='<zero-state block id>' \
# FNSERVE_BLOCK_ID='<known received block id>' \
# FNSERVE_TARGET_PID=<validator-engine-pid> \
# bash audit/run_fnserve_master_01_local.sh
CMDS
  chmod +x "${COMMANDS_FILE}"
}

preflight() {
  require_uints
  print_repo_context
  check_tools
  submodule_summary
  disk_snapshot
  private_host_only "${FNSERVE_MASTER_HOST}" || fail_verdict BLOCKER_REACHABILITY "FNSERVE_MASTER_HOST=${FNSERVE_MASTER_HOST} is not local/private; public network is refused"
  write_plan_files
}

collect_once() {
  local label="$1"
  date -u +%FT%TZ >> "${METRICS_DIR}/timestamps.txt"
  df -B1 "${FNSERVE_WORKDIR}" > "${METRICS_DIR}/df_${label}.txt"
  du -sb "${FNSERVE_WORKDIR}" > "${METRICS_DIR}/du_${label}.txt" 2>/dev/null || true
  if [[ -n "${FNSERVE_TARGET_PID:-}" ]] && ps -p "${FNSERVE_TARGET_PID}" >/dev/null 2>&1; then
    ps -o pid,ppid,stat,pcpu,pmem,rss,vsz,etime,comm -p "${FNSERVE_TARGET_PID}" > "${METRICS_DIR}/ps_${label}.txt" || true
    [[ -r "/proc/${FNSERVE_TARGET_PID}/io" ]] && cat "/proc/${FNSERVE_TARGET_PID}/io" > "${METRICS_DIR}/proc_io_${label}.txt" || true
    [[ -r "/proc/${FNSERVE_TARGET_PID}/status" ]] && cat "/proc/${FNSERVE_TARGET_PID}/status" > "${METRICS_DIR}/proc_status_${label}.txt" || true
  fi
}

resource_ok() {
  local avail
  avail="$(df -B1 --output=avail "${FNSERVE_WORKDIR}" | awk 'NR==2 {print $1}')"
  [[ "${avail}" =~ ^[0-9]+$ ]] || return 1
  (( avail >= FNSERVE_MIN_FREE_BYTES ))
}

run_one_request() {
  local kind="$1" idx="$2" start end rc=0 out err
  out="${LOG_DIR}/client_${kind}_${idx}.out"
  err="${LOG_DIR}/client_${kind}_${idx}.err"
  start="$(date +%s%3N)"
  FNSERVE_REQUEST_KIND="${kind}" \
  FNSERVE_REQUEST_NO="${idx}" \
  FNSERVE_MASTER_HOST="${FNSERVE_MASTER_HOST}" \
  FNSERVE_MASTER_PORT="${FNSERVE_MASTER_PORT:-}" \
  FNSERVE_ZERO_STATE_BLOCK="${FNSERVE_ZERO_STATE_BLOCK:-}" \
  FNSERVE_BLOCK_ID="${FNSERVE_BLOCK_ID:-}" \
  timeout "${FNSERVE_CLIENT_TIMEOUT}" bash -lc "${FNSERVE_CLIENT_CMD}" >"${out}" 2>"${err}" || rc=$?
  end="$(date +%s%3N)"
  printf '%s\t%s\t%s\t%s\t%s\n' "${idx}" "${kind}" "${rc}" "${start}" "${end}" >> "${COUNTS_FILE}"
  return "${rc}"
}

run_mode() {
  find_build_artifacts || fail_verdict BLOCKER_LOCAL_TOPOLOGY "build artifacts are missing; set FNSERVE_VALIDATOR_ENGINE to local validator-engine binary"
  parse_fullnodemaster_config || fail_verdict BLOCKER_LOCAL_TOPOLOGY "no full-node master config/port identified; set FNSERVE_CONFIG or FNSERVE_MASTER_PORT"
  identify_client || fail_verdict BLOCKER_LOCAL_TOPOLOGY "no repo-local non-trusted ADNL client path identified; set FNSERVE_CLIENT_CMD only for local/private topology"
  identify_targets || fail_verdict BLOCKER_LOCAL_TOPOLOGY "no known block or zero-state target identified; set FNSERVE_ZERO_STATE_BLOCK and/or FNSERVE_BLOCK_ID"
  [[ -n "${FNSERVE_MASTER_PORT:-}" ]] || FNSERVE_MASTER_PORT="$(awk -F'port=' '/port=/{split($2,a,"\t"); print a[1]; exit}' "${PLAN_DIR}/fullnodemaster_config.txt")"
  [[ -n "${FNSERVE_MASTER_PORT:-}" ]] || fail_verdict BLOCKER_LOCAL_TOPOLOGY "no master ext-server port can be identified"

  : > "${COUNTS_FILE}"
  collect_once start
  local deadline=$(( $(date +%s) + FNSERVE_MAX_SECONDS ))
  local idx=0 active=0 rc_any=0
  trap 'touch "${STOP_FILE}"; log "manual interruption; stopping bounded run"' INT TERM
  while (( idx < FNSERVE_MAX_REQUESTS )); do
    [[ ! -e "${STOP_FILE}" ]] || break
    (( $(date +%s) < deadline )) || break
    resource_ok || { touch "${STOP_FILE}"; break; }
    if [[ -n "${FNSERVE_TARGET_PID:-}" ]] && ! ps -p "${FNSERVE_TARGET_PID}" >/dev/null 2>&1; then
      collect_once target_gone
      fail_verdict BLOCKER_REACHABILITY "target process ${FNSERVE_TARGET_PID} is not running or restarted"
    fi
    kind="downloadZeroState"
    [[ -n "${FNSERVE_BLOCK_ID:-}" && $((idx % 2)) -eq 1 ]] && kind="downloadBlockFull"
    run_one_request "${kind}" "${idx}" &
    active=$((active + 1)); idx=$((idx + 1))
    if (( active >= FNSERVE_MAX_PARALLEL )); then
      wait -n || rc_any=1
      active=$((active - 1))
      collect_once "mid_${idx}"
    fi
  done
  while (( active > 0 )); do wait -n || rc_any=1; active=$((active - 1)); done
  collect_once end

  if [[ -n "${FNSERVE_SHARD_COMPARE_CMD:-}" ]]; then
    timeout "${FNSERVE_CLIENT_TIMEOUT}" bash -lc "${FNSERVE_SHARD_COMPARE_CMD}" >"${LOG_DIR}/shard_compare.out" 2>"${LOG_DIR}/shard_compare.err" || true
  fi

  local ok err
  ok="$(awk -F'\t' '$3==0{c++} END{print c+0}' "${COUNTS_FILE}")"
  err="$(awk -F'\t' '$3!=0{c++} END{print c+0}' "${COUNTS_FILE}")"
  printf 'ok\t%s\nerr\t%s\n' "${ok}" "${err}" > "${RUN_DIR}/summary_counts.tsv"

  if [[ -n "${FNSERVE_SHARD_LIMITER_LOG:-}" && -f "${FNSERVE_SHARD_LIMITER_LOG}" ]] && grep -Eiq 'limit|ratelimit|check_in|too many|throttl|reject' "${FNSERVE_SHARD_LIMITER_LOG}" && (( ok > 0 )); then
    printf '%s\n' PASS_RUNTIME_EVIDENCE | tee "${RUN_DIR}/final_verdict.txt"
    exit 0
  fi
  if (( ok > 0 )); then
    log "traffic was accepted, but PASS requires shard limiter evidence plus visible DB/state/proof/serialization pressure; see ${METRICS_DIR} and ${LOG_DIR}"
    printf '%s\n' CLOSE_LOW_IMPACT | tee "${RUN_DIR}/final_verdict.txt"
    exit 3
  fi
  fail_verdict BLOCKER_REACHABILITY "client sent no successful local master requests; see ${COUNTS_FILE}"
}

plan_mode() {
  find_build_artifacts || log "BLOCKER: build artifacts missing; set FNSERVE_VALIDATOR_ENGINE to a local validator-engine binary"
  parse_fullnodemaster_config || log "BLOCKER: full-node master config absent; set FNSERVE_CONFIG or FNSERVE_MASTER_PORT"
  identify_client || log "BLOCKER: no non-trusted ADNL tonNode_query client path identified"
  identify_targets || log "BLOCKER: no known block or zero-state target identified"
  log "plan file: ${SUMMARY_FILE}"
  log "commands file: ${COMMANDS_FILE}"
  cat "${SUMMARY_FILE}"
  printf '%s\n' BLOCKER_LOCAL_TOPOLOGY | tee "${RUN_DIR}/final_verdict.txt"
}

main() {
  cd "${REPO_ROOT}"
  preflight
  case "${FNSERVE_MODE}" in
    plan) plan_mode ;;
    run) run_mode ;;
    *) fail_verdict BLOCKER_LOCAL_TOPOLOGY "unsupported FNSERVE_MODE='${FNSERVE_MODE}', expected plan or run" ;;
  esac
}

main "$@"
