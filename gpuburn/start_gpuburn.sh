# Скрипт запуска GPU-BURN 
#!/bin/bash

# Длительность теста в секундах 
# 1 час=3600 
# 4 часа=14400 
# 8 часов=28800 
# 12 часов=43200 
# 24 часа=86400 
# 48 часов=172800 
TEST_DURATION=3600

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # без цвета

# Ссылки
GPU_BURN_LINK="https://github.com/wilicc/gpu-burn.git"
NVIDIA_DRIVER_LINK="nvidia-driver-580-open"
CUDA_LINK="nvidia-cuda-toolkit"

# Папка с логами
LOGDIR="$HOME/gpu_burn_logs"
mkdir -p "$LOGDIR"

# Лог-файлы с датой
GPU_BURN_LOGFILE="$LOGDIR/gpu_burn_$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}").log"
NVIDIA_SMI_LOGFILE="$LOGDIR/nvidia-smi_$(date +"${AUTOTEST_FORMAT_DATE:-%d-%m-%Y %H:%M:%S}").log"

# Формат даты и времени
DATE_FORMAT="+%d-%m-%Y %H:%M:%S"

# Интервал логирования
INTERVAL=10

# Проверка наличия gpu_burn
if ! command -v ./gpu_burn &> /dev/null; then
    echo -e "${RED}Ошибка: gpu_burn не найден.${NC}\nЗагрузите при помощи команды:\n git clone $GPU_BURN_LINK\nИ внесите изменения по инструкции SETUP_GPU_BURN.md или SETUP_GPU_BURN.pdf"
    exit 1
fi

# Проверка наличия nvidia-smi
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${RED}Ошибка: nvidia-smi не найден.${NC}\nУстановите драйвера NVIDIA при помощи команды:\n sudo apt install $NVIDIA_DRIVER_LINK"
    exit 1
fi

# Проверка наличия CUDA
if ! command -v nvcc &> /dev/null; then
    echo -e "${RED}Ошибка: nvidia-cuda-toolkit не найден.${NC}\nУстановите при помощи команды:\n sudo apt install $CUDA_LINK"
    exit 1
fi

# Определение доступных GPU (индексы)
GPU_INDICES_STR=$(nvidia-smi --query-gpu=index --format=csv,noheader 2>/dev/null | tr -d '\r')
if [ -z "$GPU_INDICES_STR" ]; then
    echo -e "${RED}Ошибка: не удалось определить видеокарты через nvidia-smi.${NC}"
    exit 1
fi

# Формируем список GPU для gpu_burn
readarray -t GPU_INDICES < <(echo "$GPU_INDICES_STR")
echo -e "${GREEN}Обнаружены GPU: ${GPU_INDICES[*]}${NC}"

# Запуск gpu_burn на всех обнаруженных GPU
nohup ./gpu_burn "$TEST_DURATION" ${GPU_INDICES[@]} > "$GPU_BURN_LOGFILE" 2>&1 &
GPU_BURN_PID=$!
echo $GPU_BURN_PID > "$LOGDIR/gpu_burn.pid"
echo -e "${GREEN}Запущен gpu_burn с PID $GPU_BURN_PID${NC}"

# Логирование nvidia-smi
(
    while kill -0 $GPU_BURN_PID 2>/dev/null; do
        nvidia-smi
        sleep $INTERVAL
    done
) >> "$NVIDIA_SMI_LOGFILE" 2>&1 &
NVIDIA_SMI_PID=$!
echo -e "${GREEN}Запущено логирование nvidia-smi с PID $NVIDIA_SMI_PID${NC}"

# Обратный отсчёт в консоли
(
    END_TIME=$(( $(date +%s) + TEST_DURATION ))
    while kill -0 $GPU_BURN_PID 2>/dev/null; do
        NOW=$(date +%s)
        REMAIN=$(( END_TIME - NOW ))
        H=$(( REMAIN / 3600 ))
        M=$(( (REMAIN % 3600) / 60 ))
        S=$(( REMAIN % 60 ))
        printf "\r${YELLOW}Осталось: %02dч %02dм %02dс${NC}" $H $M $S
        sleep 1
    done
    echo -e "\n${GREEN}Тест gpu_burn завершён.${NC}"
) &