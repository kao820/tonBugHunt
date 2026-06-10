#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <target_pid> [output_log]" >&2
  exit 2
fi

pid="$1"
out="${2:-target_rss.log}"

if [[ ! -d "/proc/$pid" ]]; then
  echo "target pid $pid is not running" >&2
  exit 1
fi

{
  echo "# unix_ts pid VmRSS_kB VmHWM_kB VmSize_kB"
  while [[ -d "/proc/$pid" ]]; do
    ts="$(date +%s)"
    vmrss="NA"
    vmhwm="NA"
    vmsize="NA"
    [[ -r "/proc/$pid/status" ]] || break
    while read -r key value unit; do
      case "$key" in
        VmRSS:) vmrss="$value" ;;
        VmHWM:) vmhwm="$value" ;;
        VmSize:) vmsize="$value" ;;
      esac
    done < "/proc/$pid/status"
    printf '%s %s %s %s %s\n' "$ts" "$pid" "$vmrss" "$vmhwm" "$vmsize"
    sleep 1
  done
} | tee "$out"
