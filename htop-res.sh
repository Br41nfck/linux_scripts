#!/bin/bash
# Вывод датчиков top, htop, sensors в формате HTML

sudo apt update
# sudo apt upgrade
sudo apt install -y aha
sudo apt install -y libsensors5

# Создание папки с логами
OUTDIR="$HOME/htop-res"
mkdir -p "$OUTDIR"

OUTFILE="$OUTDIR/htop-$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}").html"

(
  echo "--- top ---"
  /usr/bin/top -c -b -n 1
#  echo "--- htop ---"
#  /usr/bin/htop -b -C -d 10
  echo "--- sensors ---"
  /usr/bin/sensors
) | /usr/bin/aha --black --line-fix > "$OUTFILE"