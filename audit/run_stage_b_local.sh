#!/usr/bin/env bash
# Локальный self-contained Stage B runner для WSL/Linux.
# Скрипт не меняет target-side downloader logic: target checkout остаётся clean,
# attacker patch применяется только к attacker checkout, seed patch — только к seed-tool checkout.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_REPO="${SOURCE_REPO:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BASE_DIR="${BASE_DIR:-$HOME/ton-stage-b-local}"
TARGET_DIR="${TARGET_DIR:-$BASE_DIR/ton-target-clean}"
ATTACKER_DIR="${ATTACKER_DIR:-$BASE_DIR/ton-attacker}"
SEED_DIR="${SEED_DIR:-$BASE_DIR/ton-seed-tool}"
WORKDIR="${WORKDIR:-$BASE_DIR/stage_b_tontester_workdir}"
LOG_DIR="${LOG_DIR:-$BASE_DIR/stage_b_logs}"
JOBS="${JOBS:-$(nproc)}"
BUILD_TYPE="${BUILD_TYPE:-RelWithDebInfo}"
DONOR_VALIDATOR_COUNT="${DONOR_VALIDATOR_COUNT:-2}"
DONOR_MC_SEQNO="${DONOR_MC_SEQNO:-24}"
SEED_CONFIRMATION_GAP="${SEED_CONFIRMATION_GAP:-17}"
RUNTIME_SECONDS="${RUNTIME_SECONDS:-300}"
DECLARED_STATE_SIZE="${DECLARED_STATE_SIZE:-1099511627776}"

TARGET_BUILD_DIR="${TARGET_BUILD_DIR:-$TARGET_DIR/build-target}"
ATTACKER_BUILD_DIR="${ATTACKER_BUILD_DIR:-$ATTACKER_DIR/build-attacker}"
SEED_BUILD_DIR="${SEED_BUILD_DIR:-$SEED_DIR/build-seed}"
TARGET_STAMP="$TARGET_BUILD_DIR/.stage_b_commit"
ATTACKER_STAMP="$ATTACKER_BUILD_DIR/.stage_b_commit"
SEED_STAMP="$SEED_BUILD_DIR/.stage_b_commit"

mkdir -p "$BASE_DIR" "$LOG_DIR"

log() { printf '[stage-b][%s] %s\n' "$(date -Is)" "$*"; }

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ОШИБКА: не найдена команда '$1'. Установите зависимость и повторите запуск." >&2
    exit 2
  fi
}

show_failure_log() {
  local log_file="$1"
  echo "----- failure log: $log_file -----" >&2
  if [[ ! -f "$log_file" ]]; then
    echo "Лог не найден" >&2
    return
  fi
  python3 - "$log_file" <<'PY' >&2
from pathlib import Path
import re
import sys
p = Path(sys.argv[1])
text = p.read_text(errors="replace").splitlines()
for i, line in enumerate(text):
    low = line.lower()
    if "cmake error" in line or "error:" in low or "fatal error" in low or "no such file" in low:
        print("\n".join(text[i:min(len(text), i + 160)]))
        break
else:
    print("\n".join(text[-120:]))
PY
}

run_logged() {
  local log_file="$1"
  shift
  mkdir -p "$(dirname "$log_file")"
  set +e
  (
    date -Is
    "$@"
    rc=$?
    echo "BUILD_EXIT=$rc"
    date -Is
    exit "$rc"
  ) >"$log_file" 2>&1
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    show_failure_log "$log_file"
    exit "$rc"
  fi
}

run_shell_logged() {
  local log_file="$1"
  shift
  mkdir -p "$(dirname "$log_file")"
  set +e
  (
    date -Is
    bash -lc "$*"
    rc=$?
    echo "BUILD_EXIT=$rc"
    date -Is
    exit "$rc"
  ) >"$log_file" 2>&1
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    show_failure_log "$log_file"
    exit "$rc"
  fi
}

ensure_deps() {
  need_cmd git
  need_cmd cmake
  need_cmd python3
  need_cmd perl
  need_cmd clang
  need_cmd clang++
  need_cmd file
  need_cmd aclocal
  need_cmd libtoolize
  need_cmd llvm-nm
  need_cmd rg
}

source_commit() {
  git -C "$SOURCE_REPO" rev-parse HEAD
}

clone_or_update_clean_checkout() {
  local dir="$1"
  local commit="$2"
  local role="$3"
  if [[ ! -d "$dir/.git" ]]; then
    log "Создаю checkout $role: $dir"
    git clone "$SOURCE_REPO" "$dir"
  fi
  if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
    echo "ОШИБКА: checkout $role не clean: $dir" >&2
    git -C "$dir" status --short >&2
    exit 2
  fi
  git -C "$dir" fetch --all --tags --prune >/dev/null 2>&1 || true
  git -C "$dir" checkout -q "$commit"
  git -C "$dir" submodule sync --recursive >/dev/null
  git -C "$dir" submodule update --init --recursive
}

clone_or_update_patchable_checkout() {
  local dir="$1"
  local commit="$2"
  local role="$3"
  if [[ ! -d "$dir/.git" ]]; then
    log "Создаю checkout $role: $dir"
    git clone "$SOURCE_REPO" "$dir"
  fi
  if [[ "$(git -C "$dir" rev-parse HEAD)" != "$commit" ]]; then
    if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
      echo "ОШИБКА: checkout $role изменён и находится не на commit $commit: $dir" >&2
      git -C "$dir" status --short >&2
      exit 2
    fi
    git -C "$dir" fetch --all --tags --prune >/dev/null 2>&1 || true
    git -C "$dir" checkout -q "$commit"
  fi
  git -C "$dir" submodule sync --recursive >/dev/null
  git -C "$dir" submodule update --init --recursive
}

apply_attacker_patch() {
  local patch="$SOURCE_REPO/audit/stage_b_malicious_fullnode.patch"
  if rg -q "TON_POC_MALICIOUS_STATE" "$ATTACKER_DIR/validator/full-node-shard.cpp"; then
    log "Attacker patch уже применён"
    return
  fi
  if [[ -n "$(git -C "$ATTACKER_DIR" status --porcelain)" ]]; then
    echo "ОШИБКА: attacker checkout dirty до применения patch" >&2
    git -C "$ATTACKER_DIR" status --short >&2
    exit 2
  fi
  log "Применяю attacker-only patch"
  git -C "$ATTACKER_DIR" apply --check "$patch" || { echo "ОШИБКА: attacker patch не проходит git apply --check" >&2; exit 2; }
  git -C "$ATTACKER_DIR" apply "$patch"
}

apply_seed_patch() {
  local patch="$SOURCE_REPO/audit/stage_b_seed_tool.patch"
  if [[ -f "$SEED_DIR/validator/utils/seed-persistent-state-description.cpp" ]] && rg -q "seeded PersistentStateDescription" "$SEED_DIR/validator/utils/seed-persistent-state-description.cpp"; then
    log "Seed-tool patch уже применён"
    return
  fi
  if [[ -n "$(git -C "$SEED_DIR" status --porcelain)" ]]; then
    echo "ОШИБКА: seed checkout dirty до применения patch" >&2
    git -C "$SEED_DIR" status --short >&2
    exit 2
  fi
  log "Применяю seed-tool patch"
  git -C "$SEED_DIR" apply --check "$patch" || { echo "ОШИБКА: seed-tool patch не проходит git apply --check" >&2; exit 2; }
  git -C "$SEED_DIR" apply "$patch"
}

built_target_ok() {
  [[ -x "$TARGET_BUILD_DIR/validator-engine/validator-engine" && \
     -x "$TARGET_BUILD_DIR/dht-server/dht-server" && \
     -x "$TARGET_BUILD_DIR/validator-engine-console/validator-engine-console" && \
     -x "$TARGET_BUILD_DIR/crypto/create-state" && \
     -x "$TARGET_BUILD_DIR/utils/generate-random-id" && \
     -f "$TARGET_BUILD_DIR/tonlib/libtonlibjson.so" && \
     -f "$TARGET_STAMP" && "$(cat "$TARGET_STAMP")" == "$COMMIT" ]]
}

built_attacker_ok() {
  [[ -x "$ATTACKER_BUILD_DIR/validator-engine/validator-engine" && \
     -f "$ATTACKER_STAMP" && "$(cat "$ATTACKER_STAMP")" == "$COMMIT" ]]
}

built_seed_ok() {
  [[ -x "$SEED_BUILD_DIR/validator/seed-persistent-state-description" && \
     -f "$SEED_STAMP" && "$(cat "$SEED_STAMP")" == "$COMMIT" ]]
}

build_target() {
  if built_target_ok; then
    log "clean target уже собран: $TARGET_BUILD_DIR"
    return
  fi
  local log_file="$LOG_DIR/target_build.log"
  log "Собираю clean target, лог: $log_file"
  run_shell_logged "$log_file" "cd '$TARGET_DIR' && CC=clang CXX=clang++ cmake -S . -B '$TARGET_BUILD_DIR' -DCMAKE_BUILD_TYPE='$BUILD_TYPE' && cmake --build '$TARGET_BUILD_DIR' --target validator-engine dht-server validator-engine-console create-state generate-random-id tonlibjson -j'$JOBS'"
  echo "$COMMIT" >"$TARGET_STAMP"
}

build_attacker() {
  if built_attacker_ok; then
    log "attacker уже собран: $ATTACKER_BUILD_DIR"
    return
  fi
  local log_file="$LOG_DIR/attacker_build.log"
  log "Собираю attacker, лог: $log_file"
  run_shell_logged "$log_file" "cd '$ATTACKER_DIR' && CC=clang CXX=clang++ cmake -S . -B '$ATTACKER_BUILD_DIR' -DCMAKE_BUILD_TYPE='$BUILD_TYPE' && cmake --build '$ATTACKER_BUILD_DIR' --target validator-engine -j'$JOBS'"
  echo "$COMMIT" >"$ATTACKER_STAMP"
}

build_seed() {
  if built_seed_ok; then
    log "seed-tool уже собран: $SEED_BUILD_DIR"
    return
  fi
  local log_file="$LOG_DIR/seed_build.log"
  log "Собираю seed-tool, лог: $log_file"
  run_shell_logged "$log_file" "cd '$SEED_DIR' && CC=clang CXX=clang++ cmake -S . -B '$SEED_BUILD_DIR' -DCMAKE_BUILD_TYPE='$BUILD_TYPE' && cmake --build '$SEED_BUILD_DIR' --target seed-persistent-state-description -j'$JOBS'"
  echo "$COMMIT" >"$SEED_STAMP"
}

install_tontester() {
  local log_file="$LOG_DIR/pip_tontester.log"
  log "Устанавливаю tontester editable package, лог: $log_file"
  run_shell_logged "$log_file" "cd '$TARGET_DIR' && python3 -m pip install -e test/tontester"
}

run_stage_b() {
  local log_file="$LOG_DIR/stage_b_runner.log"
  log "Запускаю Stage B runner, лог: $log_file"
  set +e
  (
    date -Is
    cd "$TARGET_DIR"
    python3 audit/stage_b_tontester_topology.py \
      --target-build "$TARGET_BUILD_DIR" \
      --target-source "$TARGET_DIR" \
      --attacker-build "$ATTACKER_BUILD_DIR" \
      --attacker-source "$ATTACKER_DIR" \
      --seed-tool "$SEED_BUILD_DIR/validator/seed-persistent-state-description" \
      --auto-prepare-seed \
      --donor-validator-count "$DONOR_VALIDATOR_COUNT" \
      --donor-mc-seqno "$DONOR_MC_SEQNO" \
      --seed-confirmation-gap "$SEED_CONFIRMATION_GAP" \
      --declared-state-size "$DECLARED_STATE_SIZE" \
      --workdir "$WORKDIR" \
      --runtime-seconds "$RUNTIME_SECONDS"
    rc=$?
    echo "RUNNER_EXIT=$rc"
    date -Is
    exit "$rc"
  ) >"$log_file" 2>&1
  local rc=$?
  set -e

  echo "----- Stage B runner tail ($log_file) -----"
  tail -120 "$log_file" || true
  return "$rc"
}

print_final_locations() {
  local summary="$WORKDIR/stage_b_summary.txt"
  local seed_env="$WORKDIR/stage_b_seed_blocks.env"
  local rss="$WORKDIR/target_rss.log"
  echo "----- Итоговые файлы -----"
  echo "stage_b_summary=$summary"
  echo "stage_b_seed_blocks=$seed_env"
  echo "target_rss=$rss"
  echo "node_logs=$WORKDIR/node*/log"
  echo "build_logs=$LOG_DIR"
  if [[ -f "$summary" ]]; then
    echo "----- stage_b_summary.txt -----"
    cat "$summary"
  fi
  if [[ -f "$seed_env" ]]; then
    echo "----- stage_b_seed_blocks.env -----"
    cat "$seed_env"
  fi
}

main() {
  ensure_deps
  COMMIT="$(source_commit)"
  export COMMIT

  log "BASE_DIR=$BASE_DIR"
  log "SOURCE_REPO=$SOURCE_REPO"
  log "COMMIT=$COMMIT"
  log "TARGET_DIR=$TARGET_DIR"
  log "ATTACKER_DIR=$ATTACKER_DIR"
  log "SEED_DIR=$SEED_DIR"
  log "WORKDIR=$WORKDIR"
  log "JOBS=$JOBS"

  clone_or_update_clean_checkout "$TARGET_DIR" "$COMMIT" "target"
  build_target

  clone_or_update_patchable_checkout "$ATTACKER_DIR" "$COMMIT" "attacker"
  apply_attacker_patch
  build_attacker

  clone_or_update_patchable_checkout "$SEED_DIR" "$COMMIT" "seed-tool"
  apply_seed_patch
  build_seed

  install_tontester

  if run_stage_b; then
    echo "PASS_CANDIDATE или успешный runner exit. Проверьте PASS_CANDIDATE/BLOCKER в runner log."
  else
    echo "BLOCKER: Stage B runner завершился ненулевым кодом. Проверьте runner log."
  fi
  print_final_locations
}

main "$@"
