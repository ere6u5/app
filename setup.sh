#!/bin/bash

set -e

echo "🚀 MyApp Setup Script"

# Проверяем переменные окружения
if [ -z "$PROXY" ] || [ -z "$TOKEN" ] || [ -z "$ID" ]; then
    echo "❌ ERROR: Please set PROXY, TOKEN, and ID environment variables first"
    echo "   Add them to ~/.bashrc and run: source ~/.bashrc"
    exit 1
fi

APP_USER=$(whoami)
APP_HOME="/home/$APP_USER"
APP_DIR="$APP_HOME/myapp"

install_dependencies() {
    echo "📦 Installing dependencies..."
    sudo apt update
    sudo apt install -y python3 python3-pip wget
}

setup_app() {
    echo "🔧 Setting up application..."
    
    # Создаем директорию приложения
    mkdir -p $APP_DIR
    
    # Копируем файлы приложения
    cp app.py requirements.txt $APP_DIR/
    
    # Устанавливаем Python зависимости
    pip3 install -r $APP_DIR/requirements.txt
    
    echo "✅ Application setup completed"
}

setup_systemd() {
    echo "⚙️ Setting up systemd service..."
    
    # Копируем сервис файл с подстановкой пользователя
    sed "s/%i/$APP_USER/g" myapp.service > myapp_processed.service
    sudo cp myapp_processed.service /etc/systemd/system/myapp.service
    rm myapp_processed.service
    
    # Перечитываем systemd
    sudo systemctl daemon-reload
    sudo systemctl enable myapp
    
    echo "✅ Systemd service configured"
}

setup_frp() {
    echo "🔗 Setting up FRP..."
    
    # Скачиваем и устанавливаем frp
    wget -qO- https://gist.github.com/lawrenceching/41244a182307940cc15b45e3c4997346/raw/0576ea85d898c965c3137f7c38f9815e1233e0d1/install-frp-as-systemd-service.sh | sudo bash
    
    # Генерируем frpc.toml из шаблона
    envsubst < frpc.toml.template > frpc_generated.toml
    sudo cp frpc_generated.toml /etc/frp/frpc.toml
    rm frpc_generated.toml
    
    sudo systemctl enable frpc
    
    echo "✅ FRP configured"
}

start_services() {
    echo "🚀 Starting services..."
    
    sudo systemctl start myapp
    sudo systemctl start frpc
    
    echo "✅ Services started"
}

check_status() {
    echo ""
    echo "📊 === Service Status ==="
    sudo systemctl status myapp --no-pager -l || true
    echo ""
    echo "🔗 === FRP Status ==="
    sudo systemctl status frpc --no-pager -l || true
    echo ""
    echo "🌐 === Application URLs ==="
    echo "Local: http://localhost:8181"
    echo "External: http://app.${ID}.${PROXY}"
    echo ""
    echo "📝 === Useful Commands ==="
    echo "View app logs: journalctl -u myapp -f"
    echo "View frp logs: journalctl -u frpc -f"
    echo "Restart app: sudo systemctl restart myapp"
}

case "$1" in
    install)
        install_dependencies
        setup_app
        setup_systemd
        setup_frp
        start_services
        check_status
        ;;
    start)
        start_services
        check_status
        ;;
    stop)
        sudo systemctl stop myapp frpc
        echo "✅ Services stopped"
        ;;
    restart)
        sudo systemctl restart myapp frpc
        echo "✅ Services restarted"
        check_status
        ;;
    status)
        check_status
        ;;
    update)
        # Для обновления из репозитория
        setup_app
        sudo systemctl restart myapp
        echo "✅ Application updated and restarted"
        ;;
    *)
        echo "Usage: $0 {install|start|stop|restart|status|update}"
        echo ""
        echo "📋 Complete setup:"
        echo "1. Add variables to ~/.bashrc"
        echo "2. Run: source ~/.bashrc"  
        echo "3. Run: ./setup.sh install"
        exit 1
        ;;
esac
