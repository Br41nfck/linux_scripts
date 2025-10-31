#!/bin/bash
# monitor.sh — системный мониторинг CPU/GPU/RAM
# Логирование датчиков в табличном виде
# Создан: 09/09/2025

LOGDIR="$HOME/AutoTest_Logs/sysmonitor"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/sysmonitor.log"

# Добавляем заголовок при первом запуске
if [ ! -f "$LOGFILE" ]; then
    echo "Timestamp           | Top_Process  | CPU_Freq  | CPU_Temp | CPU_Load | GPU_Freq | GPU_Temp | RAM_Used | RAM_Total | RAM_Free | Net_If | Net_Link | Net_RxB | Net_TxB | NVMe_Temp | NVMe_Err | Disk_Health" >> "$LOGFILE"
    echo "--------------------+--------------+-----------+----------+----------+----------+----------+----------+-----------+---------+--------+----------+---------+---------+-----------+----------+------------" >> "$LOGFILE"
fi

# Метка времени
timestamp=$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}")

# Наиболее нагруженный процесс
top_process=$(ps -eo comm,pcpu --sort=-pcpu | head -n2 | tail -n1 | awk '{print $1}')

# CPU
cpu_freq=$(lscpu | awk -F: '/MHz/ {printf "%d MHz", $2; exit}')
cpu_temp=$(sensors 2>/dev/null | awk '/^Package id 0:/ {gsub("\\+",""); printf "%d°C", $4; exit}')
if [ -z "$cpu_temp" ]; then
    cpu_temp=$(sensors 2>/dev/null | awk '/^Core 0:/ {gsub("\\+",""); printf "%d°C", $2; exit}')
fi
[ -z "$cpu_temp" ] && cpu_temp="N/A"
cpu_load=$(top -bn2 -d 0.5 | grep "Cpu(s)" | tail -n1 | awk '{print 100 - $8 "%"}')

# GPU
if command -v nvidia-smi >/dev/null 2>&1; then
    gpu_freq=$(nvidia-smi --query-gpu=clocks.sm --format=csv,noheader,nounits | head -1)
    gpu_freq="${gpu_freq} MHz"
    gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -1)
    gpu_temp="${gpu_temp}°C"
    gpu_mem_clock=$(nvidia-smi --query-gpu=clocks.mem --format=csv,noheader,nounits | head -1)
    gpu_mem_clock="${gpu_mem_clock} MHz"
    read gpu_mem_used gpu_mem_total <<< $(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | head -1 | tr ',' ' ')
    gpu_mem_used="${gpu_mem_used} MiB"
    gpu_mem_total="${gpu_mem_total} MiB"
elif command -v radeontop >/dev/null 2>&1; then
    gpu_freq="N/A"
    gpu_temp=$(sensors 2>/dev/null | awk '/edge:/ {gsub("\\+",""); printf "%d°C", $2; exit}')
    gpu_mem_clock="N/A"; gpu_mem_used="N/A"; gpu_mem_total="N/A"
else
    gpu_freq="N/A"
    gpu_temp="N/A"
    gpu_mem_clock="N/A"; gpu_mem_used="N/A"; gpu_mem_total="N/A"
fi

# RAM
read mem_total mem_used mem_free <<< $(free -m | awk 'NR==2 {print $2, $3, $4}')
mem_used="${mem_used} MB"
mem_total="${mem_total} MB"
mem_free="${mem_free} MB"

# Network (primary interface)
net_if=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
if [ -n "$net_if" ] && [ -d "/sys/class/net/$net_if" ]; then
  link_carrier=$(cat "/sys/class/net/$net_if/carrier" 2>/dev/null)
  if [ "$link_carrier" = "1" ]; then net_link="UP"; else net_link="DOWN"; fi
  rx_b=$(cat "/sys/class/net/$net_if/statistics/rx_bytes" 2>/dev/null)
  tx_b=$(cat "/sys/class/net/$net_if/statistics/tx_bytes" 2>/dev/null)
else
  net_if="N/A"; net_link="N/A"; rx_b="N/A"; tx_b="N/A"
fi

# NVMe SMART (first nvme namespace)
nvme_temp="N/A"; nvme_err="N/A"
if command -v nvme >/dev/null 2>&1; then
  nvme_dev=$(ls /dev/nvme*n1 2>/dev/null | head -n1)
  if [ -n "$nvme_dev" ]; then
    nvme_temp=$(nvme smart-log "$nvme_dev" 2>/dev/null | awk -F':' '/^temperature/ {gsub(/[^0-9]/, "", $2); print $2" C"; exit}')
    [ -z "$nvme_temp" ] && nvme_temp="N/A"
    nvme_err=$(nvme smart-log "$nvme_dev" 2>/dev/null | awk -F':' '/media_errors/ {gsub(/[^0-9]/, "", $2); print $2; exit}')
    [ -z "$nvme_err" ] && nvme_err="N/A"
  fi
fi

# SMART (first SATA/SAS disk)
disk_health="N/A"
if command -v smartctl >/dev/null 2>&1; then
  disk_dev=$(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print "/dev/"$1; exit}')
  if [ -n "$disk_dev" ]; then
    disk_health=$(smartctl -H "$disk_dev" 2>/dev/null | awk -F': ' '/overall-health/{print $2}' )
    [ -z "$disk_health" ] && disk_health=$(smartctl -H "$disk_dev" 2>/dev/null | grep -qi PASSED && echo PASSED || echo UNKNOWN)
  fi
fi

# Запись строки в лог
printf "%-19s | %-12s | %-8s | %-8s | %-8s | %-8s | %-8s | %-10s | %-10s | %-8s | %-6s | %-8s | %-7s | %-7s | %-9s | %-8s | %-10s\n" \
  "$timestamp" "$top_process" "$cpu_freq" "$cpu_temp" "$cpu_load" "$gpu_freq" "$gpu_temp" "$gpu_mem_clock" "$gpu_mem_used" "$gpu_mem_total" "$net_if" "$net_link" "$rx_b" "$tx_b" "$nvme_temp" "$nvme_err" "$disk_health" >> "$LOGFILE"
