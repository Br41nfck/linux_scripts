AutoTest Linux Framework

Универсальный оркестратор для установки окружения, мониторинга и стресс‑тестов аппаратных ресурсов на Linux. Содержит CLI (`autotest.sh`) и GUI (`autotest_gui.py`).

## Репозиторий

```bash
git clone https://github.com/Br41nfck/linux_scripts
cd linux-scripts
```

## Возможности

- Мониторинг: CPU/GPU/RAM/сеть/NVMe SMART, HTML-снимки top+sensors
- Стресс‑тесты: CPU (stress‑ng), GPU (gpu-burn), RAM (memtester/stress‑ng), диск (fio), сеть (iperf3)
- Преднастроенные задачи (presets): 4h / 8h / 24h / 48h / gpu_only / cpu_only
- Планировщик: systemd timers (fallback на cron)
- Отчёты: единый HTML-отчёт, сбор/архивация/ротация/очистка логов
- Автоустранение зависимостей (deps-all), проверка окружения (doctor)
- GUI на Tkinter с переключением языка (RU/EN)

## Требования

- Linux с bash
- Права на установку пакетов (`sudo apt` для Debian/Ubuntu)
- Для GUI: Python 3 + Tkinter (`python3-tk`)

## Быстрый старт (CLI)

```bash
chmod +x ./autotest.sh
./autotest.sh install            # установка базовых пакетов (ssh, htop, и т.п.)
./autotest.sh deps-all           # установка всех зависимостей тестов
./autotest.sh setup-systemd      # регистрация таймеров systemd (или setup-cron)
./autotest.sh list               # команды и плагины
```

Полезные примеры:

```bash
./autotest.sh monitor-once
./autotest.sh monitor-loop 10
./autotest.sh htop-snapshot

./autotest.sh cpu-stress 600
./autotest.sh gpuburn 3600
./autotest.sh ram-memtest 4096 2
./autotest.sh disk-fio /tmp 120
./autotest.sh net-iperf3-server
./autotest.sh net-iperf3-client 192.168.10.18 10 10  # 10 прогонов по 10с, усреднение

./autotest.sh task run 4h
./autotest.sh report
```

## Основные команды (CLI)

- install — установка пакетов, запуск SSH
- monitor-once | monitor-loop <sec> — запись метрик в лог
- htop-snapshot — HTML‑снимок top+sensors (через `aha`)
- stress-ram [duration_s] — стресс RAM (~90% от объёма)
- iostat <device> [interval] — лог iostat для устройства
- cpu-stress [duration_s] — стресс CPU
- gpuburn <duration_s> — стресс GPU + лог `nvidia-smi`
- ram-memtest <MB> <loops> — тест памяти memtester
- disk-fio <dir> <duration_s> — тест диска fio randrw
- net-iperf3-server | net-iperf3-client <host> [10 10] — тест сети (10×10с по умолчанию)
- task run <4h|8h|24h|48h|gpu_only|cpu_only> — запуск пресетов
- setup-cron | setup-systemd | remove-systemd — планировщик
- collect | clean | rotate | report — работа с логами/отчётами
- deps-all | doctor | config-show — зависимости, проверка, конфигурация
- list | run <task> | status | stop | tail — утилиты

Глобальные флаги: `--dry-run`, `--verbose`, `--config PATH`, `--help-ru|--help|-h`, `--help-en`.

## Конфигурация (.env)

Создайте `.env` рядом с `autotest.sh` или используйте `--config PATH`. Пример в `ENV.EXAMPLE`.

Поддерживаемые переменные:

- `AUTOTEST_LOG_DIR`, `AUTOTEST_GPU_LOG_DIR`, `AUTOTEST_ARCHIVE_DIR`
- `AUTOTEST_RETENTION_DAYS`
- `AUTOTEST_FORMAT_DATE` — формат даты/времени (по умолчанию `%d-%m-%Y %H:%M:%S`)
- `AUTOTEST_IPERF_BIND` — адрес для `net-iperf3-server` (по умолчанию `192.168.10.18`)
- `AUTOTEST_IPERF_HOST` — адрес для `net-iperf3-client` (по умолчанию `AUTOTEST_IPERF_BIND`)
- `AUTOTEST_FIO_DIR` — каталог для файла fio (по умолчанию `$HOME`)
- `AUTOTEST_CAMPAIGN_DURATION_H` — длительность для `gpu_only`/`cpu_only`

Европейские форматы дат (примеры для `AUTOTEST_FORMAT_DATE`):

- `%d-%m-%Y %H:%M:%S` → 31-10-2025 14:05:00
- `%d.%m.%Y %H:%M:%S` → 31.10.2025 14:05:00
- `%d/%m/%Y %H:%M:%S` → 31/10/2025 14:05:00

Примечание: `:` в именах файлов допустим в Linux, но может мешать на других ОС/ФС.

## Логи и отчёты

- Логи: `$HOME/AutoTest_Logs/*`
- Логи GPU: `$HOME/gpu_burn_logs/*`
- Отчёты: `$HOME/AutoTest_Archives/report_*.html`

Подкоманды:

- `report` — собрать HTML‑отчёт (краткие итоги и хвосты логов)
- `collect` — упаковать логи в tar.gz
- `rotate` — сжать большие логи (>5M)
- `clean` — очистить логи (по умолчанию — все); фильтры: `--only sys|gpu|htop|ram|iostat|all`, `--older N`

## GUI (Tkinter)

Запуск:

```bash
python3 autotest_gui.py
```

Возможности:

- Запуск основных команд и тестов, пресетов задач (4h/8h/24h/48h/gpu_only/cpu_only)
- Сеть: iperf3 server, iperf3 client (10×10с, среднее)
- Планировщик: setup-cron, setup-systemd, remove-systemd
- Отчёты и логи: report, collect, rotate, clean; кнопка “Open Last Report”
- Статус RUNNING/IDLE и кнопка Stop (остановка текущей команды)
- Выбор `.env` и передача его как `--config`
- Переключение языка интерфейса (RU/EN), по умолчанию — русский

## Cleanup: полная очистка

Скрипт `DELETE_ALL.sh` удалит всё, что создано/установлено autotest:

```bash
chmod +x ./DELETE_ALL.sh
./DELETE_ALL.sh           # спросит подтверждение YES
./DELETE_ALL.sh --yes     # без подтверждения
```

Что делает: останавливает `gpu_burn`, удаляет systemd units/cron, чистит логи/отчёты, удаляет `gpu_burn` и зависимости (`apt purge` пакетов, `pip uninstall` модулей), при наличии `.env` учитывает пользовательские пути.

## Частые вопросы

- Остановить `gpu_burn`:

```bash
./autotest.sh stop gpuburn
# или
kill $(cat ~/gpu_burn_logs/gpu_burn.pid) 2>/dev/null || true
sleep 1; kill -9 $(cat ~/gpu_burn_logs/gpu_burn.pid) 2>/dev/null || true
```

## Лицензия

© Startsev Ilya. Использование в рамках вашей компании или по договорённости.

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


GUI (Tkinter)

- Запуск GUI:

```bash
python3 autotest_gui.py
```

- Возможности:
  - Запуск основных команд: install, monitor-once/loop, htop-snapshot
  - Тесты: cpu-stress, gpuburn, ram-memtest, disk-fio
  - Сеть: iperf3 server, iperf3 client (10×10с с усреднением)
  - Задачи: `task run` пресеты (4h, 8h, 24h, 48h, gpu_only, cpu_only)
  - Планировщик: setup-cron, setup-systemd, remove-systemd
  - Отчёты: report, collect, rotate, clean; кнопка “Open Last Report”
  - Статус и управление: индикатор состояния RUNNING/IDLE, кнопка Stop
  - Выбор `.env` и передача его как `--config PATH`
  - Переключение языка интерфейса (RU/EN), по умолчанию — русский

- Требования:
  - Python 3 с Tkinter (пакет `python3-tk` при необходимости)
  - Доступ к `autotest.sh` (GUI сам предложит выбрать путь, если не найдёт рядом)

