#!/bin/bash
# Стресс-тестирование для RAM (LINUX)
sudo apt update
sudo apt install -y stress-ng

# Создание папки с логами
LOGDIR="$HOME/ram_stress_logs"
mkdir -p "$LOGDIR"

# Имя лог-файла с датой
LOGFILE="$LOGDIR/ram_stress_$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}").log"

# Длительность теста (в секундах) — например, 8 часов = 28800
DURATION=28800

# Определение общего объёма RAM
TOTAL_RAM=$(free -m | awk '/Mem:/ {print $2}')
# Нагружает 90% от доступной памяти
MEM_TO_USE=$((TOTAL_RAM * 90 / 100))

echo "Starting RAM stress test at $(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}")" | tee -a "$LOGFILE"
echo "Total RAM: ${TOTAL_RAM} MB, Allocating: ${MEM_TO_USE} MB" | tee -a "$LOGFILE"

# Запуск stress-ng в фоне и параллельный обратный отсчёт
sudo stress-ng --vm 1 --vm-bytes ${MEM_TO_USE}M --vm-hang 0 --timeout ${DURATION}s --metrics-brief 2>&1 | tee -a "$LOGFILE" &
STRESS_PID=$!
END_TIME=$(( $(date +%s) + DURATION ))
while kill -0 "$STRESS_PID" 2>/dev/null; do
  NOW=$(date +%s)
  REMAIN=$(( END_TIME - NOW ))
  [ $REMAIN -lt 0 ] && REMAIN=0
  H=$(( REMAIN / 3600 ))
  M=$(( (REMAIN % 3600) / 60 ))
  S=$(( REMAIN % 60 ))
  printf "\rRemaining: %02d:%02d:%02d" $H $M $S | tee -a "$LOGFILE" >/dev/null
  sleep 1
done
echo >> "$LOGFILE"

echo "RAM stress test finished at $(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}")" | tee -a "$LOGFILE"
