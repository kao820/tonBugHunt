# Stage B: исполняемый локальный сценарий с donor/extractor flow

Цель: проверить candidate `DownloadState` accumulation в product-path режиме, где **clean target** сам запускает persistent-state download, а **attacker-only full-node neighbour** отвечает full-size slices без short-read.

Этот файл не является bounty report. Успех засчитывается только если clean target реально прошёл путь `WaitBlockState -> DownloadShardState -> ValidatorManagerImpl::send_get_persistent_state_request() -> FullNodeShardImpl::download_persistent_state() -> DownloadState` и выбрал attacker как `download_from_`.

## Роли checkout'ов

Нужны три checkout'а одного и того же commit:

```text
/workspace/ton-target-clean    # clean target и donor/localnet, attacker patch НЕ применять
/workspace/ton-attacker        # attacker-only checkout, malicious patch применять только здесь
/workspace/ton-seed-tool       # отдельный setup-tool checkout для DB-seed stopped target DB
```

Target checkout нельзя запускать с `TON_POC_MALICIOUS_STATE=1`.

## Attacker-only patch

Patch-файл:

```text
audit/stage_b_malicious_fullnode.patch
```

Он меняет только attacker full-node query handlers в `validator/full-node-shard.cpp`:

- `tonNode_preparePersistentState` -> `tonNode_preparedState`;
- `tonNode_getPersistentStateSizeV2` -> `tonNode_persistentStateSize(TON_POC_MALICIOUS_STATE_SIZE || 1 TiB)`;
- `tonNode_downloadPersistentStateSliceV2` -> `BufferSlice(query.max_size_)` на каждый запрос, без short-read, с логами `slice`, `offset`, `requested`, `returned`, `cumulative_bytes`.

## Что найдено по `PersistentStateDescription`

Нормальная нода создаёт description в `AsyncStateSerializer::store_persistent_state_description()`: берёт masterchain block id, `start_time`, TTL и shard top blocks из masterchain state, затем вызывает `ValidatorManager::add_persistent_state_description()`.

DB хранит description в тех же TL-ключах, которые seed-tool записывает до старта clean target:

- `db_state_key_persistentStateDescriptionsList`;
- `db_state_key_persistentStateDescriptionShards(masterchain_seqno)`;
- `db_state_key_dbVersion = 2`, если state DB свежий.

При старте `StateDb::get_persistent_state_descriptions()` читает эти ключи и наполняет `persistent_state_blocks_`. `ValidatorManagerImpl::get_block_persistent_state_to_download()` использует seeded description только если block не masterchain, block есть в `persistent_state_blocks_`, и выполнено product-path условие:

```text
desc.masterchain_id.seqno() + 16 < min_confirmed_masterchain_seqno_
```

`min_confirmed_masterchain_seqno_` берётся не из seed-tool: clean target обновляет его в `ValidatorManagerImpl::shard_client_update(seqno)` после применения shard-client masterchain block. Поэтому runner сначала продвигает donor/localnet, затем выбирает seed mc block с gap `17`, а target после старта должен сам синхронизироваться до более позднего masterchain seqno.

## Сборка clean target

```bash
cd /workspace/ton-target-clean
git checkout testnet
git rev-parse HEAD | tee /tmp/ton_target_commit.txt
cmake -S . -B build-target -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build-target --target validator-engine dht-server validator-engine-console -j"$(nproc)"
```

## Сборка attacker-only checkout

```bash
cd /workspace/ton-attacker
git checkout testnet
git rev-parse HEAD | tee /tmp/ton_attacker_commit.txt
mkdir -p audit
cp /workspace/ton-target-clean/audit/stage_b_malicious_fullnode.patch audit/stage_b_malicious_fullnode.patch
git apply --check audit/stage_b_malicious_fullnode.patch
git apply audit/stage_b_malicious_fullnode.patch
cmake -S . -B build-attacker -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build-attacker --target validator-engine dht-server validator-engine-console -j"$(nproc)"
```

## Сборка DB-seed setup-tool

DB-seed tool собирается в третьем checkout, чтобы target checkout и target binary оставались clean:

```bash
cd /workspace
git clone /workspace/ton-target-clean ton-seed-tool
cd /workspace/ton-seed-tool
git checkout "$(cat /tmp/ton_target_commit.txt)"
cp /workspace/ton-target-clean/audit/stage_b_seed_tool.patch audit/stage_b_seed_tool.patch
git apply --check audit/stage_b_seed_tool.patch
git apply audit/stage_b_seed_tool.patch
cmake -S . -B build-seed -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build-seed --target seed-persistent-state-description -j"$(nproc)"
```

## Исполняемый donor/extractor/target runner

Перед запуском установите Python-зависимости tontester в clean target checkout:

```bash
cd /workspace/ton-target-clean
python3 -m pip install -e test/tontester
```

Runner:

```text
audit/stage_b_tontester_topology.py
```

Он делает следующее без ручных `BlockIdExt` placeholders:

1. создаёт свежую tontester-сеть в `audit/stage_b_tontester_workdir`;
2. запускает DHT и clean donor validators из `--target-build`;
3. запускает patched attacker full-node из `--attacker-build` с `TON_POC_MALICIOUS_STATE=1`;
4. ждёт donor masterchain `--donor-mc-seqno 24`;
5. ждёт, пока attacker sync'нется до этого же seqno;
6. через donor tonlib получает реальный masterchain block `seqno = min_confirmed - 17`;
7. через `blocks.getShards` выбирает реальный shard/basechain block из этого masterchain block;
8. проверяет gate `mc_seqno + 16 < min_confirmed`;
9. записывает готовые строки в `stage_b_seed_blocks.env`;
10. останавливает honest donor validators, оставляя attacker reachable;
11. запускает seed-tool на stopped target DB;
12. запускает clean target;
13. собирает target RSS раз в секунду в `target_rss.log`;
14. сохраняет target log, attacker log, seed log и `stage_b_summary.txt`;
15. печатает `PASS_CANDIDATE`, если одновременно видит persistent-state download и malicious slice logs, иначе печатает `BLOCKER`.

Команда запуска без `<...>` placeholders:

```bash
cd /workspace/ton-target-clean
python3 audit/stage_b_tontester_topology.py \
  --target-build /workspace/ton-target-clean/build-target \
  --target-source /workspace/ton-target-clean \
  --attacker-build /workspace/ton-attacker/build-attacker \
  --attacker-source /workspace/ton-attacker \
  --seed-tool /workspace/ton-seed-tool/build-seed/validator/seed-persistent-state-description \
  --auto-prepare-seed \
  --donor-validator-count 2 \
  --donor-mc-seqno 24 \
  --seed-confirmation-gap 17 \
  --workdir /workspace/ton-target-clean/audit/stage_b_tontester_workdir \
  --runtime-seconds 300
```

## Как гарантируется, что BlockIdExt реальные

Runner не принимает вымышленные ids в основном режиме. При `--auto-prepare-seed` он получает:

- `mc_block` через tonlib `lookup_block(workchain=-1, shard=-9223372036854775808, seqno=min_confirmed-17)`;
- `shard_block` через tonlib `get_shards(mc_block)` и выбирает workchain `0`, если он есть;
- обе строки сериализуются в C++ формат `(<workchain>,<shard_hex>,<seqno>):<root_hash_hex>:<file_hash_hex>`, который принимает `ton::BlockIdExt::from_str()`.

Готовые значения сохраняются автоматически:

```text
audit/stage_b_tontester_workdir/stage_b_seed_blocks.env
```

Файл имеет вид:

```text
STAGE_B_MC_BLOCK=(...real donor block...)
STAGE_B_SHARD_BLOCK=(...real donor shard block...)
STAGE_B_SEED_MC_SEQNO=...
STAGE_B_MIN_CONFIRMED_MC_SEQNO=...
```

Это нужно для воспроизводимости и проверки, но пользователю не надо вручную подставлять эти значения.

## Как гарантировать, что shard/basechain block известен target, но state отсутствует

Runner создаёт target node directory заранее, но не запускает target до seed step. Поэтому:

- выбранный `shard_block` реален и известен сети, потому что получен из donor masterchain через tonlib;
- attacker уже sync'нулся до donor mc seqno и остаётся reachable после остановки donors;
- clean target при старте синхронизируется по обычной сети от attacker;
- target state DB содержит только seeded `PersistentStateDescription`, но не содержит downloaded persistent state/cells для выбранного shard block, потому что target ещё не запускался до seed;
- дополнительных state files удалять в основном auto-flow не надо.

Если используется не основной auto-flow, а повторный запуск с уже стартовавшим target DB, нужно начинать с нового `--workdir` или удалить весь старый workdir. Не надо вручную удалять случайные `.boc`: это легко превратить в local DB corruption. Основной runner сам удаляет workdir, если не указан `--keep-workdir`.

## Как не дать target скачать state у честных соседей раньше attacker

В controllable localnet нельзя полагаться на Sybil. Runner делает attacker единственным reachable state-serving neighbour на Stage B:

1. donor validators нужны только для подготовки реальных blocks;
2. до старта target runner вызывает `stop()` для donor validators;
3. attacker остаётся запущенным и sync'нутым;
4. target стартует после donor stop;
5. успех засчитывается только если target log показывает `downloading state ... from <attacker_adnl>` и attacker log показывает malicious slices.

## Как проверить malicious ADNL и download_from

Runner печатает и пишет в `stage_b_summary.txt`:

```text
donor_adnls=[...]
target_adnl=<hex>
attacker_adnl=<hex>
seed_mc_block=(...)
seed_shard_block=(...)
```

Успех в target log:

```text
downloading state <block_id> (...) from <attacker_adnl_or_short_id>
```

Успех в attacker log:

```text
TON_POC_MALICIOUS_STATE preparePersistentState ... -> preparedState
TON_POC_MALICIOUS_STATE getPersistentStateSizeV2 ... -> declared_size=1099511627776
TON_POC_MALICIOUS_STATE downloadPersistentStateSliceV2 slice=1 ... offset=0 requested=2097152 returned=2097152 cumulative_bytes=2097152
TON_POC_MALICIOUS_STATE downloadPersistentStateSliceV2 slice=2 ... offset=2097152 requested=2097152 returned=2097152 cumulative_bytes=4194304
```

Это доказывает не synthetic-only DB corruption: seed только создаёт нормальное состояние `PersistentStateDescription`, а последующий вход в downloader подтверждается runtime логами clean target и сетевыми ответами attacker.

## Какие DB keys/handles должны существовать для входа в downloader

До старта target в stopped target DB должны существовать:

```text
db_state_key_dbVersion -> db_state_dbVersion(2)
db_state_key_persistentStateDescriptionsList -> header(mc_block,start_time,end_time)
db_state_key_persistentStateDescriptionShards(mc_seqno) -> shard_block list или shard_block/split_depth list
```

После старта clean target должен сам создать/обновить block handles при sync и поднять `min_confirmed_masterchain_seqno_` через shard-client path. Если target не синхронизирует masterchain выше `seed_mc_seqno + 16`, seeded description будет прочитан, но `get_block_persistent_state_to_download()` вернёт null и это `BLOCKER`, а не PASS.

## Какие файлы/логи прислать обратно

После запуска runner пришлите:

```text
audit/stage_b_tontester_workdir/stage_b_summary.txt
audit/stage_b_tontester_workdir/stage_b_seed_blocks.env
audit/stage_b_tontester_workdir/target_rss.log
audit/stage_b_tontester_workdir/seed_persistent_state_description.log
audit/stage_b_tontester_workdir/node*/log
```

## PASS criteria

Stage B PASS только если всё выполнено:

1. target binary clean, без attacker patch и без `TON_POC_MALICIOUS_STATE`;
2. attacker binary patched и только он запущен с `TON_POC_MALICIOUS_STATE=1`;
3. `stage_b_seed_blocks.env` содержит реальные ids, извлечённые из donor tonlib;
4. target log показывает `downloading state ... from <attacker_adnl>`;
5. attacker log показывает repeated `downloadPersistentStateSliceV2`;
6. `returned == requested` для каждого malicious slice;
7. target RSS растёт вместе с `cumulative_bytes`;
8. outcome записан: OOM/restart, severe RSS/swap growth, timeout with retained RSS или clean fail reason.

## FAIL / close as non-Critical

Ветку закрыть как non-Critical/неподтверждённую, если:

1. clean target не удаётся заставить войти в persistent-state download без patch target binary;
2. target не выбирает attacker как `download_from_`;
3. target быстро переключается/abort до meaningful RSS growth;
4. RSS остаётся bounded при repeated full-size slices;
5. нужен DEBUG-only target injection;
6. воспроизведение зависит от public-overlay Sybil assumption;
7. auto extractor не может получить реальные donor BlockIdExt через tonlib;
8. обнаруживается внешний лимит, который caps total retained download memory.

## Почему DB-seed не является patch target-side vulnerability logic

DB-seed tool не меняет target executable и не меняет `DownloadState`, `WaitBlockState`, `DownloadShardState`, `ValidatorManager` или full-node downloader code. Он только заранее записывает в stopped target RocksDB те TL-объекты, которые нормальная нода сохраняет через `StateDb::add_persistent_state_description()` после работы persistent-state serializer. Это reproduction shortcut для труднодостижимого во времени состояния localnet, а не local-environment attack.

Если Stage B проходит только с DB-seed, в TON archive нужно явно отметить, что seed воспроизводит уже нормальное сетевое состояние `PersistentStateDescription`; primary exploit остаётся malicious network peer, который выбран как `download_from_` и отдаёт full-size slices.

## Archive layout при успешном Stage B

```text
ton-state-download-stage-b/
  README.md
  target/
    commit.txt
    build_commands.txt
    run_command.txt
    target_state_poc.log
    target_rss.log
    local_network_config/
  donor_extractor/
    stage_b_seed_blocks.env
    seed_persistent_state_description.log
    stage_b_summary.txt
  attacker/
    commit.txt
    build_commands.txt
    run_command.txt
    stage_b_malicious_fullnode.patch
    attacker_state_poc.log
  analysis/
    rss_plot.csv
    slice_summary.csv
    pass_fail.md
```
