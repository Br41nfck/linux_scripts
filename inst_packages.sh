#!/bin/bash
# Имя скрипта: inst_packages.sh
# Дата: 04/09/2025

# Переменные
SCRIPTS_DIR="$HOME/AutoTest_Scripts"
LOGS_DIR="$HOME/AutoTest_Logs"

# Обновление пакетов
sudo apt update
# Установка пакетов
sudo apt install -y vim nano htop stress-ng openssh-server tmux mc git smbclient cifs-utils libsensors5 aha

#vim			# расширяемый текстовый редактор 
#nano			# простой текстовый редактор
#htop			# просмотр активности процессов
#atop			# более простой вариант
#stress-ng 		# stress benchmark для железа
#ssh 			# Secure SHell
#tmux			# Терминальный мультиплексор (C-b " - split horizontal)
#mc				# Midnight Commander (консольный Total Commander)
#git 			# Поддержка git (for clone, push, commit, etc.)
#smbclient		# Поддержка SMB-протокола
#cifs-utils		# Работа с общими папками для Windows/Linux
#libsensors5	# Для поддержки датчиков температур

# gpu-burn - stress-test for GPU
# ТРЕБУЕТСЯ: Nvidia CUDA Toolkit
# sudo apt install -y nvidia-cuda-toolkit nvidia-smi
# sudo git clone https://github.com/wilicc/gpu-burn.git

# Проверка SSH
if systemctl is-active --quiet ssh; then
    echo "SSH уже запущен."
else
    echo "SSH не работает. Запускаю..."
    sudo systemctl restart ssh
    if systemctl is-active --quiet ssh; then
        echo "SSH успешно запущен."
    else
        echo "Не удалось запустить SSH!"
        exit 1
    fi
fi

# Показать IP
IP=$(hostname -I | awk '{print $1}')
echo "Подключиться можно по адресу: ssh $(whoami)@$IP"


echo "Копирование скриптов через CIFS..."
sudo apt install -y cifs-utils

# Монтируем шару

CRED_FILE="$HOME/.smbcredentials"
echo "username=admin" > "$CRED_FILE"
echo "password=ABC123abc" >> "$CRED_FILE"
chmod 600 "$CRED_FILE"
sudo mkdir -p /mnt/smb_share
if sudo mount -t cifs //192.168.10.15/smb /mnt/smb_share -o credentials=$CRED_FILE,vers=3.0; then
    if [ -d /mnt/smb_share/_AutoTest_NEW/linux_scripts ]; then
        mkdir -p "$SCRIPTS_DIR"
        cp -r /mnt/smb_share/_AutoTest_NEW/linux_scripts/* "$SCRIPTS_DIR/"
        chmod -R +x "$SCRIPTS_DIR"
        echo "Скрипты скопированы!"
    else
        echo "Папка linux_scripts не найдена!"
    fi
    sudo umount /mnt/smb_share
else
    echo "Не удалось подключить SMB-шару!"
fi


# Создаем папку для логов
mkdir -p "$LOGS_DIR"

echo "Настройка crontab для AutoTest (autotest.sh)..."

# Папка со скриптами и логи

# Добавляем в crontab (каждые 5 минут)
AUTOTEST="$SCRIPTS_DIR/autotest.sh"
mkdir -p "$LOGS_DIR"
CRON_MONITOR="*/5 * * * * /bin/bash $AUTOTEST monitor-once >> $LOGS_DIR/monitor-once.log 2>&1"
CRON_HTOP="*/5 * * * * /bin/bash $AUTOTEST htop-snapshot >> $LOGS_DIR/htop-snapshot.log 2>&1"

# Добавить, если нет
(crontab -l 2>/dev/null | grep -F "autotest monitor-once") || (crontab -l 2>/dev/null; echo "$CRON_MONITOR") | crontab -
(crontab -l 2>/dev/null | grep -F "autotest htop-snapshot") || (crontab -l 2>/dev/null; echo "$CRON_HTOP") | crontab -

echo "Задания autotest добавлены в crontab"

# Мгновенный запуск в фоне
/bin/bash "$AUTOTEST" monitor-once >> "$LOGS_DIR/monitor-once.log" 2>&1 &
/bin/bash "$AUTOTEST" htop-snapshot >> "$LOGS_DIR/htop-snapshot.log" 2>&1 &
echo "Задания autotest запущены в фоне."