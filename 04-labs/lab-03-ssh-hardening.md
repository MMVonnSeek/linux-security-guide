[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Lab 03 — SSH Hardening

> **Módulo de referência:** [SSH Seguro](../03-hardening/ssh-seguro.md)  
> **Nível:** Intermediário  
> **Tempo estimado:** 55 minutos  
> **Requisitos:** Sistema Linux com acesso sudo, OpenSSH instalado

---

## Objetivo

Ao concluir este lab, você será capaz de:

- Auditar a configuração atual do SSH e identificar pontos fracos
- Gerar e implantar autenticação por chave pública Ed25519
- Aplicar hardening completo no `sshd_config`
- Configurar e validar o fail2ban para proteção contra força bruta
- Interpretar logs de autenticação SSH para identificar padrões de ataque

---

## Preparação do ambiente

```bash
# Verificar versão do OpenSSH instalada
ssh -V
sshd -V 2>&1 || sudo sshd -V

# Verificar status do serviço
sudo systemctl status sshd 2>/dev/null || sudo systemctl status ssh

# Backup da configuração atual — OBRIGATÓRIO antes de qualquer alteração
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.original
echo "Backup criado em /etc/ssh/sshd_config.original"

# Criar usuário de teste
sudo useradd -m -s /bin/bash usuario_lab
sudo echo "usuario_lab:senha_fraca_123" | sudo chpasswd
id usuario_lab
```

---

## Exercício 1 — Auditoria da configuração atual

**Objetivo:** identificar os problemas de segurança na configuração padrão antes de qualquer alteração.

```bash
# Ver configuração atual (apenas diretivas ativas, sem comentários)
sudo sshd -T | grep -E "^\
(port|protocol|permitrootlogin|passwordauthentication|\
challengeresponseauthentication|permitemptypasswords|\
x11forwarding|allowtcpforwarding|maxauthtries|\
logingracetime|kexalgorithms|ciphers|macs)" | sort
```

Para cada diretiva listada, classifique como: segura, aceitável ou insegura. Use a tabela abaixo como referência:

| Diretiva | Valor padrão comum | Status | Por quê |
|----------|--------------------|--------|---------|
| `permitrootlogin` | `yes` ou `prohibit-password` | Inseguro | Root não deve ser acessível via SSH |
| `passwordauthentication` | `yes` | Inseguro | Vulnerável a força bruta |
| `maxauthtries` | `6` | Aceitável | Ideal é 3 ou menos |
| `x11forwarding` | `yes` | Inseguro | Vetor de ataque se não utilizado |
| `logingracetime` | `120` | Inseguro | 120 segundos é longo demais |

```bash
# Verificar qual algoritmo de cifra está sendo negociado
ssh -vvv localhost exit 2>&1 | grep -E "kex:|cipher:|mac:" | head -10
```

---

## Exercício 2 — Autenticação por chave pública

**Objetivo:** configurar autenticação por chave Ed25519 e desabilitar autenticação por senha.

### Parte A — Gerando o par de chaves

```bash
# Gerar chave Ed25519 para o lab (sem sobrescrever chaves existentes)
ssh-keygen -t ed25519 -C "lab-ssh-hardening-$(date +%Y%m%d)" \
    -f ~/.ssh/id_ed25519_lab

# Inspecionar o que foi gerado
ls -la ~/.ssh/id_ed25519_lab*
echo "--- Chave publica ---"
cat ~/.ssh/id_ed25519_lab.pub
echo "--- Fingerprint ---"
ssh-keygen -l -f ~/.ssh/id_ed25519_lab.pub
```

Responda:
- Qual o tamanho da chave privada versus a pública em bytes?
- Por que o fingerprint é importante?

### Parte B — Implantando a chave no servidor de teste

```bash
# Configurar authorized_keys para o usuario_lab
sudo mkdir -p /home/usuario_lab/.ssh
cat ~/.ssh/id_ed25519_lab.pub | sudo tee /home/usuario_lab/.ssh/authorized_keys

# Permissões obrigatórias — SSH recusa funcionar com permissões incorretas
sudo chown -R usuario_lab:usuario_lab /home/usuario_lab/.ssh
sudo chmod 700 /home/usuario_lab/.ssh
sudo chmod 600 /home/usuario_lab/.ssh/authorized_keys

# Verificar
sudo ls -la /home/usuario_lab/.ssh/
```

### Parte C — Testando autenticação por chave

```bash
# Testar conexão com a chave (deve funcionar sem pedir senha)
ssh -i ~/.ssh/id_ed25519_lab -o PasswordAuthentication=no \
    usuario_lab@localhost echo "Autenticacao por chave funcionando"
```

<details>
<summary>Resultado esperado</summary>

```
Autenticacao por chave funcionando
```

Se pedir senha, verifique as permissões do diretório `.ssh` e do arquivo `authorized_keys`. O SSH é muito rigoroso com permissões — qualquer coisa mais permissiva que `700` no diretório ou `600` no arquivo causa falha silenciosa.
</details>

---

## Exercício 3 — Aplicando hardening no sshd_config

**Objetivo:** aplicar as configurações de segurança em etapas, testando após cada bloco de alterações.

### Parte A — Configurações críticas de autenticação

```bash
sudo nano /etc/ssh/sshd_config
```

Localize e altere (ou adicione) as seguintes diretivas:

```ini
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
PubkeyAuthentication yes
```

```bash
# Testar sintaxe ANTES de recarregar
sudo sshd -t && echo "Sintaxe OK" || echo "ERRO DE SINTAXE — nao recarregar"

# Recarregar mantendo sessão atual aberta
sudo systemctl reload sshd 2>/dev/null || sudo systemctl reload ssh

# Em novo terminal, confirmar que a chave ainda funciona
ssh -i ~/.ssh/id_ed25519_lab usuario_lab@localhost echo "Conexao pos-hardening OK"

# Confirmar que senha foi bloqueada
ssh -o PasswordAuthentication=yes -o PubkeyAuthentication=no \
    usuario_lab@localhost 2>&1 | grep -E "denied|refused|Permission"
```

### Parte B — Desabilitando funcionalidades desnecessárias

```bash
sudo nano /etc/ssh/sshd_config
```

Adicione ou ajuste:

```ini
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
MaxSessions 5
MaxStartups 10:30:60
ClientAliveInterval 300
ClientAliveCountMax 2
```

```bash
# Testar e recarregar
sudo sshd -t && sudo systemctl reload sshd 2>/dev/null || \
    sudo systemctl reload ssh
echo "Recarga OK"
```

### Parte C — Algoritmos criptográficos modernos

```bash
sudo nano /etc/ssh/sshd_config
```

Adicione:

```ini
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
```

```bash
# Testar sintaxe — algoritmos inválidos causam erro aqui
sudo sshd -t && echo "Algoritmos OK" || echo "Algoritmo invalido — verificar"

sudo systemctl reload sshd 2>/dev/null || sudo systemctl reload ssh

# Verificar quais algoritmos estão sendo negociados agora
ssh -vvv -i ~/.ssh/id_ed25519_lab usuario_lab@localhost exit 2>&1 | \
    grep -E "kex:|cipher:|mac:" | head -5
```

### Parte D — Controle de acesso e logging

```bash
# Criar grupo de acesso SSH
sudo groupadd ssh-users
sudo usermod -aG ssh-users usuario_lab
sudo usermod -aG ssh-users $USER

sudo nano /etc/ssh/sshd_config
```

Adicione:

```ini
AllowGroups ssh-users
LogLevel INFO
SyslogFacility AUTH
Banner /etc/ssh/banner.txt
```

```bash
# Criar banner
sudo tee /etc/ssh/banner.txt << 'EOF'
----------------------------------------------------------------------------
ACESSO RESTRITO E MONITORADO
Este sistema e de uso exclusivo de pessoal autorizado.
Todo acesso e registrado. Acesso nao autorizado e crime (Lei 12.737/2012).
----------------------------------------------------------------------------
EOF

sudo sshd -t && sudo systemctl reload sshd 2>/dev/null || \
    sudo systemctl reload ssh

# Testar — deve exibir o banner antes da autenticação
ssh -i ~/.ssh/id_ed25519_lab usuario_lab@localhost echo "Acesso com banner OK"
```

---

## Exercício 4 — Instalando e configurando fail2ban

**Objetivo:** configurar proteção automática contra força bruta.

```bash
# Instalar
sudo apt install fail2ban -y 2>/dev/null || sudo dnf install fail2ban -y

# Habilitar e iniciar
sudo systemctl enable --now fail2ban

# Verificar status
sudo fail2ban-client status
```

### Configurando a jail SSH

```bash
sudo tee /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 3
backend  = systemd
ignoreip = 127.0.0.1/8

[sshd]
enabled  = true
port     = ssh
filter   = sshd
maxretry = 3
bantime  = 86400
EOF

sudo systemctl reload fail2ban
sudo fail2ban-client status sshd
```

### Simulando e detectando força bruta

```bash
# Criar usuário sem chave para simular tentativas falhas
sudo useradd -m -s /bin/bash alvo_teste
sudo passwd -l alvo_teste    # bloquear senha mas manter conta

# Simular tentativas falhas (sem realmente ter a chave)
for i in $(seq 1 4); do
    ssh -o PasswordAuthentication=yes \
        -o PubkeyAuthentication=no \
        -o ConnectTimeout=3 \
        -o StrictHostKeyChecking=no \
        alvo_teste@localhost 2>&1 | grep -E "denied|refused" || true
    echo "Tentativa $i"
    sleep 1
done

# Verificar se o fail2ban agiu
sudo fail2ban-client status sshd

# Ver IPs banidos
sudo fail2ban-client get sshd banned
```

<details>
<summary>Resultado esperado</summary>

Após as tentativas, `sudo fail2ban-client status sshd` deve mostrar `Total banned: 1` e o IP `127.0.0.1` na lista de banidos (ou não, se estiver no `ignoreip`).

Se `127.0.0.1` estiver no `ignoreip`, remova-o temporariamente para o teste e depois restaure.
</details>

```bash
# Desbanir manualmente após o teste
sudo fail2ban-client set sshd unbanip 127.0.0.1 2>/dev/null || true

# Limpeza
sudo userdel -r alvo_teste
```

---

## Exercício 5 — Análise de logs de autenticação

**Objetivo:** identificar padrões de ataque nos logs do sistema.

```bash
# Verificar tentativas de autenticação das últimas horas
sudo journalctl -u sshd --since "1 hour ago" | grep -E "Failed|Accepted|Invalid"

# Contar tentativas falhas por IP
sudo journalctl -u sshd | grep "Failed password" | \
    grep -oP '(?<=from )\S+' | sort | uniq -c | sort -rn | head -10

# Contar tentativas com usuário inválido
sudo journalctl -u sshd | grep "Invalid user" | \
    awk '{print $8, $10}' | sort | uniq -c | sort -rn | head -10

# Verificar acessos bem-sucedidos
sudo journalctl -u sshd | grep "Accepted" | tail -20

# Verificar horários de pico de tentativas
sudo journalctl -u sshd | grep "Failed" | \
    awk '{print $1, $2, $3}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -10
```

### Interpretando os resultados

Para cada padrão encontrado, classifique:

| Padrão | Indicação |
|--------|-----------|
| Muitas tentativas com usuários diferentes (`admin`, `root`, `ubuntu`) | Varredura automatizada de credenciais padrão |
| Muitas tentativas do mesmo IP com o mesmo usuário | Ataque de dicionário direcionado |
| Tentativas em intervalos regulares (a cada 30s, 60s) | Ferramenta automatizada com throttling |
| Acessos bem-sucedidos em horário incomum | Possível comprometimento — investigar |

---

## Exercício 6 — Configuração do cliente SSH

**Objetivo:** configurar o arquivo `~/.ssh/config` para uso profissional.

```bash
cat > ~/.ssh/config << 'EOF'
# Configuracao padrao para todos os hosts
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    IdentitiesOnly yes
    AddKeysToAgent yes

# Servidor local de lab
Host lab-local
    HostName localhost
    User usuario_lab
    IdentityFile ~/.ssh/id_ed25519_lab
    Port 22
    ForwardAgent no

EOF

chmod 600 ~/.ssh/config

# Testar usando o alias configurado
ssh lab-local echo "Conexao via alias OK"
```

---

## Verificação final — Auditando o resultado do hardening

```bash
echo "=== AUDITORIA FINAL DO SSH ==="

echo -e "\n[1] Diretivas de segurança aplicadas:"
sudo sshd -T | grep -E "^\
(port|permitrootlogin|passwordauthentication|\
maxauthtries|logingracetime|x11forwarding|\
allowtcpforwarding|allowgroups)" | sort

echo -e "\n[2] Algoritmos em uso:"
sudo sshd -T | grep -E "^(kexalgorithms|ciphers|macs)" | \
    awk '{print $1": "substr($0,index($0,$2),40)"..."}'

echo -e "\n[3] Status do fail2ban:"
sudo fail2ban-client status sshd 2>/dev/null | grep -E "Currently banned|Total banned"

echo -e "\n[4] Ultimos acessos bem-sucedidos:"
sudo journalctl -u sshd | grep "Accepted" | tail -5

echo -e "\n[5] Chaves autorizadas configuradas:"
for user in $(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'); do
    home=$(getent passwd $user | cut -d: -f6)
    [ -f "$home/.ssh/authorized_keys" ] && \
        echo "$user: $(wc -l < $home/.ssh/authorized_keys) chave(s)"
done
```

---

## Limpeza do ambiente

```bash
# Remover usuário de teste
sudo userdel -r usuario_lab

# Remover chave de teste
rm -f ~/.ssh/id_ed25519_lab ~/.ssh/id_ed25519_lab.pub

# Remover alias do ssh config
sed -i '/# Servidor local de lab/,/ForwardAgent no/d' ~/.ssh/config

# Restaurar configuração original do SSH (opcional)
# sudo cp /etc/ssh/sshd_config.original /etc/ssh/sshd_config
# sudo systemctl reload sshd 2>/dev/null || sudo systemctl reload ssh
```

---

## Perguntas de revisão

1. Por que `PasswordAuthentication no` deve ser configurado apenas após confirmar que a autenticação por chave funciona?
2. Qual a vantagem da chave Ed25519 sobre RSA 2048?
3. O que acontece se o diretório `~/.ssh` tiver permissão `755` ao invés de `700`?
4. Por que o `fail2ban` usa `jail.local` ao invés de editar `jail.conf` diretamente?
5. O que `MaxStartups 10:30:60` significa? Qual ataque ele mitiga?

<details>
<summary>Respostas</summary>

1. Se a chave não funcionar e a senha já estiver desabilitada, você perde o acesso ao servidor remotamente. A sequência correta é: configurar chave → testar chave → desabilitar senha → testar que senha está bloqueada.

2. Ed25519 usa curvas elípticas e produz chaves menores (256 bits) com segurança equivalente ou superior a RSA 3072+. Operações são mais rápidas e o algoritmo é resistente a ataques de tempo. RSA 2048 ainda é considerado seguro mas Ed25519 é o padrão moderno recomendado.

3. O SSH recusa a chave. Permissões mais permissivas que `700` no diretório `.ssh` significam que outros usuários podem listar seu conteúdo, o que viola a segurança esperada. O daemon SSH implementa essa verificação explicitamente e falha silenciosamente (do ponto de vista do usuário).

4. `jail.conf` é sobrescrito em atualizações do pacote. `jail.local` sobrepõe as configurações do `jail.conf` e é preservado em atualizações. Editar `jail.conf` diretamente significa perder as configurações customizadas no próximo `apt upgrade`.

5. Aceita 10 conexões não autenticadas simultâneas sem restrição. A partir de 10, começa a descartar 30% das novas conexões não autenticadas. A partir de 60, descarta 100%. Mitiga ataques de exaustão de recursos onde um atacante abre muitas conexões simultaneamente para impedir logins legítimos (negação de serviço no SSH).
</details>

---

<div align="center">

**Lab anterior: [Lab 02 — Firewall](lab-02-firewall.md)**  
**Voltar ao inicio: [Repositório Principal](../../README.md)**

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-darkred?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-black?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

</div>