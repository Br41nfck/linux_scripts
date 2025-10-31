AutoTest Linux Framework

`autotest.sh` — единый оркестратор для установки окружения, мониторинга и стресс‑тестов

Репозиторий

```bash
git clone https://git.fs-c.ru/Knedl/linux-scripts
```

Быстрый старт

```bash
chmod +x ./autotest.sh
./autotest.sh install
./autotest.sh setup-cron
./autotest.sh list
```

 Основные команды

- install — установка пакетов, запуск SSH
- monitor-once — одна строка метрик в лог
- monitor-loop <seconds> — периодический мониторинг
- htop-snapshot — HTML‑снимок top+sensors с помощью `aha`
- stress-ram [duration_s] — стресс‑тест RAM (~90% от объёма)
- iostat <device> [interval] — лог iostat для устройства
- gpuburn <duration_s> — запуск `gpu_burn` и лог `nvidia-smi`
- parse-nvidia <log> [xlsx] — парсинг лога `nvidia-smi` в Excel
- setup-cron — регистрация cron‑заданий (каждые 5 минут)
- setup-systemd — регистрация systemd user timers (если доступно), авто‑фолбек на cron
- remove-systemd — удаление systemd user timers
- collect — сбор логов в архив `tar.gz`
- clean — по умолчанию удаляет все логи автотеста (см. ниже)
- rotate — компрессия больших лог‑файлов
- deps-all — установка всех зависимостей
- config-show — показать активную конфигурацию
- doctor — проверка зависимостей и окружения
- report — HTML‑отчёт с краткими итогами и хвостами логов
- list — список встроенных задач и плагинов
- run <task> […] — запуск задачи по имени (встроенной или плагина)
- status, stop, tail — статус, остановка и просмотр логов

Глобальные флаги: `--dry-run`, `--verbose`.

Плагины (автодискавери)

Оркестратор автоматически подхватывает пользовательские сценарии в папке `linux_scripts`:
- Любой исполняемый `*.sh` (кроме `autotest.sh` и файлов в `gpuburn/`) считается плагином
- Имя задачи — имя файла без `.sh` (можно переопределить метаданными)
- Описание берётся из первой строки‑комментария или метаданных

Поддерживаются метаданные (рекомендуется):
```bash
#!/bin/bash
# AUTOTEST_NAME: my-test
# AUTOTEST_DESC: Custom memory throughput benchmark
# ... ваш код ...
```

После сохранения:
```bash
./autotest.sh list
./autotest.sh run my-test --your --args
```

Логи

- Общие логи: `$HOME/AutoTest_Logs/*`
- GPU burn: `$HOME/gpu_burn_logs/*`

Конфигурация (.env)

- Создайте `.env` рядом с `autotest.sh` или используйте `--config PATH`
- Пример смотрите в файле `ENV.EXAMPLE`
- Поддерживаемые переменные:
  - `AUTOTEST_LOG_DIR`, `AUTOTEST_GPU_LOG_DIR`, `AUTOTEST_ARCHIVE_DIR`
  - `AUTOTEST_RETENTION_DAYS`
  - `AUTOTEST_FORMAT_DATE` — формат даты/времени (по умолчанию `%d-%m-%Y %H:%M:%S`)

Европейские форматы дат (примеры для `AUTOTEST_FORMAT_DATE`):

- `%d-%m-%Y %H:%M:%S` → 31-10-2025 14:05:00
- `%d.%m.%Y %H:%M:%S` → 31.10.2025 14:05:00
- `%d/%m/%Y %H:%M:%S` → 31/10/2025 14:05:00

Примечание: символ `:` в именах файлов допустим в Linux, но может быть неудобен при переносе на другие ОС/ФС.

Очистка (clean)

- По умолчанию: удаляет все логи, созданные автотестом и скриптами, сейчас
- Фильтрация: `--only sys|gpu|htop|ram|iostat|all`
- По возрасту: `--older N` — удалять только старше N дней
- Полная очистка явно: `--all`

Примеры

```bash
./autotest.sh iostat nvme0n1 300
./autotest.sh stress-ram 3600
./autotest.sh gpuburn 14400
./autotest.sh tail gpuburn-smi
```

