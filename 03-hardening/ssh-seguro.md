[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Módulo 03 — SSH Seguro

> **Pré-requisito:** [Análise de Tráfego](../02-redes/analise-trafico.md)  
> **Tempo estimado:** 55 minutos  
> **Distro testada:** Ubuntu 22.04 / RHEL 9 / Debian 12

---

## Por que SSH é a superfície de ataque mais explorada em servidores Linux

SSH é o protocolo de acesso remoto padrão em Linux. Por consequência, é o alvo número um de varreduras automatizadas na internet. Qualquer servidor com a porta 22 exposta recebe tentativas de autenticação por força bruta em questão de minutos após ser conectado à internet. A configuração padrão do OpenSSH é funcional, mas não é segura para ambientes de produção.

---

## 1. Como o SSH funciona — o que importa para segurança

### Handshake e troca de chaves

```
Cliente                          Servidor
   |                                 |
   |--- TCP SYN -------------------> |
   |<-- TCP SYN-ACK ---------------- |
   |--- TCP ACK -------------------> |
   |                                 |
   |<-- Banner (SSH-2.0-OpenSSH) --- |  ← versão exposta publicamente
   |                                 |
   |--- Key Exchange Init ---------> |  ← algoritmos suportados
   |<-- Key Exchange Reply --------- |  ← chave pública do servidor
   |                                 |
   |    [verificação da chave do servidor contra known_hosts]
   |                                 |
   |--- Diffie-Hellman -----------> |  ← segredo compartilhado
   |<-- Session Key estabelecida -- |
   |                                 |
   |--- Autenticação (chave/senha) > |
   |<-- Acesso concedido/negado ---- |
```

O fingerprint do servidor é armazenado em `~/.ssh/known_hosts` na primeira conexão. Se mudar em conexões futuras, o SSH alerta — isso pode indicar um ataque man-in-the-middle.

```bash
# Ver fingerprint do servidor atual
ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub

# Ver known_hosts do cliente
cat ~/.ssh/known_hosts

# Remover entrada específica de known_hosts
ssh-keygen -R hostname_ou_ip
```

---

## 2. Configuração do servidor — sshd_config

O arquivo principal é `/etc/ssh/sshd_config`. Sempre faça backup antes de editar e teste a sintaxe antes de recarregar.

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)
sudo nano /etc/ssh/sshd_config

# Testar sintaxe sem reiniciar
sudo sshd -t

# Recarregar após confirmar
sudo systemctl reload sshd
```

> **Regra crítica:** nunca feche a sessão SSH atual antes de confirmar que uma nova sessão abre com a configuração alterada. Mantenha sempre uma sessão de backup aberta durante alterações.

### Configurações essenciais de segurança

```ini
# --- Porta e protocolo ---

# Mudar a porta padrão reduz o volume de tentativas automatizadas
# Não é segurança real, mas reduz o ruído nos logs
Port 2222

# Forçar somente protocolo 2 (protocolo 1 é inseguro e obsoleto)
Protocol 2

# Interface específica para escutar (evitar escutar em todas)
ListenAddress 0.0.0.0


# --- Autenticação ---

# Desabilitar login como root via SSH — OBRIGATÓRIO
PermitRootLogin no

# Autenticação por senha: desabilitar após configurar chaves
PasswordAuthentication no

# Desabilitar autenticação por teclado interativo
ChallengeResponseAuthentication no

# Desabilitar autenticação por host (inseguro)
HostbasedAuthentication no

# Desabilitar senhas vazias — deve ser no por padrão, confirme
PermitEmptyPasswords no

# Número máximo de tentativas por conexão antes de desconectar
MaxAuthTries 3

# Tempo máximo para autenticar (segundos)
LoginGraceTime 30


# --- Sessão e acesso ---

# Número máximo de sessões simultâneas por conexão
MaxSessions 5

# Número máximo de conexões não autenticadas simultâneas
MaxStartups 10:30:60

# Desabilitar encaminhamento X11 se não for necessário
X11Forwarding no

# Desabilitar encaminhamento TCP se não for necessário
AllowTcpForwarding no

# Desabilitar agent forwarding se não for necessário
AllowAgentForwarding no

# Desabilitar túneis TUN/TAP
PermitTunnel no


# --- Algoritmos criptográficos (configuração moderna) ---

# Apenas algoritmos modernos e seguros
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512

# Apenas Ed25519 e RSA para chaves de host
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256


# --- Controle de acesso ---

# Permitir apenas usuários específicos
AllowUsers max deploy

# Ou apenas grupos específicos (prefira grupos — mais fácil de gerenciar)
AllowGroups ssh-users

# Negar usuários específicos (blacklist — menos recomendado que whitelist)
# DenyUsers usuario1 usuario2


# --- Logging ---

# Nível de log: INFO é suficiente para auditoria; VERBOSE para diagnóstico
LogLevel INFO

# Facility de syslog
SyslogFacility AUTH


# --- Keepalive ---

# Envia keepalive para detectar clientes desconectados
ClientAliveInterval 300
ClientAliveCountMax 2
# Resultado: sessão encerrada após 10 minutos sem resposta (300s * 2 + margem)


# --- Banner ---

# Exibe aviso legal antes da autenticação
Banner /etc/ssh/banner.txt
```

### Banner de aviso legal

```bash
sudo nano /etc/ssh/banner.txt
```

```
----------------------------------------------------------------------------
ACESSO RESTRITO E MONITORADO

Este sistema é de uso exclusivo de pessoal autorizado.
Todo acesso é registrado e monitorado.
O acesso não autorizado é crime conforme a Lei 12.737/2012.
----------------------------------------------------------------------------
```

---

## 3. Autenticação por chave pública

A autenticação por chave pública é significativamente mais segura que senha. Um par de chaves consiste em:

- **Chave privada** — fica no cliente, nunca deve sair da máquina do usuário
- **Chave pública** — copiada para o servidor, fica em `~/.ssh/authorized_keys`

### Gerando o par de chaves

```bash
# Ed25519 — algoritmo moderno, recomendado
ssh-keygen -t ed25519 -C "max@senai-taguatinga" -f ~/.ssh/id_ed25519

# RSA 4096 bits — para compatibilidade com sistemas mais antigos
ssh-keygen -t rsa -b 4096 -C "max@senai-taguatinga" -f ~/.ssh/id_rsa

# A passphrase protege a chave privada em caso de roubo do arquivo
# Sempre defina uma passphrase em chaves de produção
```

```bash
# Ver a chave pública gerada
cat ~/.ssh/id_ed25519.pub

# Conteúdo esperado:
# ssh-ed25519 AAAA...base64... max@senai-taguatinga
```

### Copiando a chave pública para o servidor

```bash
# Método automático (recomendado)
ssh-copy-id -i ~/.ssh/id_ed25519.pub usuario@servidor

# Método manual (quando ssh-copy-id não está disponível)
cat ~/.ssh/id_ed25519.pub | ssh usuario@servidor \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
     cat >> ~/.ssh/authorized_keys && \
     chmod 600 ~/.ssh/authorized_keys"
```

### Permissões corretas — obrigatório

O SSH recusa funcionar se as permissões estiverem incorretas:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_ed25519        # chave privada
chmod 644 ~/.ssh/id_ed25519.pub    # chave pública
chmod 644 ~/.ssh/known_hosts
chmod 600 ~/.ssh/config            # arquivo de configuração do cliente
```

### Configuração do cliente SSH (~/.ssh/config)

```bash
nano ~/.ssh/config
```

```ini
# Configuração padrão para todos os hosts
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    IdentitiesOnly yes

# Servidor de produção
Host prod-web
    HostName 203.0.113.10
    User deploy
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent no

# Servidor de desenvolvimento
Host dev
    HostName 192.168.1.100
    User max
    Port 22
    IdentityFile ~/.ssh/id_ed25519_dev

# Jump host (bastion)
Host interno
    HostName 10.0.0.50
    User max
    ProxyJump bastion

Host bastion
    HostName 203.0.113.5
    User max
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
```

Com esse arquivo configurado:

```bash
ssh prod-web        # equivale a: ssh -p 2222 -i ~/.ssh/id_ed25519 deploy@203.0.113.10
ssh interno         # passa automaticamente pelo bastion
```

---

## 4. fail2ban — bloqueio automático de força bruta

O `fail2ban` monitora logs do sistema e bloqueia IPs que excedem um número de tentativas de autenticação falhas em um período.

```bash
sudo apt install fail2ban -y
sudo systemctl enable --now fail2ban
```

### Configuração

Nunca edite `/etc/fail2ban/jail.conf` diretamente — ele é sobrescrito em atualizações. Crie um override:

```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
```

Configurações relevantes:

```ini
[DEFAULT]
# Tempo de banimento em segundos (3600 = 1 hora)
bantime = 3600

# Janela de tempo para contar tentativas (segundos)
findtime = 600

# Número de tentativas antes de banir
maxretry = 5

# IPs nunca banidos (sua rede administrativa)
ignoreip = 127.0.0.1/8 192.168.1.0/24

# Backend de monitoramento
backend = systemd

[sshd]
enabled = true
port = 2222          # ajustar se mudou a porta padrão
filter = sshd
logpath = %(sshd_log)s
maxretry = 3
bantime = 86400      # 24 horas para SSH especificamente
```

```bash
# Recarregar configuração
sudo systemctl reload fail2ban

# Ver status das jails ativas
sudo fail2ban-client status

# Ver status da jail SSH especificamente
sudo fail2ban-client status sshd

# Ver IPs banidos
sudo fail2ban-client get sshd banned

# Desbanir um IP manualmente
sudo fail2ban-client set sshd unbanip 192.168.1.50

# Testar se um filtro está funcionando
sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf
```

---

## 5. Restrições por usuário e grupo no sshd_config

```ini
# Permitir apenas membros do grupo ssh-users
AllowGroups ssh-users

# Regras específicas por usuário ou grupo com Match
Match User deploy
    AllowTcpForwarding yes
    X11Forwarding no
    ForceCommand /usr/bin/deploy-script.sh

Match Group sftp-only
    ForceCommand internal-sftp
    ChrootDirectory /var/sftp/%u
    AllowTcpForwarding no
    X11Forwarding no
```

Configurando o grupo e o diretório chroot para SFTP:

```bash
sudo groupadd sftp-only
sudo useradd -m -s /usr/sbin/nologin -G sftp-only joao-sftp
sudo mkdir -p /var/sftp/joao-sftp
sudo chown root:root /var/sftp/joao-sftp    # dono deve ser root para chroot
sudo chmod 755 /var/sftp/joao-sftp
sudo mkdir /var/sftp/joao-sftp/upload
sudo chown joao-sftp:joao-sftp /var/sftp/joao-sftp/upload
```

---

## 6. Auditando acessos SSH

```bash
# Últimos logins bem-sucedidos
last | grep -v "^$" | head -20

# Tentativas de login falhas
sudo lastb | head -20

# Log em tempo real de autenticação
sudo journalctl -u sshd -f

# Tentativas de força bruta nos logs
sudo journalctl -u sshd | grep "Failed password" | \
    awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -20

# IPs com mais tentativas falhas
sudo grep "Failed password" /var/log/auth.log | \
    grep -oP '(?<=from )\S+' | sort | uniq -c | sort -rn | head -20

# Verificar chaves autorizadas de todos os usuários
for user in $(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'); do
    home=$(getent passwd $user | cut -d: -f6)
    if [ -f "$home/.ssh/authorized_keys" ]; then
        echo "=== $user ==="
        cat "$home/.ssh/authorized_keys"
    fi
done
```

---

## 7. Configuração completa recomendada para produção

Arquivo `/etc/ssh/sshd_config` enxuto e seguro para servidor de produção:

```ini
# Porta e escuta
Port 2222
Protocol 2
ListenAddress 0.0.0.0

# Chaves de host (apenas algoritmos modernos)
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

# Algoritmos modernos
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# Autenticação
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Controle de acesso
AllowGroups ssh-users
MaxStartups 10:30:60
MaxSessions 5

# Funcionalidades desnecessárias desabilitadas
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
PrintMotd no

# Sessão
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
SyslogFacility AUTH
LogLevel INFO

# Banner
Banner /etc/ssh/banner.txt
```

---

## Lab — Coloque em prática

### Exercício 1 — Geração e configuração de chave

```bash
# 1. Gere um par de chaves Ed25519
ssh-keygen -t ed25519 -C "lab-teste" -f ~/.ssh/id_ed25519_lab

# 2. Verifique as permissões geradas automaticamente
ls -la ~/.ssh/id_ed25519_lab*

# 3. Inspecione a chave pública
cat ~/.ssh/id_ed25519_lab.pub

# 4. Calcule o fingerprint
ssh-keygen -l -f ~/.ssh/id_ed25519_lab.pub
```

Responda: qual a diferença de tamanho entre a chave privada e a pública? Por que a chave privada não deve ser copiada para o servidor?

---

### Exercício 2 — Hardening do sshd_config

Aplique as configurações de segurança em um servidor de teste e verifique cada uma:

```bash
# 1. Backup
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 2. Testar configuração atual
sudo sshd -t && echo "Sintaxe OK"

# 3. Aplicar alterações e testar novamente
# (editar o arquivo conforme seção 2)
sudo sshd -t && echo "Sintaxe OK após alterações"

# 4. Recarregar mantendo sessão atual aberta
sudo systemctl reload sshd

# 5. Em outro terminal, testar nova conexão ANTES de fechar a atual
ssh -p 2222 usuario@localhost
```

---

### Exercício 3 — Análise de tentativas de força bruta

```bash
# Verificar se há tentativas nos logs
sudo journalctl -u sshd | grep "Failed" | wc -l

# Identificar os 5 IPs com mais tentativas
sudo journalctl -u sshd | grep "Failed password" | \
    grep -oP '(?<=from )\S+' | sort | uniq -c | sort -rn | head -5

# Verificar se fail2ban está ativo e bloqueando
sudo fail2ban-client status sshd
```

<details>
<summary>O que analisar nos resultados</summary>

- Volume alto de tentativas de IPs externos indica que o servidor está sendo varrido
- IPs repetidos com alta frequência são candidatos para blocklist permanente no nftables
- Após configurar fail2ban, o número de tentativas por IP não deve ultrapassar o `maxretry` configurado
</details>

---

## Checklist de segurança — SSH

- [ ] `PermitRootLogin no`
- [ ] `PasswordAuthentication no` (após confirmar que a chave funciona)
- [ ] `MaxAuthTries 3` ou menor
- [ ] `LoginGraceTime 30` ou menor
- [ ] `AllowGroups` ou `AllowUsers` definido (whitelist de acesso)
- [ ] Porta padrão alterada de 22
- [ ] Algoritmos modernos configurados (Ed25519, ChaCha20, SHA-512)
- [ ] fail2ban instalado, ativo e configurado para SSH
- [ ] Banner de aviso legal configurado
- [ ] Chaves Ed25519 em uso — sem chaves RSA abaixo de 4096 bits
- [ ] `~/.ssh/authorized_keys` com permissão 600
- [ ] Revisão periódica das chaves autorizadas de todos os usuários
- [ ] `ClientAliveInterval` e `ClientAliveCountMax` configurados

---

## Referências

- `man sshd_config` / `man ssh_config` / `man ssh-keygen`
- [OpenSSH Security — mozilla.github.io](https://infosec.mozilla.org/guidelines/openssh)
- [fail2ban Documentation](https://www.fail2ban.org/wiki/index.php/MANUAL_0_8)
- [Red Hat — Using OpenSSH](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/securing_networks/assembly_using-secure-communications-between-two-systems-with-openssh_securing-networks)

---

<div align="center">

**Módulo anterior: [Análise de Tráfego](../02-redes/analise-trafico.md)**  
**Próximo módulo: [Auditoria de Logs](auditoria-logs.md)**

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-darkred?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-black?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

</div>