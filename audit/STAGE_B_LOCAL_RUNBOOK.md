# Stage B local runbook для WSL/Linux

Этот документ описывает локальный запуск Stage B PoC для кандидата `persistent-state download accumulation`.
Это **не bounty report**. Report-ready статус возможен только после фактического `PASS_CANDIDATE` с логами clean target, patched attacker и RSS.

## Что запускает пользователь

Из корня checkout с audit-артефактами запустите один главный скрипт:

```bash
chmod +x audit/run_stage_b_local.sh
BASE_DIR="$HOME/ton-stage-b-local" \
SOURCE_REPO="$(pwd)" \
JOBS="$(nproc)" \
audit/run_stage_b_local.sh
```

Скрипт создаёт отдельные checkout'ы и workdir под `BASE_DIR`:

```text
$BASE_DIR/ton-target-clean          # clean target, без attacker patch
$BASE_DIR/ton-attacker              # attacker-only checkout с malicious patch
$BASE_DIR/ton-seed-tool             # отдельный seed-tool checkout с DB-seed patch
$BASE_DIR/stage_b_tontester_workdir # runtime логи tontester/localnet
$BASE_DIR/stage_b_logs              # build/runner логи
```

Можно переопределить переменные:

```bash
BASE_DIR="$HOME/ton-stage-b-local" \
SOURCE_REPO="$HOME/src/ton-testnet-audit" \
TARGET_DIR="$HOME/ton-stage-b-local/ton-target-clean" \
ATTACKER_DIR="$HOME/ton-stage-b-local/ton-attacker" \
SEED_DIR="$HOME/ton-stage-b-local/ton-seed-tool" \
WORKDIR="$HOME/ton-stage-b-local/stage_b_tontester_workdir" \
JOBS="8" \
RUNTIME_SECONDS="300" \
DONOR_MC_SEQNO="24" \
SEED_CONFIRMATION_GAP="17" \
audit/run_stage_b_local.sh
```

Если вы продолжаете уже начатый прогон после обновления только audit-скриптов/patch-файлов, зафиксируйте исходный commit Stage B через `STAGE_B_COMMIT`. Это не даёт скрипту пересобирать clean target и attacker на новом audit-only commit:

```bash
BASE_DIR="$HOME/ton-stage-b-local" \
SOURCE_REPO="$HOME/src/ton-testnet-audit" \
STAGE_B_COMMIT="41257a4d1c28c983ce81bf8e02aa8bdb4fa3ba71" \
JOBS="1" \
audit/run_stage_b_local.sh
```

Скрипт resumable:

- если clean target уже собран на том же commit (`SOURCE_REPO` HEAD или `STAGE_B_COMMIT`) — target не пересобирается;
- если attacker уже patched и собран на том же commit (`SOURCE_REPO` HEAD или `STAGE_B_COMMIT`) — attacker не пересобирается;
- если seed-tool уже собран на том же commit (`SOURCE_REPO` HEAD или `STAGE_B_COMMIT`) — seed-tool не пересобирается;
- каждый build пишет отдельный лог и строку `BUILD_EXIT=<код>`;
- при ошибке скрипт печатает лог начиная с первой строки `error:` / `CMake Error`; если таких строк нет — последние 120 строк.

## Минимальные зависимости Ubuntu/WSL

Рекомендуемый набор пакетов:

```bash
sudo apt-get update
sudo apt-get install -y \
  git cmake clang lld llvm \
  build-essential ccache pkg-config \
  automake autoconf libtool file \
  perl python3 python3-pip python3-venv \
  zlib1g-dev liblz4-dev libzstd-dev
```

Проверки перед запуском:

```bash
clang --version
cmake --version
perl --version
python3 --version
git --version
llvm-nm --version
aclocal --version
libtoolize --version
file --version
```

Если `llvm-nm` не находится, установите `llvm` или добавьте каталог LLVM binaries в `PATH`.

## Что делает скрипт

`audit/run_stage_b_local.sh` выполняет только build/setup и Stage B run:

1. определяет commit `SOURCE_REPO` или использует `STAGE_B_COMMIT`, если он явно задан;
2. создаёт/обновляет clean target checkout на этом commit;
3. инициализирует submodules;
4. собирает clean target через `CC=clang CXX=clang++`;
5. создаёт attacker checkout на том же commit;
6. применяет `audit/stage_b_malicious_fullnode.patch` только в attacker checkout;
7. собирает attacker `validator-engine`;
8. создаёт seed-tool checkout на том же commit;
9. применяет `audit/stage_b_seed_tool.patch` только в seed checkout;
10. собирает `seed-persistent-state-description`;
11. выполняет `python3 -m pip install -e test/tontester` в clean target checkout;
12. запускает `audit/stage_b_tontester_topology.py` с `--auto-prepare-seed`;
13. сохраняет build logs и runtime logs.

## Как проверить, что target clean

Target checkout должен быть без attacker/seed patches:

```bash
git -C "$BASE_DIR/ton-target-clean" status --short
git -C "$BASE_DIR/ton-target-clean" diff -- validator/full-node-shard.cpp validator/CMakeLists.txt validator/utils/seed-persistent-state-description.cpp
! rg -n 'TON_POC_MALICIOUS_STATE|seed-persistent-state-description' "$BASE_DIR/ton-target-clean/validator"
```

Ожидаемо:

- `status --short` пустой;
- `git diff` пустой;
- `rg` не находит malicious/seed markers в target checkout.

## Как проверить, что attacker patched

```bash
rg -n 'TON_POC_MALICIOUS_STATE|downloadPersistentStateSliceV2' "$BASE_DIR/ton-attacker/validator/full-node-shard.cpp"
git -C "$BASE_DIR/ton-attacker" diff -- validator/full-node-shard.cpp | sed -n '1,160p'
```

Ожидаемо:

- markers `TON_POC_MALICIOUS_STATE` есть только в attacker checkout;
- patch затрагивает attacker `validator/full-node-shard.cpp`;
- target checkout остаётся clean.

## Как проверить, что seed-tool patch только в seed checkout

```bash
test -x "$BASE_DIR/ton-seed-tool/build-seed/validator/seed-persistent-state-description"
rg -n 'seed-persistent-state-description|seeded PersistentStateDescription' "$BASE_DIR/ton-seed-tool/validator"
! test -e "$BASE_DIR/ton-target-clean/validator/utils/seed-persistent-state-description.cpp"
```

## Какие файлы прислать обратно

После завершения скрипта пришлите:

```text
$BASE_DIR/stage_b_logs/target_build.log
$BASE_DIR/stage_b_logs/attacker_build.log
$BASE_DIR/stage_b_logs/seed_build.log
$BASE_DIR/stage_b_logs/pip_tontester.log
$BASE_DIR/stage_b_logs/stage_b_runner.log
$BASE_DIR/stage_b_tontester_workdir/stage_b_summary.txt
$BASE_DIR/stage_b_tontester_workdir/stage_b_seed_blocks.env
$BASE_DIR/stage_b_tontester_workdir/target_rss.log
$BASE_DIR/stage_b_tontester_workdir/node*/log
```

Если runner завершился `BLOCKER`, эти файлы всё равно нужны для определения точного следующего шага.

## PASS criteria

Stage B считается `PASS_CANDIDATE` только если одновременно выполнено:

1. target binary clean, без attacker patch и без `TON_POC_MALICIOUS_STATE`;
2. attacker binary patched и только он запущен с `TON_POC_MALICIOUS_STATE=1`;
3. `stage_b_seed_blocks.env` содержит реальные ids, извлечённые из donor tonlib;
4. target log показывает `downloading state ... from <attacker_adnl>`;
5. attacker log показывает repeated `downloadPersistentStateSliceV2`;
6. для каждого malicious slice `returned == requested`;
7. `target_rss.log` показывает рост RSS вместе с `cumulative_bytes`;
8. outcome записан: OOM/restart, severe RSS/swap growth, timeout with retained RSS или clean fail reason.

## BLOCKER criteria

Это `BLOCKER`/неподтверждённый кандидат, если:

1. clean target не входит в persistent-state download без patch target binary;
2. target не выбирает attacker как `download_from_`;
3. target быстро переключается/abort до meaningful RSS growth;
4. RSS остаётся bounded при repeated full-size slices;
5. нужен DEBUG-only target injection;
6. воспроизведение зависит от public-overlay Sybil assumption;
7. auto extractor не может получить реальные donor `BlockIdExt` через tonlib;
8. найден внешний лимит, который ограничивает retained download memory.

## Почему это ещё не bounty report

Пакет и runbook только запускают проверку. До фактического `PASS_CANDIDATE` нельзя утверждать Critical-impact:

- Stage A показывает retention semantics, но не product-path exploit;
- Stage B должен доказать clean target runtime path и malicious full-node source;
- нужны target logs, attacker logs и RSS metrics;
- без этих файлов это остаётся PoC setup, а не validated bounty report.
