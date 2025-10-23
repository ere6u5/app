# MyApp Configuration
export PROXY="course.prafdin.ru"
export TOKEN="tokentoken"
export ID="prafdin"
export APP_ENV="production"

# MyApp Management Aliases
alias myapp-install='~/myapp/setup.sh install'
alias myapp-start='~/myapp/setup.sh start'
alias myapp-stop='~/myapp/setup.sh stop'
alias myapp-restart='~/myapp/setup.sh restart'
alias myapp-status='~/myapp/setup.sh status'
alias myapp-logs='journalctl -u myapp -f'
alias myapp-frp-logs='journalctl -u frpc -f'
alias myapp-update='cd ~/myapp && git pull && ./setup.sh update'
