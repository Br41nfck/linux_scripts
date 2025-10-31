AutoTest Linux Framework

Универсальный оркестратор для установки окружения, мониторинга и стресс‑тестов аппаратных ресурсов на Linux. Содержит CLI (`autotest.sh`) и GUI (`autotest_gui.py`).

## Репозиторий

```bash
git clone https://github.com/Br41nfck/linux_scripts
cd linux-scripts
```

## Быстрый старт

```bash
chmod +x ./autotest.sh
./autotest.sh install
./autotest.sh deps-all
./autotest.sh setup-systemd   # или setup-cron
./autotest.sh list
```

Примеры:

```bash
./autotest.sh monitor-once
./autotest.sh cpu-stress 600
./autotest.sh gpuburn 3600
./autotest.sh net-iperf3-client 192.168.10.18 10 10
./autotest.sh task run 4h
./autotest.sh report
```

## Основное (CLI)

- monitor-once | monitor-loop <sec>
- cpu-stress [duration_s] | gpuburn <duration_s> | stress-ram [duration_s]
- ram-memtest <MB> <loops> | disk-fio <dir> <duration_s>
- net-iperf3-server | net-iperf3-client <host> [10 10]
- task run <4h|8h|24h|48h|gpu_only|cpu_only>
- setup-cron | setup-systemd | remove-systemd
- collect | clean | rotate | report
- deps-all | doctor | config-show

## Конфигурация (.env)

Пример — `ENV.EXAMPLE`. Важно:

- `AUTOTEST_LOG_DIR`, `AUTOTEST_GPU_LOG_DIR`, `AUTOTEST_ARCHIVE_DIR`
- `AUTOTEST_FORMAT_DATE` (по умолчанию `%d-%m-%Y %H:%M:%S`)
- `AUTOTEST_IPERF_BIND` (по умолчанию `192.168.10.18`)

## GUI

```bash
python3 autotest_gui.py
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

- Требования:
  - Python 3 с Tkinter (пакет `python3-tk` при необходимости)
  - Доступ к `autotest.sh` (GUI сам предложит выбрать путь, если не найдёт рядом)

