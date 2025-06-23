#!/bin/bash

# Simple deployment script for the Proxy Generator static site with Nginx.
# This script is intended for Debian/Ubuntu based systems.

echo "Proxy Generator Deployment Script"
echo "---------------------------------"

# Check for root/sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите этот скрипт с правами sudo или от имени root."
  exit 1
fi

# --- Configuration ---
DEFAULT_DEPLOY_PATH="/var/www/proxy_generator"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
SITE_DIR_NAME="proxy_generator_site" # Name for the Nginx config file and site dir

# --- Helper Functions ---
confirm() {
    while true; do
        read -r -p "$1 [Y/n]: " response
        case "$response" in
            [yY][eE][sS]|[yY]|"") # Default to Yes
                return 0
                ;;
            [nN][oO]|[nN])
                return 1
                ;;
            *)
                echo "Пожалуйста, ответьте 'yes' или 'no'."
                ;;
        esac
    done
}

# --- Main Script ---

echo
echo "Шаг 1: Обновление списка пакетов..."
apt update -y || { echo "Ошибка при обновлении списка пакетов."; exit 1; }

echo
echo "Шаг 2: Проверка и установка Nginx..."
if ! command -v nginx &> /dev/null; then
    echo "Nginx не найден. Установка Nginx..."
    apt install -y nginx || { echo "Ошибка при установке Nginx."; exit 1; }
    systemctl enable nginx
    systemctl start nginx
    echo "Nginx успешно установлен и запущен."
else
    echo "Nginx уже установлен."
fi

echo
# Prompt for deployment path
read -r -p "Укажите путь для развертывания сайта (по умолчанию: $DEFAULT_DEPLOY_PATH): " DEPLOY_PATH
DEPLOY_PATH_EFFECTIVE="${DEPLOY_PATH:-$DEFAULT_DEPLOY_PATH}" # Use default if empty

# Update SITE_DIR_NAME based on the chosen path to keep config name relevant
SITE_CONFIG_NAME=$(basename "$DEPLOY_PATH_EFFECTIVE")

echo
echo "Шаг 3: Создание директории для сайта..."
if [ -d "$DEPLOY_PATH_EFFECTIVE" ]; then
    if ! confirm "Директория '$DEPLOY_PATH_EFFECTIVE' уже существует. Перезаписать её содержимое?"; then
        echo "Развертывание отменено пользователем."
        exit 0
    fi
    rm -rf "${DEPLOY_PATH_EFFECTIVE:?}"/* # Ensure we don't delete / if var is empty
else
    mkdir -p "$DEPLOY_PATH_EFFECTIVE" || { echo "Не удалось создать директорию '$DEPLOY_PATH_EFFECTIVE'."; exit 1; }
fi
echo "Сайт будет развернут в '$DEPLOY_PATH_EFFECTIVE'."

echo
echo "Шаг 4: Копирование файлов сайта..."
# Assuming the script is run from the root of the repository where 'site' directory exists
if [ ! -d "site" ]; then
    echo "Ошибка: Директория 'site' не найдена. Убедитесь, что скрипт запущен из корня репозитория."
    exit 1
fi
cp -r site/* "$DEPLOY_PATH_EFFECTIVE/" || { echo "Ошибка при копировании файлов сайта."; exit 1; }
echo "Файлы сайта скопированы."

echo
echo "Шаг 5: Создание конфигурационного файла Nginx..."

# Prompt for server name (domain or IP)
read -r -p "Введите имя сервера (домен или IP-адрес, например, example.com или ваш_ip): " SERVER_NAME
if [ -z "$SERVER_NAME" ]; then
    echo "Имя сервера не может быть пустым."
    exit 1
fi

# Prompt for listen port
DEFAULT_LISTEN_PORT="80"
read -r -p "Введите порт для прослушивания (по умолчанию: $DEFAULT_LISTEN_PORT): " LISTEN_PORT
LISTEN_PORT_EFFECTIVE="${LISTEN_PORT:-$DEFAULT_LISTEN_PORT}"


NGINX_CONFIG_FILE="$NGINX_SITES_AVAILABLE/$SITE_CONFIG_NAME"

# Create Nginx server block configuration
cat << EOF > "$NGINX_CONFIG_FILE"
server {
    listen $LISTEN_PORT_EFFECTIVE;
    listen [::]:$LISTEN_PORT_EFFECTIVE;

    server_name $SERVER_NAME;

    root $DEPLOY_PATH_EFFECTIVE;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Optional: Add logging settings if desired
    # access_log /var/log/nginx/${SITE_CONFIG_NAME}_access.log;
    # error_log /var/log/nginx/${SITE_CONFIG_NAME}_error.log;
}
EOF

echo "Конфигурационный файл Nginx создан: $NGINX_CONFIG_FILE"

echo
echo "Шаг 6: Активация сайта в Nginx..."
# Remove existing symlink if it points to a different config with the same name to avoid conflicts
if [ -L "$NGINX_SITES_ENABLED/$SITE_CONFIG_NAME" ]; then
    echo "Обнаружена существующая символическая ссылка для $SITE_CONFIG_NAME. Удаление..."
    rm "$NGINX_SITES_ENABLED/$SITE_CONFIG_NAME"
fi
ln -s "$NGINX_CONFIG_FILE" "$NGINX_SITES_ENABLED/" || { echo "Не удалось создать символическую ссылку для сайта Nginx."; exit 1; }
echo "Сайт активирован."

echo
echo "Шаг 7: Проверка конфигурации Nginx..."
nginx -t
if [ $? -ne 0 ]; then
    echo "Ошибка в конфигурации Nginx. Пожалуйста, проверьте вывод выше."
    echo "Вы можете найти конфигурационный файл здесь: $NGINX_CONFIG_FILE"
    exit 1
fi
echo "Конфигурация Nginx в порядке."

echo
echo "---------------------------------"
echo "Развертывание завершено!"
echo "---------------------------------"
echo
echo "Следующие шаги:"
echo "1. Если конфигурация Nginx прошла успешно, перезапустите Nginx, чтобы применить изменения:"
echo "   sudo systemctl restart nginx"
echo
echo "2. Убедитесь, что ваш брандмауэр (например, ufw) разрешает трафик на порт $LISTEN_PORT_EFFECTIVE."
echo "   Пример для ufw: sudo ufw allow $LISTEN_PORT_EFFECTIVE/tcp"
echo
echo "3. Откройте сайт в браузере по адресу: http://$SERVER_NAME:$LISTEN_PORT_EFFECTIVE"
echo "   (Если вы использовали порт 80, :$LISTEN_PORT_EFFECTIVE можно опустить: http://$SERVER_NAME)"
echo
echo "Напоминание: Этот инструмент генерирует строки конфигурации прокси. Он не создает и не запускает сами прокси-серверы."
echo

exit 0
