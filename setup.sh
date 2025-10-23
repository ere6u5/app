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
SSH_DIR="$APP_HOME/.ssh"
GITHUB_KEY="$SSH_DIR/github_actions"

install_dependencies() {
    echo "📦 Installing dependencies..."
    sudo apt update
    sudo apt install -y python3 python3-pip wget git openssh-server
}

setup_ssh_for_github() {
    echo "🔑 Setting up SSH for GitHub Actions..."
    
    # Создаем .ssh директорию если нет
    mkdir -p $SSH_DIR
    chmod 700 $SSH_DIR
    
    # Генерируем SSH ключ если нет
    if [ ! -f "$GITHUB_KEY" ]; then
        echo "📝 Generating new SSH key for GitHub Actions..."
        ssh-keygen -t ed25519 -C "github-actions-$(hostname)" -f "$GITHUB_KEY" -N ""
        echo "✅ SSH key generated"
    else
        echo "✅ SSH key already exists"
    fi
    
    # Добавляем в authorized_keys
    if ! grep -q "$(cat ${GITHUB_KEY}.pub)" $SSH_DIR/authorized_keys 2>/dev/null; then
        cat ${GITHUB_KEY}.pub >> $SSH_DIR/authorized_keys
        echo "✅ Added to authorized_keys"
    fi
    
    # Настраиваем права
    chmod 600 $SSH_DIR/authorized_keys
    chmod 600 $GITHUB_KEY
    chmod 644 ${GITHUB_KEY}.pub
    
    # Показываем информацию для GitHub Secrets
    echo ""
    echo "📋 === GITHUB SECRETS SETUP ==="
    echo "Add these to your GitHub repository secrets:"
    echo ""
    echo "SERVER_HOST: $(hostname -I | awk '{print $1}')"
    echo "SERVER_USER: $APP_USER"
    echo "SERVER_SSH_KEY:"
    cat $GITHUB_KEY
    echo ""
    echo "📍 Save the above private key completely as SERVER_SSH_KEY secret"
}

setup_ssh_port() {
    echo "🔧 Configuring SSH port 2438..."
    
    # Убедимся что SSH сервер установлен и запущен
    if ! systemctl is-active --quiet ssh; then
        echo "🔄 Starting SSH server..."
        sudo systemctl enable ssh
        sudo systemctl start ssh
    fi
    
    # Проверяем текущую конфигурацию SSH
    if [ ! -f "/etc/ssh/sshd_config" ]; then
        echo "📁 Creating basic SSH config..."
        sudo mkdir -p /etc/ssh
        sudo tee /etc/ssh/sshd_config > /dev/null <<EOF
Port 22
Port 2438
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
        sudo systemctl restart ssh
        echo "✅ Basic SSH config created with port 2438"
        return
    fi
    
    # Если файл существует, добавляем порт
    if ! sudo grep -q "^Port 2438" /etc/ssh/sshd_config; then
        echo "🔄 Adding port 2438 to SSH config..."
        
        # Создаем backup
        sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
        
        # Добавляем порт 2438
        echo "Port 2438" | sudo tee -a /etc/ssh/sshd_config
        
        # Рестартуем SSH
        sudo systemctl restart ssh
        echo "✅ SSH port 2438 configured"
    else
        echo "✅ SSH port 2438 already configured"
    fi
    
    # Проверяем что порт слушается
    echo "🔍 Checking SSH ports..."
    sudo netstat -tlnp | grep sshd || echo "⚠️  SSHD not found in netstat"
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
    sudo systemctl status myapp --no-pager -l 2>/dev/null || echo "⚠️  myapp service not running"
    echo ""
    echo "🔗 === FRP Status ==="
    sudo systemctl status frpc --no-pager -l 2>/dev/null || echo "⚠️  frpc service not running"
    echo ""
    echo "🌐 === Application URLs ==="
    echo "Local: http://localhost:8181"
    echo "External: http://app.${ID}.${PROXY}"
    echo ""
    echo "🔑 === SSH Info ==="
    echo "SSH Host: $(hostname -I | awk '{print $1}')"
    echo "SSH Port: 2438"
    echo "SSH User: $APP_USER"
    echo ""
    echo "📝 === Useful Commands ==="
    echo "View app logs: journalctl -u myapp -f"
    echo "View frp logs: journalctl -u frpc -f"
    echo "Restart app: sudo systemctl restart myapp"
}

case "$1" in
    install)
        install_dependencies
        setup_ssh_for_github
        setup_ssh_port
        setup_app
        setup_systemd
        setup_frp
        start_services
        check_status
        ;;
    ssh-setup)
        setup_ssh_for_github
        setup_ssh_port
        ;;
    start)
        start_services
        check_status
        ;;
    stop)
        sudo systemctl stop myapp frpc 2>/dev/null || true
        echo "✅ Services stopped"
        ;;
    restart)
        sudo systemctl restart myapp frpc 2>/dev/null || true
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
        echo "Usage: $0 {install|ssh-setup|start|stop|restart|status|update}"
        echo ""
        echo "📋 Complete setup:"
        echo "1. Add variables to ~/.bashrc"
        echo "2. Run: source ~/.bashrc"  
        echo "3. Run: ./setup.sh install"
        echo ""
        echo "🔑 SSH setup only: ./setup.sh ssh-setup"
        exit 1
        ;;
esac
