#!/bin/bash
# iostat_5min.sh
# Папка для логов
# LOGDIR=~/Logs
# mkdir -p "$LOGDIR"

# Файл CSV
LOGFILE="nvme0n1_iostat.csv"

# Если файл не существует, создаём заголовок
if [ ! -f "$LOGFILE" ]; then
    echo "Timestamp,Read_MB_s,Write_MB_s" > "$LOGFILE"
fi

# Бесконечный цикл
while true; do
    TS=$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}")

    # Берём статистику только для nvme0n1
    iostat -dx 1 1 | awk -v dev="nvme0n1" -v ts="$TS" '
    $1 == dev {printf "%s,%.2f,%.2f\n", ts, $3, $4}
    ' >> "$LOGFILE"

    sleep 300  # 5 минут
done