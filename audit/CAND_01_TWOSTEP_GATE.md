# CAND-01 static gate — private-overlay twostep FEC incomplete-broadcast state

Дата: 2026-06-12.

Статус: **статически подтверждён как product-path-reachable candidate, но не report-ready**. Impact пока **unclear**: нужно измерить, создаёт ли clean target много receiver state и растёт ли RSS/CPU до GC.

## Baseline / cleanup

- `git status --short` перед изменениями был пустым: unexpected dirty state не обнаружен.
- `git log --oneline -3` показывал последний audit cleanup/triage commit `900bc243 audit: add NEXT_CANDIDATES.md with triage and follow-up candidates`.
- Persistent-state ветка остаётся закрытой; к ней не возвращаемся.

## Ответы на gate-вопросы

### 1. Где включается twostep для validator/private overlay

- Consensus private overlay создаёт `OverlayOptions`, выставляет `twostep_broadcast_sender_ = adnl_sender_`, `send_twostep_broadcast_ = true`, `allow_old_broadcasts_ = false`, затем вызывает `create_private_overlay_ex` с authorized validator keys.
- Block-sync overlay использует тот же pattern: `twostep_broadcast_sender_ = adnl_sender_`, `send_twostep_broadcast_ = true`, `allow_old_broadcasts_ = false`.
- `OverlayImpl` принимает twostep FEC только если `opts_.twostep_broadcast_sender_` не пустой; иначе возвращает `twostep broadcasts are not enabled`.

### 2. Какие параметры лимитеров реально передаются

- `OverlayOptions` содержит default `{}` для `auth_broadcast_rate_limit_`, `auth_broadcast_size_rate_limit_`, `unauth_broadcast_rate_limit_`, `unauth_broadcast_size_rate_limit_`.
- В inspected consensus/block-sync private overlay options эти лимитеры не переопределяются.
- Для authorized source `OverlayImpl::get_broadcasts_limiter()` инициализирует `RateLimiterWindow` из `opts_.auth_broadcast_rate_limit_` и `opts_.auth_broadcast_size_rate_limit_`.

### 3. Правда ли, что default/zero duration limiter effectively disabled

Да, для `RateLimiterWindow` при `duration_ == 0` метод `check()` сразу возвращает `true`, а `insert()` при `duration_ == 0` сразу возвращает без записи. Поэтому default `{duration=0, limit=0}` не ограничивает broadcast count/size.

### 4. Где создаётся state на уникальный `broadcast_id`

В `BroadcastsTwostep::process_broadcast(... overlay_broadcastTwostepFec ...)`:

1. `broadcast_id` считается из flags/date/source ADNL/data_hash/data_size/part_size/extra.
2. Duplicate check идёт через `overlay->is_delivered(broadcast_id)` и `broadcasts_.find(broadcast_id)`.
3. Для нового `broadcast_id` вызывается `try_register_broadcast(data_size)`.
4. Создаётся `td::raptorq::Decoder`.
5. Создаётся `BroadcastTwostep` с decoder/debug state.
6. Объект кладётся в `lru_` и `broadcasts_`.
7. Лог: `twostep START receiver ...`.

### 5. Есть ли count cap на `broadcasts_` / `lru_`

Явного count cap для `BroadcastsTwostep::broadcasts_` не найден. `BroadcastsTwostep::gc()` удаляет entries только по age: если `bcast->date > now - 25`, цикл прекращается; иначе incomplete entry логируется как `twostep GC_INCOMPLETE`, стирается из `broadcasts_` и регистрируется как delivered.

Контраст: legacy simple broadcasts имеют `MAX_BCASTS = 100`, но twostep FEC такого count cap не имеет.

### 6. Минимальный attacker-controlled input

Чтобы пройти product path, attacker должен быть Byzantine validator/private-overlay member и иметь валидный ключ/сертификат для source:

- overlay id текущего consensus/block-sync private overlay;
- member/source key, которым можно подписать `overlay_broadcastTwostepFec_toSign`;
- `src_adnl_id` участника overlay;
- `date` в допустимом окне;
- уникальные `data_hash`/`extra`/`date` или другие поля, влияющие на `broadcast_id`;
- `data_size` и `part` с `0 < part_size < data_size`;
- `seqno < overlay->persistent_node_count()`;
- корректная signature на `(broadcast_id, seqno, part)`.

### 7. Может ли один Byzantine validator достичь path без public-overlay Sybil

Статически: **да, reachability выглядит plausible** для Byzantine validator / private-overlay member, потому что:

- consensus и block-sync overlays являются private overlays с authorized validator keys;
- twostep включён именно для этих overlays;
- входной обработчик twostep FEC не требует public-overlay Sybil, а требует valid source/certificate/signature;
- один member может генерировать много уникальных `broadcast_id`, если rate/size limiter действительно default-disabled.

Но это ещё не vulnerability report: нужно runtime gate, доказывающий accepted state allocation и measurable RSS/CPU impact.

## Минимальный gate без большого harness

### Attacker-only действие

Сделать маленький attacker-only patch/tool в одном Byzantine validator checkout, который после создания private overlay отправляет серию валидных `overlay_broadcastTwostepFec`:

- N уникальных `broadcast_id` через уникальный `data_hash` и/или `extra`;
- одинаковый допустимый `seqno=0`, если он меньше `persistent_node_count()`;
- `part_size` минимальный допустимый, но `part_size < data_size`;
- `data_size` близко к max authorized broadcast size overlay, но начать с безопасных малых значений для gate;
- корректная signature тем же keyring path, который используется обычным twostep sender.

### Clean target

Target не патчить для прохождения gate. Достаточно включить verbose logs, где уже есть:

- `twostep START receiver ...`;
- `twostep RECV_CHUNK receiver ...`;
- `twostep GC_INCOMPLETE receiver ...`.

### Метрики

- count `twostep START receiver` за 25 секунд;
- count `twostep GC_INCOMPLETE`;
- RSS target раз в секунду из `/proc/<pid>/status`;
- CPU target процесса;
- наличие/отсутствие limiter rejection и duplicate rejection.

### PASS gate

- Clean target принимает много уникальных FEC broadcasts от attacker member.
- В target log есть серия `twostep START receiver` с разными `broadcast_id`.
- `broadcasts_` state живёт до age-based GC, видны `GC_INCOMPLETE`.
- RSS/CPU растут существенно до GC.
- Нет раннего `Broadcast rate limit ... exceeded`, duplicate rejection или authorization failure.

### BLOCKER gate

- Signature/certificate/authorization не проходит.
- `precheck_new_broadcast()` / `try_register_broadcast()` реально ограничивает поток.
- Duplicate/delivered cache отсекает сообщения до `Decoder::create`.
- `Decoder::create` почти ничего не аллоцирует, RSS/CPU impact слабый.
- Достижимость есть только в non-validator-relevant overlay.

## Допустимый instrumentation patch, если логов не хватит

Только логирование/counters, без изменения поведения target:

- в ветке `if (it == broadcasts_.end())` перед/после `broadcasts_.emplace` логировать `broadcast_id`, `broadcasts_.size()`, `data_size`, `part_size`, `symbols_needed`, `src_peer_id`;
- в `gc()` логировать число удалённых incomplete entries за вызов;
- не менять limiter, duplicate logic, decoder, `broadcasts_`, `lru_` или delivery logic.

Если нужен строгий clean-target gate, instrumentation лучше сначала применять только в отдельном observer build для подтверждения counters, затем повторить acceptance gate на clean target по существующим logs/RSS.

## Следующий конкретный шаг

Открыть реализацию sender-side twostep signing path и выбрать минимальное место для attacker-only trigger:

```bash
sed -n '130,270p' overlay/broadcast-twostep.cpp
sed -n '520,556p' overlay/overlay.cpp
sed -n '54,76p' validator/consensus/private-overlay.cpp
sed -n '49,65p' validator/consensus/block-sync-overlay.cpp
```

Цель следующего шага: найти самый короткий attacker-only path, который переиспользует существующий keyring/signing и `Overlays::send_message_via`/twostep serialization, а не вручную ломает target или local DB.
