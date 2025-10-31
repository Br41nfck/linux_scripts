#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

LOG_DIR="$HOME/AutoTest_Logs"
GPU_LOG_DIR="$HOME/gpu_burn_logs"
ARCHIVE_DIR="$HOME/AutoTest_Archives"
UNIT_DIR="$HOME/.config/systemd/user"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE" || true
  LOG_DIR="${AUTOTEST_LOG_DIR:-$LOG_DIR}"
  GPU_LOG_DIR="${AUTOTEST_GPU_LOG_DIR:-$GPU_LOG_DIR}"
  ARCHIVE_DIR="${AUTOTEST_ARCHIVE_DIR:-$ARCHIVE_DIR}"
fi

info() { echo "[INFO] $(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}") - $*"; }
warn() { echo "[WARN] $*"; }

confirm() {
  if [ "${1:-}" = "--yes" ] || [ "${DELETE_ALL_CONFIRM:-}" = "YES" ]; then
    return 0
  fi
  echo "Эта операция удалит логи, отчёты, таймеры/cron и ПО, установленное autotest."
  read -r -p "Продолжить? Введите YES: " ans
  [ "$ans" = "YES" ]
}

have_systemd() {
  command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]
}

remove_systemd_units() {
  if have_systemd; then
    info "Отключаю systemd user timers"
    systemctl --user disable --now autotest-monitor-once.timer 2>/dev/null || true
    systemctl --user disable --now autotest-htop-snapshot.timer 2>/dev/null || true
    rm -f "$UNIT_DIR/autotest-monitor-once.timer" \
          "$UNIT_DIR/autotest-monitor-once.service" \
          "$UNIT_DIR/autotest-htop-snapshot.timer" \
          "$UNIT_DIR/autotest-htop-snapshot.service" || true
    systemctl --user daemon-reload || true
  fi
}

remove_cron() {
  info "Удаляю cron-задания autotest"
  crontab -l 2>/dev/null | grep -v "autotest " | crontab - || true
}

stop_gpu_burn() {
  local pidfile="$HOME/gpu_burn_logs/gpu_burn.pid"
  if [ -f "$pidfile" ]; then
    local pid
    pid=$(cat "$pidfile" 2>/dev/null || true)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      info "Останавливаю gpu_burn (pid=$pid)"
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
}

purge_packages() {
  info "Удаляю пакеты apt, установленные autotest"
  sudo apt purge -y htop stress-ng tmux mc aha sysstat lm-sensors memtester fio iperf3 smartmontools nvme-cli nvidia-utils-535 2>/dev/null || true
  sudo apt autoremove -y || true
}

pip_uninstall() {
  info "Удаляю python-пакеты (пользовательские)"
  python3 -m pip uninstall -y pandas openpyxl 2>/dev/null || true
}

remove_files() {
  info "Удаляю логи и отчёты"
  rm -rf "$LOG_DIR" "$GPU_LOG_DIR" "$ARCHIVE_DIR" 2>/dev/null || true
  rm -rf "$HOME/htop-res" "$HOME/ram_stress_logs" 2>/dev/null || true

  info "Удаляю gpu_burn и исходники"
  rm -f "$SCRIPT_DIR/gpu_burn" 2>/dev/null || true
  rm -rf "$SCRIPT_DIR/gpu-burn-src" 2>/dev/null || true

  # Удалить лого/пасс SMB только если это тестовый шаблон
  local cred="$HOME/.smbcredentials"
  if [ -f "$cred" ] && grep -q "username=admin" "$cred" && grep -q "password=ABC123abc" "$cred"; then
    info "Удаляю тестовый $cred"
    rm -f "$cred" || true
  fi
}

main() {
  if ! confirm "${1:-}"; then
    warn "Отменено пользователем"
    exit 1
  fi
  stop_gpu_burn
  remove_systemd_units
  remove_cron
  remove_files
  purge_packages
  pip_uninstall
  info "Готово."
}

main "$@"


