#!/bin/bash

# Unified orchestrator framework for system setup, monitoring and stress tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults (overridable via .env)
LOG_DIR="$HOME/AutoTest_Logs"
GPU_LOG_DIR="$HOME/gpu_burn_logs"
ARCHIVE_DIR="$HOME/AutoTest_Archives"
RETENTION_DAYS=14

mkdir -p "$LOG_DIR" "$GPU_LOG_DIR" "$ARCHIVE_DIR"

# Global flags
DRY_RUN=false
VERBOSE=false

vlog() { $VERBOSE && echo "[VERBOSE] $*" || true; }
run() { if $DRY_RUN; then echo "[DRY-RUN] $*"; else eval "$@"; fi }
info() { echo "[INFO] $(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}") - $*"; }

print_repo_banner() {
  echo "AutoTest Linux Framework"
  echo "Source: https://git.fs-c.ru/Knedl/linux-scripts"
  echo "Version: 1.0.0"
  echo "Author: Startsev Ilya"
  echo "Email: i.startsev@forsite-company.ru"
  echo "--------------------------------"
}

load_config() {
  local cfg_path="${1:-}"
  if [ -z "$cfg_path" ]; then
    if [ -f "$SCRIPT_DIR/.env" ]; then cfg_path="$SCRIPT_DIR/.env"; fi
  fi
  if [ -n "$cfg_path" ] && [ -f "$cfg_path" ]; then
    # shellcheck source=/dev/null
    . "$cfg_path"
    # Apply overrides if provided
    LOG_DIR="${AUTOTEST_LOG_DIR:-$LOG_DIR}"
    GPU_LOG_DIR="${AUTOTEST_GPU_LOG_DIR:-$GPU_LOG_DIR}"
    ARCHIVE_DIR="${AUTOTEST_ARCHIVE_DIR:-$ARCHIVE_DIR}"
    RETENTION_DAYS="${AUTOTEST_RETENTION_DAYS:-$RETENTION_DAYS}"
  fi
  mkdir -p "$LOG_DIR" "$GPU_LOG_DIR" "$ARCHIVE_DIR"
}

print_usage() {
cat <<'USAGE'
Usage: autotest.sh [--dry-run] [--verbose] [--config PATH] <command> [options]

Global flags:
  --dry-run                     Print actions without executing
  --verbose                     Verbose logs
  --config PATH                 Load environment from file (.env format)
  --help-ru | --help | -h       Show help in Russian (default)
  --help-en                     Show help in English

Environment (can be set in .env):
  AUTOTEST_LOG_DIR              Base dir for logs (default: $HOME/AutoTest_Logs)
  AUTOTEST_GPU_LOG_DIR          GPU logs dir (default: $HOME/gpu_burn_logs)
  AUTOTEST_ARCHIVE_DIR          Reports/archives dir (default: $HOME/AutoTest_Archives)
  AUTOTEST_RETENTION_DAYS       Default retention for clean (default: 14)
  AUTOTEST_FORMAT_DATE          Date format for timestamps (default: %d-%m-%Y %H:%M:%S)

Commands:
  install                       Install common packages and enable SSH
  monitor-once                  Append one row of system metrics to log
  monitor-loop <seconds>        Log system metrics every N seconds
  htop-snapshot                 Save HTML snapshot of top+sensors via aha
  stress-ram [duration_s]       Run RAM stress (~90% of RAM) for duration (default 28800s)
  iostat <device> [interval]    Log iostat for device every 5 min (default) or custom interval
  gpuburn <duration_s>          Run gpu_burn for all GPUs and log nvidia-smi
  parse-nvidia <log> [xlsx]     Parse nvidia-smi log to Excel (requires Python deps)
  list                          List available tasks (commands) and plugins
  run <task> [args]             Run any task by name (includes plugins)
  status                        Show runtime status (gpu-burn, cron)
  stop <task>                   Stop a running task (supported: gpuburn)
  tail <task>                   Tail log (monitor-once|htop-snapshot|gpuburn-smi)
  cpu-stress [duration_s]       CPU stress via stress-ng with countdown, logs
  ram-memtest <MB> <loops>      RAM test via memtester, logs
  disk-fio <dir> <duration_s>   Disk test via fio randrw, logs
  net-iperf3-server             Run iperf3 server
  net-iperf3-client <host> <t>  Run iperf3 client to host for t seconds
  task run <4h|8h|24h|48h|gpu_only|cpu_only>

Scheduling:
  setup-cron                    Register cron jobs for monitor-once and htop-snapshot (every 5 min)
  setup-systemd                 Register systemd user timers (falls back to cron)
  remove-systemd                Remove systemd user timers

Logs and reports:
  collect                       Collect logs into timestamped tar.gz in archive dir
  clean [--only sys|gpu|htop|ram|iostat|all] [--older N|--all]
                                Clean logs. By default removes ALL autotest logs now.
                                Use --older N to keep recent logs.
  rotate                        Gzip/compress large logs (>5M) in log dirs
  report                        Build a single HTML with key logs and summary

Tooling:
  deps-all                      Install all dependencies required by tasks
  doctor                        Check dependencies, permissions and environment
  config-show                   Show effective configuration values
  help-en                       Show this help in English
  help-ru                       Show help in Russian

Examples:
  ./autotest.sh install
  ./autotest.sh monitor-loop 10
  ./autotest.sh htop-snapshot
  ./autotest.sh stress-ram 3600
  ./autotest.sh iostat nvme0n1 300
  ./autotest.sh gpuburn 14400
  ./autotest.sh report
  ./autotest.sh setup-systemd   # or setup-cron if no systemd
USAGE
}

print_usage_ru() {
cat <<'USAGE_RU'
Использование: autotest.sh [--dry-run] [--verbose] [--config PATH] <команда> [опции]

Глобальные флаги:
  --dry-run                     Показать действия без выполнения
  --verbose                     Подробный вывод
  --config PATH                 Загрузить переменные окружения из файла (.env)
  --help-ru | --help | -h       Показать справку на русском (по умолчанию)
  --help-en                     Показать справку на английском

Переменные окружения (.env):
  AUTOTEST_LOG_DIR              База логов (по умолчанию: $HOME/AutoTest_Logs)
  AUTOTEST_GPU_LOG_DIR          Логи GPU (по умолчанию: $HOME/gpu_burn_logs)
  AUTOTEST_ARCHIVE_DIR          Папка отчетов/архивов (по умолчанию: $HOME/AutoTest_Archives)
  AUTOTEST_RETENTION_DAYS       Ретенция по умолчанию для clean (по умолчанию: 14)
  AUTOTEST_FORMAT_DATE          Формат даты/времени (по умолчанию: %d-%m-%Y %H:%M:%S)

Команды:
  install                       Установка пакетов и включение SSH
  monitor-once                  Одна строка метрик в лог
  monitor-loop <секунды>        Писать метрики каждые N секунд
  htop-snapshot                 HTML-снимок top+sensors через aha
  stress-ram [секунды]          Стресс RAM (~90% ОЗУ) указанное время
  iostat <устройство> [инт]     Лог iostat для устройства
  gpuburn <секунды>             Запуск gpu_burn на все GPU + лог nvidia-smi
  parse-nvidia <лог> [xlsx]     Парсинг nvidia-smi лога в Excel
  list                          Список задач (включая плагины)
  run <задача> [арг]            Запуск задачи по имени (включая плагины)
  status                        Статус (gpu-burn, cron)
  stop <задача>                 Остановить задачу (поддержка: gpuburn)
  tail <задача>                 Просмотр лога (monitor-once|htop-snapshot|gpuburn-smi)

Планировщик:
  setup-cron                    Добавить задания cron (каждые 5 минут)
  setup-systemd                 Добавить systemd user timers (если недоступно — fallback на cron)
  remove-systemd                Удалить systemd user timers

Логи и отчеты:
  collect                       Сбор логов в tar.gz в папку архива
  clean [--only sys|gpu|htop|ram|iostat|all] [--older N|--all]
                                Очистка логов. По умолчанию удаляет ВСЕ логи автотеста сейчас.
                                С ключом --older N сохраняет свежие логи.
  rotate                        Сжатие больших логов (>5M)
  report                        HTML-отчёт с краткими итогами и хвостами логов

Сервисные команды:
  deps-all                      Установить все зависимости
  doctor                        Проверка зависимостей и окружения
  config-show                   Показать активную конфигурацию
  help-en                       Показать справку на английском
  help-ru                       Показать справку на русском

Примеры:
  ./autotest.sh install
  ./autotest.sh monitor-loop 10
  ./autotest.sh htop-snapshot
  ./autotest.sh stress-ram 3600
  ./autotest.sh iostat nvme0n1 300
  ./autotest.sh gpuburn 14400
  ./autotest.sh report
  ./autotest.sh setup-systemd   # или setup-cron если нет systemd
USAGE_RU
}

ensure_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing dependency: $1" >&2
    exit 1
  fi
}

# Auto-install helpers
require_cmd() {
  # usage: require_cmd <cmd> <apt_pkg>
  local cmd="$1"; local pkg="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Installing missing dependency: $pkg (for $cmd)"
    run sudo apt update
    run sudo apt install -y "$pkg"
  fi
}
require_any_cmd() {
  # usage: require_any_cmd <cmd> <pkg> [<cmd2> <pkg2>...]
  local i=1 found=false
  while [ $i -le $# ]; do
    local cmd="${!i}"; i=$((i+1))
    local pkg="${!i}"; i=$((i+1))
    if command -v "$cmd" >/dev/null 2>&1; then found=true; break; fi
  done
  if ! $found; then
    # install first pair
    set -- "$@"
    local cmd1="$1"; local pkg1="$2"
    echo "Installing dependency: $pkg1 (for $cmd1)"
    run sudo apt update
    run sudo apt install -y "$pkg1"
  fi
}

# Tasks registry (name:description)
declare -A TASK_DESC
TASK_DESC[install]="Install common packages and enable SSH"
TASK_DESC[monitor-once]="Append one row of system metrics to log"
TASK_DESC[monitor-loop]="Log system metrics every N seconds"
TASK_DESC[htop-snapshot]="Save HTML snapshot of top+sensors via aha"
TASK_DESC[stress-ram]="Run RAM stress (~90% of RAM)"
TASK_DESC[iostat]="Log iostat for a device at intervals"
TASK_DESC[gpuburn]="Run gpu_burn and log nvidia-smi"
TASK_DESC[parse-nvidia]="Parse nvidia-smi log to Excel"
TASK_DESC[setup-cron]="Register cron jobs for monitor and snapshot"
TASK_DESC[list]="List available tasks"
TASK_DESC[run]="Run task by name"
TASK_DESC[status]="Show runtime status (gpu-burn, cron)"
TASK_DESC[stop]="Stop a running task"
TASK_DESC[tail]="Tail known task log"
TASK_DESC[collect]="Archive logs into tar.gz"
TASK_DESC[clean]="Delete logs older than N days"
TASK_DESC[rotate]="Compress large logs to save space"
TASK_DESC[deps-all]="Install all framework dependencies"
TASK_DESC[config-show]="Print current configuration"
TASK_DESC[doctor]="Check dependencies, permissions and environment"
TASK_DESC[report]="Build HTML report with summaries and recent logs"
TASK_DESC[setup-systemd]="Register systemd user timers (fallback to cron)"
TASK_DESC[remove-systemd]="Remove systemd user timers"
TASK_DESC[cpu-stress]="CPU stress test via stress-ng"
TASK_DESC[ram-memtest]="RAM test via memtester"
TASK_DESC[disk-fio]="Disk test via fio"
TASK_DESC[net-iperf3-server]="Run iperf3 server"
TASK_DESC[net-iperf3-client]="Run iperf3 client"
TASK_DESC[task]="Run predefined test tasks"

# Plugin registry
declare -A PLUGIN_PATH
declare -A PLUGIN_DESC

discover_plugins() {
  local f base name desc first_comment meta_name meta_desc
  for f in "$SCRIPT_DIR"/*.sh; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    # skip self
    if [ "$base" = "autotest.sh" ]; then continue; fi
    # skip non-executable
    if [ ! -x "$f" ]; then continue; fi
    # skip nested tool launchers (optional): gpuburn scripts
    case "$f" in
      */gpuburn/*) continue ;;
    esac
    name="${base%.sh}"
    # try metadata
    meta_name=$(grep -m1 -E '^#\s*AUTOTEST_NAME\s*:' "$f" | sed -E 's/^#\s*AUTOTEST_NAME\s*:\s*//') || true
    if [ -n "$meta_name" ]; then name="$meta_name"; fi
    meta_desc=$(grep -m1 -E '^#\s*AUTOTEST_DESC\s*:' "$f" | sed -E 's/^#\s*AUTOTEST_DESC\s*:\s*//') || true
    if [ -n "$meta_desc" ]; then
      desc="$meta_desc"
    else
      first_comment=$(grep -m1 -E '^#' "$f" | sed -E 's/^#\s*//') || true
      desc=${first_comment:-"Custom plugin script"}
    fi
    PLUGIN_PATH["$name"]="$f"
    PLUGIN_DESC["$name"]="$desc"
  done
}

cmd_install() {
  info "Starting install"
  run sudo apt update
  run sudo apt install -y vim nano htop stress-ng openssh-server tmux mc git smbclient cifs-utils libsensors5 aha
  if systemctl is-active --quiet ssh; then
    echo "SSH уже запущен."
  else
    echo "SSH не работает. Запускаю..."
    run sudo systemctl restart ssh || true
    if systemctl is-active --quiet ssh; then
      echo "SSH успешно запущен."
    else
      echo "Не удалось запустить SSH!" >&2
    fi
  fi
  IP=$(hostname -I | awk '{print $1}')
  echo "Подключиться можно по адресу: ssh $(whoami)@$IP"
}

cmd_monitor_once() {
  info "Monitor once"
  bash "$SCRIPT_DIR/monitor.sh"
  echo "Appended metrics to $HOME/AutoTest_Logs/sysmonitor/sysmonitor.log"
}

cmd_monitor_loop() {
  local interval="${1:-10}"
  info "Monitor loop every ${interval}s"
  ensure_cmd awk
  ensure_cmd sensors || true
  while true; do
    bash "$SCRIPT_DIR/monitor.sh"
    sleep "$interval"
  done
}

cmd_htop_snapshot() {
  info "HTOP snapshot"
  require_cmd aha aha
  require_any_cmd sensors lm-sensors sensors lm-sensors
  bash "$SCRIPT_DIR/htop-res.sh"
}

cmd_stress_ram() {
  local duration="${1:-28800}"
  info "RAM stress for ${duration}s"
  require_cmd stress-ng stress-ng
  DURATION="$duration" bash "$SCRIPT_DIR/stress_ram.sh"
}

cmd_iostat() {
  local dev="${1:-}"
  local interval="${2:-300}"
  if [ -z "$dev" ]; then
    echo "Specify device, e.g. nvme0n1" >&2
    exit 1
  fi
  ensure_cmd iostat
  require_cmd iostat sysstat
  local log_file="$LOG_DIR/${dev}_iostat.csv"
  info "Start iostat for ${dev} every ${interval}s -> $log_file"
  if [ ! -f "$log_file" ]; then
    echo "Timestamp,Read_MB_s,Write_MB_s" > "$log_file"
  fi
  echo "Logging iostat for $dev every ${interval}s to $log_file"
  while true; do
    TS=$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}")
    iostat -dx 1 1 | awk -v dev="$dev" -v ts="$TS" '$1 == dev {printf "%s,%.2f,%.2f\n", ts, $3, $4}' >> "$log_file"
    sleep "$interval"
  done
}

cmd_gpuburn() {
  local duration="${1:-3600}"
  info "GPU burn for ${duration}s"
  require_cmd nvidia-smi nvidia-utils-535 || true
  if [ ! -x "$SCRIPT_DIR/gpu_burn" ] && ! command -v gpu_burn >/dev/null 2>&1; then
    echo "gpu_burn не найден. Пытаюсь установить..."
    require_cmd git git
    require_cmd make build-essential
    run git clone https://github.com/wilicc/gpu-burn.git "$SCRIPT_DIR/gpu-burn-src" || true
    if [ -d "$SCRIPT_DIR/gpu-burn-src" ]; then
      (cd "$SCRIPT_DIR/gpu-burn-src" && run make)
      if [ -x "$SCRIPT_DIR/gpu-burn-src/gpu_burn" ]; then
        run cp "$SCRIPT_DIR/gpu-burn-src/gpu_burn" "$SCRIPT_DIR/gpu_burn"
        run chmod +x "$SCRIPT_DIR/gpu_burn"
      fi
    fi
    if [ ! -x "$SCRIPT_DIR/gpu_burn" ] && ! command -v gpu_burn >/dev/null 2>&1; then
      echo "Не удалось установить gpu_burn автоматически. Установите вручную." >&2
      exit 1
    fi
  fi
  LOGDIR="$GPU_LOG_DIR"
  mkdir -p "$LOGDIR"
  local burn_log="$LOGDIR/gpu_burn_$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}").log"
  local smi_log="$LOGDIR/nvidia-smi_$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}").log"
  local bin="${SCRIPT_DIR}/gpu_burn"
  if command -v gpu_burn >/dev/null 2>&1; then bin="$(command -v gpu_burn)"; fi
  mapfile -t gpu_idx < <(nvidia-smi --query-gpu=index --format=csv,noheader 2>/dev/null | tr -d '\r')
  if [ "${#gpu_idx[@]}" -eq 0 ]; then
    echo "GPU не обнаружены через nvidia-smi" >&2
    exit 1
  fi
  echo "Запуск gpu_burn на GPU: ${gpu_idx[*]} на ${duration}с"
  nohup "$bin" "$duration" "${gpu_idx[@]}" > "$burn_log" 2>&1 &
  local pid=$!
  echo $pid > "$LOGDIR/gpu_burn.pid"
  (
    while kill -0 $pid 2>/dev/null; do
      nvidia-smi
      sleep 10
    done
  ) >> "$smi_log" 2>&1 &
  echo "Логи: $burn_log, $smi_log"
}

cmd_status() {
  info "Status"
  local LOGDIR="$HOME/gpu_burn_logs"
  if [ -f "$LOGDIR/gpu_burn.pid" ]; then
    local pid
    pid=$(cat "$LOGDIR/gpu_burn.pid" 2>/dev/null || true)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "gpu_burn: RUNNING (pid=$pid)"
    else
      echo "gpu_burn: NOT RUNNING"
    fi
  else
    echo "gpu_burn: NO PID FILE"
  fi
  if crontab -l 2>/dev/null | grep -q "autotest monitor-once"; then
    echo "cron: monitor-once present"
  else
    echo "cron: monitor-once missing"
  fi
  if crontab -l 2>/dev/null | grep -q "autotest htop-snapshot"; then
    echo "cron: htop-snapshot present"
  else
    echo "cron: htop-snapshot missing"
  fi
}

cmd_stop() {
  local task="${1:-}"
  info "Stop task ${task}"
  if [ -z "$task" ]; then echo "Specify task to stop (e.g. gpuburn)" >&2; exit 1; fi
  case "$task" in
    gpuburn)
      local LOGDIR="$HOME/gpu_burn_logs"
      if [ -f "$LOGDIR/gpu_burn.pid" ]; then
        local pid
        pid=$(cat "$LOGDIR/gpu_burn.pid" 2>/dev/null || true)
        if [ -n "$pid" ]; then
          kill "$pid" 2>/dev/null || true
          sleep 1
          if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
          fi
          echo "Stopped gpuburn (pid=$pid)"
        else
          echo "No PID inside pid file"
        fi
      else
        echo "No pid file found"
      fi
      ;;
    *)
      echo "Stop not supported for: $task" >&2; exit 1 ;;
  esac
}

cmd_tail() {
  local task="${1:-}"
  info "Tail ${task}"
  if [ -z "$task" ]; then echo "Specify task to tail (monitor-once|htop-snapshot|gpuburn-smi)" >&2; exit 1; fi
  case "$task" in
    monitor-once)
      tail -f "$LOG_DIR/monitor-once.log" ;;
    htop-snapshot)
      tail -f "$LOG_DIR/htop-snapshot.log" ;;
    gpuburn-smi)
      local LOGDIR="$HOME/gpu_burn_logs"; local last
      last=$(ls -1t "$LOGDIR"/nvidia-smi_*.log 2>/dev/null | head -n1)
      [ -n "$last" ] && tail -f "$last" || { echo "No nvidia-smi logs found"; exit 1; }
      ;;
    *) echo "Unknown task for tail: $task" >&2; exit 1 ;;
  esac
}

cmd_list() {
  info "List tasks and plugins"
  discover_plugins
  echo "Built-in tasks:"
  for k in "${!TASK_DESC[@]}"; do
    printf "  %-14s - %s\n" "$k" "${TASK_DESC[$k]}"
  done | sort
  echo ""
  echo "Plugins:"
  if [ ${#PLUGIN_PATH[@]} -eq 0 ]; then
    echo "  (none found)"
  else
    for k in "${!PLUGIN_PATH[@]}"; do
      printf "  %-14s - %s (path: %s)\n" "$k" "${PLUGIN_DESC[$k]}" "${PLUGIN_PATH[$k]}"
    done | sort
  fi
}

cmd_run() {
  local task="${1:-}"; shift || true
  info "Run task: ${task}"
  if [ -z "$task" ]; then echo "Specify task to run" >&2; exit 1; fi
  case "$task" in
    install|monitor-once|monitor-loop|htop-snapshot|stress-ram|iostat|gpuburn|parse-nvidia|setup-cron|list|status|stop|tail)
      "cmd_${task//-/_}" "$@" ;;
    *)
       discover_plugins
       if [ -n "${PLUGIN_PATH[$task]:-}" ]; then
         bash "${PLUGIN_PATH[$task]}" "$@"
       else
         echo "Unknown task: $task" >&2; exit 1
       fi
       ;;
  esac
}

cmd_collect() {
  local ts archive
  ts=$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}")
  info "Collect logs"
  mkdir -p "$ARCHIVE_DIR"
  archive="$ARCHIVE_DIR/autotest_logs_$ts.tar.gz"
  echo "Collecting logs to $archive"
  run tar -czf "$archive" -C "$HOME" \
    "${LOG_DIR#${HOME}/}" 2>/dev/null || true
  run tar -rzf "$archive" -C "$HOME" \
    "${GPU_LOG_DIR#${HOME}/}" 2>/dev/null || true
  echo "Saved: $archive"
}

cmd_clean() {
  local only="all"; local older=""; local mode="all_now"
  info "Clean logs"
  while [ -n "${1:-}" ]; do
    case "$1" in
      --only) only="$2"; shift 2 ;;
      --older) older="$2"; mode="older"; shift 2 ;;
      --all) mode="all_now"; shift ;;
      *) break ;;
    esac
  done

  # Targets
  local sys_dirs=("$LOG_DIR" "$HOME/AutoTest_Logs/sysmonitor")
  local gpu_dirs=("$GPU_LOG_DIR")
  local htop_dirs=("$HOME/htop-res")
  local ram_dirs=("$HOME/ram_stress_logs")
  local iostat_dirs=("$LOG_DIR")

  clean_dir() {
    local dir="$1"; local pattern="$2"
    [ -d "$dir" ] || return 0
    if [ "$mode" = "older" ]; then
      find "$dir" -type f -name "$pattern" -mtime +"$older" -print -delete 2>/dev/null || true
    else
      find "$dir" -type f -name "$pattern" -print -delete 2>/dev/null || true
    fi
  }

  echo "Cleaning logs (only=$only, mode=$mode${older:+, older=$older d})"

  case "$only" in
    sys|all)
      for d in "${sys_dirs[@]}"; do
        clean_dir "$d" "*.log"; clean_dir "$d" "*.csv"; clean_dir "$d" "*.html"; clean_dir "$d" "*.log.gz"; clean_dir "$d" "*.csv.gz"; clean_dir "$d" "*.html.gz"
      done
      ;;&
    gpu|all)
      for d in "${gpu_dirs[@]}"; do
        clean_dir "$d" "*.log"; clean_dir "$d" "*.csv"; clean_dir "$d" "*.gz"; clean_dir "$d" "*.pid"
      done
      ;;&
    htop|all)
      for d in "${htop_dirs[@]}"; do
        clean_dir "$d" "*.html"; clean_dir "$d" "*.html.gz"
      done
      ;;&
    ram|all)
      for d in "${ram_dirs[@]}"; do
        clean_dir "$d" "*.log"; clean_dir "$d" "*.log.gz"
      done
      ;;&
    iostat|all)
      for d in "${iostat_dirs[@]}"; do
        clean_dir "$d" "*_iostat.csv"; clean_dir "$d" "*_iostat.csv.gz"
      done
      ;;
    *) echo "Unknown --only value: $only" >&2; exit 1 ;;
  esac
}

cmd_rotate() {
  info "Rotate logs (>5M)"
  echo "Compressing large logs (>5M) in $LOG_DIR and $GPU_LOG_DIR"
  find "$LOG_DIR" -type f \( -name '*.log' -o -name '*.html' -o -name '*.csv' \) -size +5M -not -name '*.gz' -print -exec gzip -f {} + 2>/dev/null || true
  find "$GPU_LOG_DIR" -type f \( -name '*.log' -o -name '*.csv' \) -size +5M -not -name '*.gz' -print -exec gzip -f {} + 2>/dev/null || true
}

cmd_deps_all() {
  info "Installing dependencies"
  run sudo apt update
  run sudo apt install -y vim nano htop stress-ng openssh-server tmux mc git smbclient cifs-utils libsensors5 aha sysstat lm-sensors python3 python3-pip build-essential memtester fio iperf3 smartmontools nvme-cli
  # Optional NVIDIA utils
  run sudo apt install -y nvidia-utils-535 || true
  # Python libs for parsers
  run python3 -m pip install --user --upgrade pip
  run python3 -m pip install --user pandas openpyxl
  # gpu_burn build
  if [ ! -x "$SCRIPT_DIR/gpu_burn" ]; then
    run git clone https://github.com/wilicc/gpu-burn.git "$SCRIPT_DIR/gpu-burn-src" || true
    if [ -d "$SCRIPT_DIR/gpu-burn-src" ]; then
      (cd "$SCRIPT_DIR/gpu-burn-src" && run make)
      if [ -x "$SCRIPT_DIR/gpu-burn-src/gpu_burn" ]; then
        run cp "$SCRIPT_DIR/gpu-burn-src/gpu_burn" "$SCRIPT_DIR/gpu_burn"
        run chmod +x "$SCRIPT_DIR/gpu_burn"
      fi
    fi
  fi
  echo "deps-all completed."
}

cmd_config_show() {
  info "Config show"
  echo "CONFIG:" 
  echo "  LOG_DIR=$LOG_DIR"
  echo "  GPU_LOG_DIR=$GPU_LOG_DIR"
  echo "  ARCHIVE_DIR=$ARCHIVE_DIR"
  echo "  RETENTION_DAYS=$RETENTION_DAYS"
  echo "  FORMAT_DATE=${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}"
}

cmd_cpu_stress() {
  local duration="${1:-600}"
  info "CPU stress for ${duration}s"
  require_cmd stress-ng stress-ng
  local ts logfile
  ts=$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}")
  logfile="$LOG_DIR/cpu_stress_${ts}.log"
  echo "CPU stress for ${duration}s" | tee -a "$logfile"
  stress-ng --cpu 0 --cpu-method matrixprod --timeout ${duration}s --metrics-brief 2>&1 | tee -a "$logfile" &
  local pid=$!
  local end=$(( $(date +%s) + duration ))
  while kill -0 $pid 2>/dev/null; do
    now=$(date +%s); remain=$(( end - now )); [ $remain -lt 0 ] && remain=0
    h=$(( remain/3600 )); m=$(( (remain%3600)/60 )); s=$(( remain%60 ))
    printf "\rRemaining: %02d:%02d:%02d" $h $m $s | tee -a "$logfile" >/dev/null
    sleep 1
  done
  echo >> "$logfile"
  echo "CPU stress finished at $(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}")" | tee -a "$logfile"
}

cmd_ram_memtest() {
  local mb="${1:-1024}"; local loops="${2:-1}"
  info "RAM memtest ${mb}MB loops=${loops}"
  require_cmd memtester memtester
  local ts logfile
  ts=$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}")
  logfile="$LOG_DIR/memtest_${ts}.log"
  echo "memtester ${mb} MB, loops=${loops}" | tee -a "$logfile"
  sudo memtester "$mb" "$loops" 2>&1 | tee -a "$logfile"
}

cmd_disk_fio() {
  local dir="${1:-$HOME}"; local duration="${2:-60}"
  info "Disk FIO in ${dir} for ${duration}s"
  require_cmd fio fio
  mkdir -p "$dir"
  local ts logfile
  ts=$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}")
  logfile="$LOG_DIR/fio_${ts}.log"
  local file="$dir/fio_testfile"
  echo "fio randrw ${duration}s on $file" | tee -a "$logfile"
  fio --name=autotest --filename="$file" --size=1G --bs=128k --rw=randrw --rwmixread=50 --ioengine=libaio --iodepth=32 --direct=1 --runtime="$duration" --time_based --group_reporting 2>&1 | tee -a "$logfile"
  rm -f "$file"
}

cmd_net_iperf3_server() {
  require_cmd iperf3 iperf3
  local bind_ip="${AUTOTEST_IPERF_BIND:-192.168.10.18}"
  info "Start iperf3 server on ${bind_ip}"
  echo "Starting iperf3 server on ${bind_ip} (Ctrl+C to stop)"
  iperf3 -s -B "$bind_ip"
}

cmd_net_iperf3_client() {
  local host="${1:-}"; local duration="${2:-10}"; local runs="${3:-10}"
  info "iperf3 client to ${host} runs=${runs} duration=${duration}s"
  if [ -z "$host" ]; then echo "Specify host for iperf3 client" >&2; exit 1; fi
  require_cmd iperf3 iperf3
  local ts logfile
  ts=$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}")
  logfile="$LOG_DIR/iperf3_${ts}.log"
  echo "iperf3 to $host, duration=${duration}s, runs=${runs}" | tee -a "$logfile"

  # helper: convert '<number> <unit>bits/sec' to Mbps
  to_mbps() {
    local val="$1"; local unit="$2"
    case "$unit" in
      G|Gbit|Gbits) awk -v v="$val" 'BEGIN{printf "%.2f", v*1000}' ;;
      M|Mbit|Mbits) awk -v v="$val" 'BEGIN{printf "%.2f", v}' ;;
      K|Kbit|Kbits) awk -v v="$val" 'BEGIN{printf "%.4f", v/1000}' ;;
      *) awk -v v="$val" 'BEGIN{printf "%.2f", v/1000000}' ;; # bits/sec -> Mbps
    esac
  }

  local i=1 sum=0 count=0
  while [ $i -le $runs ]; do
    echo "Run $i/$runs" | tee -a "$logfile"
    # text output parsing: take receiver summary line
    local line
    line=$(iperf3 -c "$host" -t "$duration" 2>&1 | tee -a "$logfile" | awk '/receiver$/ {last=$0} END{print last}')
    # extract bandwidth number and unit (e.g., 945 Mbits/sec)
    local bw_num bw_unit
    bw_num=$(echo "$line" | awk '{for(i=1;i<=NF;i++) if ($i ~ /bits\/sec$/) {print $(i-1); exit}}')
    bw_unit=$(echo "$line" | awk '{for(i=1;i<=NF;i++) if ($i ~ /bits\/sec$/) {u=$(i-1); if(u~"Gbits") print "G"; else if(u~"Mbits") print "M"; else if(u~"Kbits") print "K"; else print "b"; exit}}')
    if [ -n "$bw_num" ]; then
      local mbps
      mbps=$(to_mbps "$bw_num" "$bw_unit")
      echo "Run $i: ${mbps} Mbps" | tee -a "$logfile"
      sum=$(awk -v a="$sum" -v b="$mbps" 'BEGIN{printf "%.4f", a+b}')
      count=$((count+1))
    else
      echo "Run $i: could not parse bandwidth" | tee -a "$logfile"
    fi
    i=$((i+1))
  done
  if [ $count -gt 0 ]; then
    local avg
    avg=$(awk -v s="$sum" -v c="$count" 'BEGIN{printf "%.2f", s/c}')
    echo "Average over $count runs: ${avg} Mbps" | tee -a "$logfile"
  else
    echo "No successful runs to compute average" | tee -a "$logfile"
  fi
}

cmd_task() {
  local action="${1:-}"; shift || true
  info "Run task preset: ${*}"
  if [ "$action" != "run" ]; then
    echo "Usage: autotest.sh task run <4h|8h|24h|48h|gpu_only|cpu_only>" >&2
    exit 1
  fi
  local preset="${1:-}"; shift || true
  if [ -z "$preset" ]; then echo "Specify campaign preset" >&2; exit 1; fi

  # Helpers
  run_step() { echo "[Campaign] $*"; "$@"; }
  seconds_for_hours() { echo $(( $1 * 3600 )); }

  local iperf_host="${AUTOTEST_IPERF_HOST:-${AUTOTEST_IPERF_BIND:-192.168.10.18}}"
  local work_dir="${AUTOTEST_FIO_DIR:-$HOME}"

  case "$preset" in
    4h)
      run_step "$SCRIPT_DIR/autotest.sh" cpu-stress $(seconds_for_hours 1)
      run_step "$SCRIPT_DIR/autotest.sh" gpuburn $(seconds_for_hours 1)
      run_step "$SCRIPT_DIR/autotest.sh" stress-ram $(seconds_for_hours 1)
      # Network + Disk: run sequentially 30m each
      run_step "$SCRIPT_DIR/autotest.sh" net-iperf3-client "$iperf_host" 10 10
      run_step "$SCRIPT_DIR/autotest.sh" disk-fio "$work_dir" $((30*60))
      ;;
    8h)
      run_step "$SCRIPT_DIR/autotest.sh" cpu-stress $(seconds_for_hours 2)
      run_step "$SCRIPT_DIR/autotest.sh" gpuburn $(seconds_for_hours 2)
      run_step "$SCRIPT_DIR/autotest.sh" stress-ram $(seconds_for_hours 2)
      run_step "$SCRIPT_DIR/autotest.sh" net-iperf3-client "$iperf_host" 10 10
      run_step "$SCRIPT_DIR/autotest.sh" disk-fio "$work_dir" $(seconds_for_hours 1)
      ;;
    24h)
      # Split equally into 4 x 6h
      run_step "$SCRIPT_DIR/autotest.sh" cpu-stress $(seconds_for_hours 6)
      run_step "$SCRIPT_DIR/autotest.sh" gpuburn $(seconds_for_hours 6)
      run_step "$SCRIPT_DIR/autotest.sh" stress-ram $(seconds_for_hours 6)
      run_step "$SCRIPT_DIR/autotest.sh" net-iperf3-client "$iperf_host" 10 10
      run_step "$SCRIPT_DIR/autotest.sh" disk-fio "$work_dir" $(seconds_for_hours 3)
      ;;
    48h)
      # Split equally into 4 x 12h
      run_step "$SCRIPT_DIR/autotest.sh" cpu-stress $(seconds_for_hours 12)
      run_step "$SCRIPT_DIR/autotest.sh" gpuburn $(seconds_for_hours 12)
      run_step "$SCRIPT_DIR/autotest.sh" stress-ram $(seconds_for_hours 12)
      run_step "$SCRIPT_DIR/autotest.sh" net-iperf3-client "$iperf_host" 10 10
      run_step "$SCRIPT_DIR/autotest.sh" disk-fio "$work_dir" $(seconds_for_hours 6)
      ;;
    gpu_only)
      # Default 4h, override via AUTOTEST_CAMPAIGN_DURATION_H
      local H="${AUTOTEST_CAMPAIGN_DURATION_H:-4}"
      run_step "$SCRIPT_DIR/autotest.sh" gpuburn $(seconds_for_hours "$H")
      ;;
    cpu_only)
      # Default 4h split: 2h CPU + 2h RAM
      local H="${AUTOTEST_CAMPAIGN_DURATION_H:-4}"
      local half=$(( H/2 ))
      [ $half -lt 1 ] && half=1
      run_step "$SCRIPT_DIR/autotest.sh" cpu-stress $(seconds_for_hours "$half")
      run_step "$SCRIPT_DIR/autotest.sh" stress-ram $(seconds_for_hours "$half")
      ;;
    *) echo "Unknown preset: $preset" >&2; exit 1 ;;
  esac
}

cmd_doctor() {
  echo "AutoTest Doctor"
  local ok=0
  check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
      echo "[OK]   $name"
    else
      echo "[FAIL] $name"
      ok=1
    fi
  }
  echo "- Commands"
  check "bash" command -v bash
  check "top" command -v top
  check "sensors (lm-sensors)" command -v sensors
  check "aha" command -v aha
  check "stress-ng" command -v stress-ng
  check "iostat (sysstat)" command -v iostat
  check "python3" command -v python3
  check "pip3" command -v pip3
  check "pandas (python)" python3 -c "import pandas"
  check "openpyxl (python)" python3 -c "import openpyxl"
  check "nvidia-smi (optional)" command -v nvidia-smi || true
  echo "- Directories"
  for d in "$LOG_DIR" "$GPU_LOG_DIR" "$ARCHIVE_DIR"; do
    if [ -d "$d" ] && [ -w "$d" ]; then echo "[OK]   writable: $d"; else echo "[FAIL] writable: $d"; ok=1; fi
  done
  echo "- Network"
  hostname -I >/dev/null 2>&1 && echo "[OK]   hostname -I" || { echo "[FAIL] hostname -I"; ok=1; }
  echo "- GPU Burn binary"
  if [ -x "$SCRIPT_DIR/gpu_burn" ] || command -v gpu_burn >/dev/null 2>&1; then
    echo "[OK]   gpu_burn present"
  else
    echo "[WARN] gpu_burn not found (will attempt auto-build during gpuburn)"
  fi
  if [ $ok -eq 0 ]; then echo "Doctor: PASS"; else echo "Doctor: issues detected"; fi
  return $ok
}

cmd_report() {
  local ts out
  ts=$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}")
  out="$ARCHIVE_DIR/report_$ts.html"
  mkdir -p "$ARCHIVE_DIR"
  echo "Generating report: $out"
  {
    echo "<html><head><meta charset=\"utf-8\"><title>AutoTest Report $ts</title>"
    echo "<style>body{font-family:Segoe UI,Arial,sans-serif;margin:20px}h1,h2{margin:8px 0}pre{background:#111;color:#eee;padding:10px;overflow:auto} .kv{font-family:monospace} .ok{color:#2ecc71}.fail{color:#e74c3c}.warn{color:#f1c40f} table{border-collapse:collapse} td,th{border:1px solid #ddd;padding:6px}</style>"
    echo "</head><body>"
    echo "<h1>AutoTest Report</h1><div class=kv>Generated: $ts</div>"
    echo "<h2>Environment</h2><pre>"
    echo "Host: $(hostname)"
    uname -a
    echo "\nCPU:"; lscpu 2>/dev/null | sed -n '1,12p'
    echo "</pre>"
    echo "<h2>Configuration</h2><pre>LOG_DIR=$LOG_DIR\nGPU_LOG_DIR=$GPU_LOG_DIR\nARCHIVE_DIR=$ARCHIVE_DIR\nRETENTION_DAYS=$RETENTION_DAYS</pre>"

    # Helper to print latest file tail
    print_section() {
      local title="$1"; local pattern="$2"; local dir="$3"; local lines="${4:-100}"
      local file
      file=$(ls -1t "$dir"/$pattern 2>/dev/null | head -n1)
      echo "<h2>$title</h2>"
      if [ -n "$file" ]; then
        echo "<div class=kv>File: $file</div><pre>"
        tail -n "$lines" "$file" 2>/dev/null
        echo "</pre>"
      else
        echo "<div class=warn>No files found in $dir matching $pattern</div>"
      fi
    }

    print_section "System monitor" "sysmonitor.log" "$HOME/AutoTest_Logs/sysmonitor" 50
    print_section "HTOP snapshot (HTML shown as text)" "*.html" "$HOME/htop-res" 80 | sed 's/<pre>/<pre>&lt;html&gt; content not rendered, showing raw &lt;tags&gt;\n/g'
    print_section "RAM stress log" "*.log" "$HOME/ram_stress_logs" 80
    print_section "IOStat csv" "*_iostat.csv" "$LOG_DIR" 40
    print_section "GPU burn log" "gpu_burn_*.log" "$GPU_LOG_DIR" 80
    print_section "nvidia-smi log" "nvidia-smi_*.log" "$GPU_LOG_DIR" 80

    echo "</body></html>"
  } > "$out"
  echo "Report saved: $out"
}

cmd_parse_nvidia() {
  local in_log="${1:-}"
  local out_xlsx="${2:-gpu_metrics.xlsx}"
  if [ -z "$in_log" ]; then
    echo "Specify nvidia-smi log path" >&2
    exit 1
  fi
  require_cmd python3 python3
  require_cmd pip3 python3-pip
  run python3 -m pip install --user --upgrade pip
  run python3 -m pip install --user pandas openpyxl
  python3 "$SCRIPT_DIR/gpuburn/nvidia-smi_table-parser.py" "$in_log" -o "$out_xlsx"
}

cmd_setup_cron() {
  local AUTOTEST="$SCRIPT_DIR/autotest.sh"
  mkdir -p "$LOG_DIR"
  local CRON_MONITOR="*/5 * * * * /bin/bash $AUTOTEST monitor-once >> $LOG_DIR/monitor-once.log 2>&1"
  local CRON_HTOP="*/5 * * * * /bin/bash $AUTOTEST htop-snapshot >> $LOG_DIR/htop-snapshot.log 2>&1"
  (crontab -l 2>/dev/null | grep -F "autotest monitor-once") || (crontab -l 2>/dev/null; echo "$CRON_MONITOR") | crontab -
  (crontab -l 2>/dev/null | grep -F "autotest htop-snapshot") || (crontab -l 2>/dev/null; echo "$CRON_HTOP") | crontab -
  echo "Cron jobs registered: monitor-once and htop-snapshot (every 5 min)"
}

have_systemd() {
  command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]
}

cmd_setup_systemd() {
  if ! have_systemd; then
    echo "Systemd is not available. Falling back to cron."
    cmd_setup_cron
    return 0
  fi
  local user_dir="$HOME/.config/systemd/user"
  mkdir -p "$user_dir"
  local AUTOTEST="$SCRIPT_DIR/autotest.sh"

  # monitor-once service/timer
  cat > "$user_dir/autotest-monitor-once.service" <<EOF
[Unit]
Description=AutoTest monitor-once

[Service]
Type=oneshot
ExecStart=/bin/bash $AUTOTEST monitor-once
EOF

  cat > "$user_dir/autotest-monitor-once.timer" <<EOF
[Unit]
Description=Run AutoTest monitor-once every 5 minutes

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

  # htop-snapshot service/timer
  cat > "$user_dir/autotest-htop-snapshot.service" <<EOF
[Unit]
Description=AutoTest htop-snapshot

[Service]
Type=oneshot
ExecStart=/bin/bash $AUTOTEST htop-snapshot
EOF

  cat > "$user_dir/autotest-htop-snapshot.timer" <<EOF
[Unit]
Description=Run AutoTest htop-snapshot every 5 minutes

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload || true
  systemctl --user enable --now autotest-monitor-once.timer || true
  systemctl --user enable --now autotest-htop-snapshot.timer || true
  echo "Systemd user timers enabled: autotest-monitor-once.timer, autotest-htop-snapshot.timer"
  echo "Tip: use 'systemctl --user list-timers' to view timers."
}

cmd_remove_systemd() {
  if ! have_systemd; then
    echo "Systemd not available. Nothing to remove."
    return 0
  fi
  systemctl --user disable --now autotest-monitor-once.timer 2>/dev/null || true
  systemctl --user disable --now autotest-htop-snapshot.timer 2>/dev/null || true
  rm -f "$HOME/.config/systemd/user/autotest-monitor-once.timer" \
        "$HOME/.config/systemd/user/autotest-monitor-once.service" \
        "$HOME/.config/systemd/user/autotest-htop-snapshot.timer" \
        "$HOME/.config/systemd/user/autotest-htop-snapshot.service"
  systemctl --user daemon-reload || true
  echo "Systemd user timers removed (if existed)."
}

# Parse global flags
CONFIG_PATH=""
while [[ "${1:-}" =~ ^-- ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    --config) CONFIG_PATH="$2"; shift 2 ;;
    --help-ru|--help|-h) print_usage_ru; exit 0 ;;
    --help-en) print_usage; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; print_usage; exit 1 ;;
  esac
done

load_config "$CONFIG_PATH"

# Print banner only when launched without commands/flags (TTY only)
if [ -t 1 ] && [ "${AUTOTEST_NO_BANNER:-0}" != "1" ] && [ $# -eq 0 ]; then
  print_repo_banner
fi

case "${1:-help}" in
  install)
    shift; cmd_install "$@" ;;
  monitor-once)
    shift; cmd_monitor_once "$@" ;;
  monitor-loop)
    shift; cmd_monitor_loop "$@" ;;
  htop-snapshot)
    shift; cmd_htop_snapshot "$@" ;;
  stress-ram)
    shift; cmd_stress_ram "$@" ;;
  iostat)
    shift; cmd_iostat "$@" ;;
  gpuburn)
    shift; cmd_gpuburn "$@" ;;
  cpu-stress)
    shift; cmd_cpu_stress "$@" ;;
  ram-memtest)
    shift; cmd_ram_memtest "$@" ;;
  disk-fio)
    shift; cmd_disk_fio "$@" ;;
  net-iperf3-server)
    shift; cmd_net_iperf3_server "$@" ;;
  net-iperf3-client)
    shift; cmd_net_iperf3_client "$@" ;;
  task)
    shift; cmd_task "$@" ;;
  parse-nvidia)
    shift; cmd_parse_nvidia "$@" ;;
  setup-cron)
    shift; cmd_setup_cron "$@" ;;
  setup-systemd)
    shift; cmd_setup_systemd "$@" ;;
  remove-systemd)
    shift; cmd_remove_systemd "$@" ;;
  list)
    shift; cmd_list "$@" ;;
  run)
    shift; cmd_run "$@" ;;
  status)
    shift; cmd_status "$@" ;;
  stop)
    shift; cmd_stop "$@" ;;
  tail)
    shift; cmd_tail "$@" ;;
  collect)
    shift; cmd_collect "$@" ;;
  clean)
    shift; cmd_clean "$@" ;;
  rotate)
    shift; cmd_rotate "$@" ;;
  doctor)
    shift; cmd_doctor "$@" ;;
  report)
    shift; cmd_report "$@" ;;
  deps-all)
    shift; cmd_deps_all "$@" ;;
  config-show)
    shift; cmd_config_show "$@" ;;
  help-en)
    print_usage ;;
  help-ru)
    print_usage_ru ;;
  help|--help|-h)
    print_usage_ru ;;
  *)
    echo "Unknown command: ${1:-}" >&2
    print_usage
    exit 1 ;;
esac


