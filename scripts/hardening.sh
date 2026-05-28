#!/usr/bin/env bash

set -Eeuo pipefail

# Criado com assistência do GitHub Copilot e revisado pelo Professor Max.
# Script de hardening para Ubuntu/Debian.
# Executa apenas com root, registra tudo em /var/log/hardening.log
# e verifica a presença de cada ferramenta antes de aplicar mudanças.

LOG_FILE="/var/log/hardening.log"
TIMESTAMP="$(date '+%F %T')"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Este script precisa ser executado como root."
    exit 1
fi

mkdir -p /var/log
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

# Redireciona toda a saida para o log e para o terminal.
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%F %T')] $*"
}

backup_file() {
    local file_path="$1"

    if [[ -f "$file_path" ]]; then
        cp -a "$file_path" "${file_path}.bak.$(date +%Y%m%d_%H%M%S)"
        log "Backup criado para $file_path"
    fi
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        log "Ferramenta ausente: $command_name. Pulando este bloco."
        return 1
    fi

    return 0
}

set_sshd_directive() {
    local file_path="$1"
    local directive="$2"
    local value="$3"

    if grep -Eq "^[[:space:]]*#?[[:space:]]*${directive}[[:space:]]+" "$file_path"; then
        sed -i -E "s|^[[:space:]]*#?[[:space:]]*${directive}[[:space:]]+.*|${directive} ${value}|" "$file_path"
    else
        echo "${directive} ${value}" >> "$file_path"
    fi
}

disable_service_if_present() {
    local service_name="$1"

    if systemctl list-unit-files "$service_name.service" >/dev/null 2>&1 || systemctl status "$service_name" >/dev/null 2>&1; then
        if systemctl is-active --quiet "$service_name"; then
            systemctl stop "$service_name"
            log "Servico parado: $service_name"
        fi

        if systemctl is-enabled --quiet "$service_name"; then
            systemctl disable "$service_name"
            log "Servico desabilitado: $service_name"
        fi
    else
        log "Servico nao encontrado: $service_name"
    fi
}

log "Iniciando hardening em $TIMESTAMP"

# -----------------------------------------------------------------------------
# SSH: desabilitar login root
# -----------------------------------------------------------------------------
if require_command sshd; then
    SSH_CONFIG="/etc/ssh/sshd_config"

    if [[ -f "$SSH_CONFIG" ]]; then
        backup_file "$SSH_CONFIG"
        set_sshd_directive "$SSH_CONFIG" "PermitRootLogin" "no"

        if sshd -t; then
            systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
            log "SSH ajustado: PermitRootLogin no"
        else
            log "Falha na validacao do SSH. Revertendo nao automatizado; revise o backup antes de aplicar."
        fi
    else
        log "Arquivo SSH nao encontrado em $SSH_CONFIG"
    fi
fi

# -----------------------------------------------------------------------------
# Fail2ban: endurecer protecao contra tentativas repetidas
# -----------------------------------------------------------------------------
if require_command fail2ban-client; then
    FAIL2BAN_JAIL="/etc/fail2ban/jail.local"

    mkdir -p /etc/fail2ban
    backup_file "$FAIL2BAN_JAIL"

    cat > "$FAIL2BAN_JAIL" <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
backend = systemd
EOF

    systemctl enable --now fail2ban 2>/dev/null || service fail2ban restart 2>/dev/null || true
    log "Fail2ban configurado em $FAIL2BAN_JAIL"
else
    log "Fail2ban nao instalado. Pulando configuracao."
fi

# -----------------------------------------------------------------------------
# /tmp: permissao segura com sticky bit
# -----------------------------------------------------------------------------
log "Aplicando permissao segura em /tmp"
chown root:root /tmp
chmod 1777 /tmp
stat -c 'Resultado /tmp: %A %U %G %n' /tmp

# -----------------------------------------------------------------------------
# Servicos desnecessarios: desligar apenas o que estiver presente
# -----------------------------------------------------------------------------
log "Desabilitando servicos nao essenciais, se existirem"
UNNECESSARY_SERVICES=(
    avahi-daemon
    bluetooth
    cups
    rpcbind
    modemmanager
)

for service_name in "${UNNECESSARY_SERVICES[@]}"; do
    disable_service_if_present "$service_name"
done

# -----------------------------------------------------------------------------
# auditd: regras basicas para monitorar arquivos de identidade e sudo
# -----------------------------------------------------------------------------
if require_command auditctl && require_command augenrules; then
    AUDIT_RULES="/etc/audit/rules.d/hardening.rules"

    mkdir -p /etc/audit/rules.d
    backup_file "$AUDIT_RULES"

    cat > "$AUDIT_RULES" <<'EOF'
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
-w /etc/ssh/sshd_config -p wa -k sshd_config
EOF

    augenrules --load 2>/dev/null || systemctl restart auditd 2>/dev/null || true
    log "auditd configurado com regras basicas em $AUDIT_RULES"
else
    log "auditd ou augenrules nao instalado. Pulando configuracao."
fi

log "Hardening concluido. Verifique o log em $LOG_FILE"