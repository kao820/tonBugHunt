#!/usr/bin/env bash
# Safe local PoC skeleton for CN-ARCHIVE-01.
#
# This script intentionally does NOT build TON, install dependencies, execute a
# proof-of-concept, start validator/full-node processes, or contact any network.
# It prepares a bounded local run directory, records environment/submodule
# preflight information, and prints the exact evidence that a topology-specific
# runtime must collect before any PASS claim can be made.

set -euo pipefail

CANDIDATE_ID="CN-ARCHIVE-01"
CN_ARCHIVE_WORKDIR="${CN_ARCHIVE_WORKDIR:-$HOME/ton-cn-archive-01-local}"
CN_ARCHIVE_MAX_BYTES="${CN_ARCHIVE_MAX_BYTES:-268435456}"
CN_ARCHIVE_MAX_SECONDS="${CN_ARCHIVE_MAX_SECONDS:-180}"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*"
}

need_tool() {
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'tool %-8s OK: %s\n' "$tool" "$(command -v "$tool")"
  else
    printf 'tool %-8s MISSING\n' "$tool"
    return 1
  fi
}

is_uint() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git work tree: $REPO_ROOT"

BRANCH="$(git branch --show-current 2>/dev/null || true)"
COMMIT="$(git rev-parse --verify HEAD 2>/dev/null || true)"

note "Candidate: $CANDIDATE_ID"
note "Repository root: $REPO_ROOT"
note "Branch: ${BRANCH:-DETACHED}"
note "Commit: ${COMMIT:-UNKNOWN}"
note "Workdir: $CN_ARCHIVE_WORKDIR"
note "CN_ARCHIVE_MAX_BYTES: $CN_ARCHIVE_MAX_BYTES"
note "CN_ARCHIVE_MAX_SECONDS: $CN_ARCHIVE_MAX_SECONDS"

is_uint "$CN_ARCHIVE_MAX_BYTES" || fail "CN_ARCHIVE_MAX_BYTES must be an unsigned integer"
is_uint "$CN_ARCHIVE_MAX_SECONDS" || fail "CN_ARCHIVE_MAX_SECONDS must be an unsigned integer"
[ "$CN_ARCHIVE_MAX_BYTES" -gt 0 ] || fail "CN_ARCHIVE_MAX_BYTES must be greater than zero"
[ "$CN_ARCHIVE_MAX_SECONDS" -gt 0 ] || fail "CN_ARCHIVE_MAX_SECONDS must be greater than zero"

note ""
note "Checking required local tools (no install attempted):"
missing_tools=0
for tool in git cmake ninja clang python3; do
  need_tool "$tool" || missing_tools=1
done
[ "$missing_tools" -eq 0 ] || fail "one or more required tools are missing"

note ""
note "Checking submodules:"
if [ ! -f .gitmodules ]; then
  fail ".gitmodules is missing; cannot verify third-party submodules"
fi

git submodule status --recursive > /tmp/cn_archive_submodules.$$ || fail "git submodule status failed"
cat /tmp/cn_archive_submodules.$$
if grep -qE '^[-+]' /tmp/cn_archive_submodules.$$; then
  rm -f /tmp/cn_archive_submodules.$$
  fail "submodules are missing, uninitialized, or not at recorded commits"
fi
rm -f /tmp/cn_archive_submodules.$$

if [ ! -d third-party/openssl ]; then
  fail "required submodule third-party/openssl is missing"
fi
if [ -z "$(find third-party/openssl -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
  fail "required submodule third-party/openssl is empty or uninitialized"
fi
note "third-party/openssl present"

note ""
note "Preparing bounded local evidence directories:"
mkdir -p -- "$CN_ARCHIVE_WORKDIR/logs" "$CN_ARCHIVE_WORKDIR/metrics"
[ -d "$CN_ARCHIVE_WORKDIR/logs" ] || fail "logs directory was not created"
[ -d "$CN_ARCHIVE_WORKDIR/metrics" ] || fail "metrics directory was not created"
note "created/verified: $CN_ARCHIVE_WORKDIR/logs"
note "created/verified: $CN_ARCHIVE_WORKDIR/metrics"

METRICS_FILE="$CN_ARCHIVE_WORKDIR/metrics/preflight_$(date -u +%Y%m%dT%H%M%SZ).txt"
{
  printf 'candidate=%s\n' "$CANDIDATE_ID"
  printf 'repo_root=%s\n' "$REPO_ROOT"
  printf 'branch=%s\n' "${BRANCH:-DETACHED}"
  printf 'commit=%s\n' "${COMMIT:-UNKNOWN}"
  printf 'workdir=%s\n' "$CN_ARCHIVE_WORKDIR"
  printf 'max_bytes=%s\n' "$CN_ARCHIVE_MAX_BYTES"
  printf 'max_seconds=%s\n' "$CN_ARCHIVE_MAX_SECONDS"
  printf '\n# df before topology-specific runtime\n'
  df -h "$CN_ARCHIVE_WORKDIR"
  printf '\n# du before topology-specific runtime\n'
  du -sh "$CN_ARCHIVE_WORKDIR" 2>/dev/null || true
} > "$METRICS_FILE"
note "wrote preflight metrics: $METRICS_FILE"

note ""
note "Safety policy:"
note "- This skeleton never writes archive payloads and never intentionally fills the real disk."
note "- Runtime evidence collection must enforce CN_ARCHIVE_MAX_BYTES=$CN_ARCHIVE_MAX_BYTES and CN_ARCHIVE_MAX_SECONDS=$CN_ARCHIVE_MAX_SECONDS."
note "- Runtime should use an isolated filesystem, quota, sparse throwaway image, tmpfs, or disposable VM/disk."
note "- This script never runs git clean."
note "- This script never prints or records PASS; PASS is reserved for real bounded runtime evidence."

cat <<'TODO'

TODO: topology-specific target command placeholder (NOT EXECUTED)
  # Start an instrumented local TON target node/import path in an isolated workdir.
  # Capture logs containing: "Importing archive from net".
  # Capture du/df metrics for db_root/tmp at a fixed interval.

TODO: topology-specific attacker command placeholder (NOT EXECUTED)
  # Start a controlled malicious full-node neighbour that serves archive slices.
  # Capture logs containing: "downloading archive slice from attacker".
  # Bound output by CN_ARCHIVE_MAX_BYTES and stop by CN_ARCHIVE_MAX_SECONDS.

Required PASS evidence (do not claim PASS without all of this):
  1. Target log line showing: Importing archive from net
  2. Attacker/target log line showing: downloading archive slice from attacker
  3. Metrics proving repeated full-size slices were requested or written
  4. du/df time series proving db_root/tmp grows during repeated slices

Expected BLOCKER/CLOSE evidence:
  - Submodules/tooling missing before runtime can start
  - No path from malicious full-node neighbour to DownloadArchiveSlice
  - Target rejects/limits slices before temp-file growth
  - db_root/tmp remains bounded under CN_ARCHIVE_MAX_BYTES/CN_ARCHIVE_MAX_SECONDS
TODO

note ""
note "Preflight complete. Runtime not executed; no PASS claimed."
exit 0
