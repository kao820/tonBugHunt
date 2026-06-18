#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FNSERVE_BUILD_DIR="${FNSERVE_BUILD_DIR:-$HOME/ton-fnserve-master-01-build}"
FNSERVE_BUILD_JOBS="${FNSERVE_BUILD_JOBS:-2}"
FNSERVE_C_COMPILER="${FNSERVE_C_COMPILER:-clang}"
FNSERVE_CXX_COMPILER="${FNSERVE_CXX_COMPILER:-clang++}"
LOG_DIR="${FNSERVE_BUILD_DIR}/audit-logs"
TARGETS=(validator-engine validator-engine-console create-state fift lite-client dht-server generate-random-id tonlibjson)

mkdir -p "${FNSERVE_BUILD_DIR}" "${LOG_DIR}"

fail() {
  printf 'FORMAT FNSERVE_TOPOLOGY_BLOCKED\n'
  printf 'exact reason: %s\n' "$1"
  printf 'blocker class: %s\n' "$2"
  printf 'exact missing repo capability: matching current-worktree binaries required by test/tontester\n'
  printf 'whether this parks or closes FNSERVE-MASTER-01: parked / not closed / not report-ready\n'
  exit 2
}

command -v cmake >/dev/null || fail "cmake missing" "A) missing dependency/toolchain"
command -v ninja >/dev/null || fail "ninja missing" "A) missing dependency/toolchain"
command -v autoreconf >/dev/null || fail "autoreconf missing (install autoconf)" "A) missing dependency/toolchain"
command -v aclocal >/dev/null || fail "aclocal missing (install automake)" "A) missing dependency/toolchain"
command -v libtoolize >/dev/null || fail "libtoolize missing (install libtool)" "A) missing dependency/toolchain"
command -v "${FNSERVE_C_COMPILER}" >/dev/null || fail "${FNSERVE_C_COMPILER} missing" "A) missing dependency/toolchain"
command -v "${FNSERVE_CXX_COMPILER}" >/dev/null || fail "${FNSERVE_CXX_COMPILER} missing" "A) missing dependency/toolchain"
python3 - <<'PY' || fail "test/tontester requires Python >=3.14" "B) unsupported compiler/Python version"
import sys
raise SystemExit(0 if sys.version_info >= (3, 14) else 1)
PY

if git -C "${REPO_ROOT}" submodule status | grep -Eq '^-|^\+'; then
  fail "submodules are missing or not at the recorded commits; initialize them before this offline build" "A) missing dependency/toolchain"
fi

if [[ -f "${FNSERVE_BUILD_DIR}/CMakeCache.txt" ]]; then
  cached_root="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "${FNSERVE_BUILD_DIR}/CMakeCache.txt")"
  [[ "${cached_root}" == "${REPO_ROOT}" ]] ||
    fail "build directory belongs to a different source tree: ${cached_root}" "D) topology harness bug"
fi

cmake -S "${REPO_ROOT}" -B "${FNSERVE_BUILD_DIR}" -G Ninja \
  -DCMAKE_C_COMPILER="${FNSERVE_C_COMPILER}" \
  -DCMAKE_CXX_COMPILER="${FNSERVE_CXX_COMPILER}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DTON_USE_JEMALLOC=OFF \
  2>&1 | tee "${LOG_DIR}/configure.log"

cmake --build "${FNSERVE_BUILD_DIR}" --parallel "${FNSERVE_BUILD_JOBS}" --target "${TARGETS[@]}" \
  2>&1 | tee "${LOG_DIR}/build.log"

required=(
  validator-engine/validator-engine
  validator-engine-console/validator-engine-console
  crypto/create-state
  crypto/fift
  lite-client/lite-client
  dht-server/dht-server
  utils/generate-random-id
)
for rel in "${required[@]}"; do
  [[ -x "${FNSERVE_BUILD_DIR}/${rel}" ]] || fail "missing built artifact ${FNSERVE_BUILD_DIR}/${rel}" "C) product code compile failure"
done
if [[ ! -f "${FNSERVE_BUILD_DIR}/tonlib/libtonlibjson.so" && ! -f "${FNSERVE_BUILD_DIR}/tonlib/libtonlibjson.dylib" ]]; then
  fail "missing built tonlib shared library" "C) product code compile failure"
fi

printf 'FORMAT FNSERVE_TOPOLOGY_READY\n'
printf 'matching_build_dir=%s\n' "${FNSERVE_BUILD_DIR}"
printf 'matching_commit=%s\n' "$(git -C "${REPO_ROOT}" rev-parse HEAD)"
printf 'built_targets=%s\n' "${TARGETS[*]}"
