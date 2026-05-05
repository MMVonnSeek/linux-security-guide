[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Módulo 03 — Auditoria de Logs

> **Pré-requisito:** [SSH Seguro](ssh-seguro.md)  
> **Tempo estimado:** 55 minutos  
> **Distro testada:** Ubuntu 22.04 / RHEL 9 / Debian 12

---

## Por que logs são a base de qualquer investigação

Logs são o registro de tudo que aconteceu em um sistema. Em um incidente, eles respondem as perguntas fundamentais: quem acessou, quando, de onde, o que executou e o que foi alterado. Um sistema sem auditoria configurada adequadamente é um sistema que não pode ser investigado — e do ponto de vista de conformidade, um evento que não foi registrado, para todos os efeitos, não aconteceu.

---

## 1. Arquitetura de logs no Linux moderno

O Linux moderno opera com duas camadas de logging em paralelo:

```
Aplicações e serviços
        │
        ├──── syslog API (rsyslog / syslog-ng)
        │         └── /var/log/*.log  (arquivos de texto)
        │
        └──── journald (systemd)
                  └── /run/log/journal/  (binário, indexado)
```

O `journald` captura tudo que vai para stdout/stderr de serviços systemd, mensagens do kernel e eventos do sistema. O `rsyslog` recebe mensagens via syslog API e escreve em arquivos de texto tradicionais. Em muitas distribuições, os dois coexistem e o rsyslog consome do journald via socket.

---

## 2. journalctl — consultando o journal

### Consultas básicas

```bash
journalctl                          # todo o journal (mais antigo primeiro)
journalctl -r                       # ordem reversa (mais recente primeiro)
journalctl -f                       # modo follow (tempo real)
journalctl -n 50                    # últimas 50 entradas
journalctl -b                       # apenas o boot atual
journalctl -b -1                    # boot anterior
journalctl --list-boots             # lista todos os boots registrados
```

### Filtrando por serviço e unidade

```bash
journalctl -u sshd                  # logs do SSH
journalctl -u sshd -f               # SSH em tempo real
journalctl -u nginx -u php-fpm      # múltiplos serviços
journalctl -u sshd -n 100 -r        # últimas 100 entradas do SSH, mais recentes primeiro
```

### Filtrando por tempo

```bash
journalctl --since "2024-01-15 08:00:00"
journalctl --until "2024-01-15 18:00:00"
journalctl --since "2024-01-15 08:00:00" --until "2024-01-15 18:00:00"
journalctl --since "1 hour ago"
journalctl --since "yesterday"
journalctl --since today
```

### Filtrando por prioridade

```bash
journalctl -p err                   # apenas erros (err e acima)
journalctl -p warning               # warning e acima
journalctl -p debug                 # tudo incluindo debug

# Prioridades: emerg(0), alert(1), crit(2), err(3), warning(4), notice(5), info(6), debug(7)
```

### Filtrando por processo e PID

```bash
journalctl _PID=1234                # logs de um PID específico
journalctl _UID=1000                # logs de um UID específico
journalctl _COMM=sshd               # logs de um executável específico
journalctl _EXE=/usr/sbin/sshd     # caminho completo do executável
```

### Formato de saída

```bash
journalctl -u sshd -o json          # formato JSON (para parsing)
journalctl -u sshd -o json-pretty   # JSON formatado
journalctl -u sshd -o cat           # apenas a mensagem, sem metadados
journalctl -u sshd -o short-precise # timestamp preciso em microssegundos
journalctl -u sshd -o verbose       # todos os campos disponíveis
```

### Informações sobre o journal

```bash
journalctl --disk-usage             # espaço usado pelo journal
journalctl --verify                 # verifica integridade do journal
journalctl --vacuum-size=500M       # remove entradas antigas até atingir 500MB
journalctl --vacuum-time=30d        # remove entradas com mais de 30 dias
```

---

## 3. Arquivos de log tradicionais

Mesmo com o journald, muitos serviços ainda escrevem em `/var/log/`. Conhecer esses arquivos é necessário tanto para investigação quanto para configuração de SIEM.

| Arquivo | Conteúdo |
|---------|----------|
| `/var/log/auth.log` | Autenticação: SSH, sudo, su, PAM (Debian/Ubuntu) |
| `/var/log/secure` | Equivalente ao auth.log no RHEL/CentOS |
| `/var/log/syslog` | Mensagens gerais do sistema (Debian/Ubuntu) |
| `/var/log/messages` | Equivalente ao syslog no RHEL/CentOS |
| `/var/log/kern.log` | Mensagens do kernel |
| `/var/log/dpkg.log` | Instalações e remoções de pacotes (Debian/Ubuntu) |
| `/var/log/dnf.log` | Instalações e remoções de pacotes (RHEL/Fedora) |
| `/var/log/cron` | Execuções do cron |
| `/var/log/lastlog` | Último login de cada usuário (binário — use `lastlog`) |
| `/var/log/wtmp` | Histórico de logins (binário — use `last`) |
| `/var/log/btmp` | Tentativas de login falhas (binário — use `lastb`) |
| `/var/log/faillog` | Falhas de autenticação por PAM (binário — use `faillog`) |

### Leitura eficiente com grep e awk

```bash
# Todas as tentativas de autenticação falha de hoje
grep "Failed password" /var/log/auth.log | grep "$(date '+%b %e')"

# IPs com mais de 10 tentativas falhas
grep "Failed password" /var/log/auth.log | \
    grep -oP '(?<=from )\S+' | sort | uniq -c | sort -rn | awk '$1 > 10'

# Usuários que fizeram sudo hoje
grep "sudo" /var/log/auth.log | grep "$(date '+%b %e')" | grep "COMMAND"

# Comandos executados via sudo por um usuário específico
grep "sudo.*max.*COMMAND" /var/log/auth.log

# Logins bem-sucedidos nas últimas 24 horas
grep "Accepted" /var/log/auth.log | grep "$(date '+%b %e')"

# Pacotes instalados ou removidos hoje
grep "$(date '+%Y-%m-%d')" /var/log/dpkg.log | grep -E "install|remove|upgrade"
```

---

## 4. auditd — auditoria em nível de kernel

O `auditd` opera na camada do kernel e é capaz de registrar eventos que o syslog não captura: acesso a arquivos específicos, chamadas de sistema, alterações de configuração, execução de binários e muito mais. É o padrão exigido por frameworks de conformidade como PCI-DSS, SOC 2 e CIS Benchmark.

```bash
# Instalar
sudo apt install auditd audispd-plugins -y      # Debian/Ubuntu
sudo dnf install audit -y                        # RHEL/Fedora

# Habilitar e iniciar
sudo systemctl enable --now auditd

# Status
sudo auditctl -s
```

### Regras de auditoria

Regras são adicionadas via `auditctl` (temporário) ou no arquivo `/etc/audit/rules.d/` (persistente).

```bash
# Ver regras ativas
sudo auditctl -l

# Arquivo de regras persistentes
sudo nano /etc/audit/rules.d/hardening.rules
```

#### Regras essenciais para segurança

```bash
# Tornar as regras imutáveis até o próximo reboot (adicione por último)
# -e 2 impede que as regras sejam alteradas sem reiniciar
# Coloque esta linha SEMPRE no final do arquivo de regras

# --- Monitorar alterações em arquivos críticos de configuração ---
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege_escalation
-w /etc/sudoers.d/ -p wa -k privilege_escalation
-w /etc/ssh/sshd_config -p wa -k sshd_config

# --- Monitorar autenticação ---
-w /var/log/auth.log -p rwa -k auth_log
-w /var/log/secure -p rwa -k auth_log

# --- Monitorar execução de comandos privilegiados ---
-a always,exit -F arch=b64 -S execve -F euid=0 -k root_commands
-a always,exit -F arch=b32 -S execve -F euid=0 -k root_commands

# --- Monitorar uso de su e sudo ---
-w /bin/su -p x -k privilege_escalation
-w /usr/bin/sudo -p x -k privilege_escalation

# --- Monitorar modificações de rede ---
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k network_modifications
-w /etc/hosts -p wa -k network_modifications
-w /etc/resolv.conf -p wa -k network_modifications

# --- Monitorar carregamento de módulos do kernel ---
-w /sbin/insmod -p x -k kernel_modules
-w /sbin/rmmod -p x -k kernel_modules
-w /sbin/modprobe -p x -k kernel_modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k kernel_modules

# --- Monitorar arquivos temporários (vetor comum de malware) ---
-w /tmp -p x -k tmp_execution
-w /var/tmp -p x -k tmp_execution
-w /dev/shm -p x -k shm_execution

# --- Monitorar crontabs ---
-w /etc/cron.d/ -p wa -k cron_modification
-w /etc/cron.daily/ -p wa -k cron_modification
-w /etc/cron.hourly/ -p wa -k cron_modification
-w /etc/cron.weekly/ -p wa -k cron_modification
-w /etc/crontab -p wa -k cron_modification
-w /var/spool/cron/ -p wa -k cron_modification

# Tornar regras imutáveis (SEMPRE a última linha)
-e 2
```

```bash
# Aplicar regras sem reiniciar (exceto -e 2)
sudo augenrules --load

# Verificar se foram aplicadas
sudo auditctl -l
```

### Consultando logs de auditoria com ausearch

```bash
# Busca por chave (key) definida nas regras
sudo ausearch -k identity
sudo ausearch -k privilege_escalation
sudo ausearch -k root_commands

# Busca por usuário
sudo ausearch -ua 1000              # por UID
sudo ausearch -ua max               # por nome

# Busca por período
sudo ausearch --start today
sudo ausearch --start "01/15/2024 08:00:00" --end "01/15/2024 18:00:00"

# Busca por tipo de evento
sudo ausearch -m USER_LOGIN
sudo ausearch -m SYSCALL
sudo ausearch -m EXECVE

# Formato de saída legível
sudo ausearch -k identity -i         # -i interpreta UIDs e GIDs para nomes

# Exportar para análise
sudo ausearch -k root_commands -i --start today > /tmp/root_commands_hoje.txt
```

### Gerando relatórios com aureport

```bash
# Relatório resumido geral
sudo aureport

# Relatório de autenticação
sudo aureport -au

# Relatório de execuções
sudo aureport -x

# Relatório de falhas
sudo aureport --failed

# Relatório de anomalias
sudo aureport --anomaly

# Relatório de logins
sudo aureport -l

# Relatório para período específico
sudo aureport --start today --summary
```

---

## 5. rsyslog — centralização e filtragem de logs

O `rsyslog` permite centralizar logs de múltiplos servidores em um único ponto, filtrar mensagens e encaminhar para sistemas externos como SIEM.

```bash
sudo nano /etc/rsyslog.conf
```

### Configurações essenciais

```bash
# Garantir que auth.log receba todos os eventos de autenticação
auth,authpriv.*     /var/log/auth.log

# Separar logs do kernel
kern.*              /var/log/kern.log

# Reter todos os logs localmente
*.*                 /var/log/syslog

# Encaminhar para servidor syslog central (SIEM)
*.* @192.168.1.200:514      # UDP
*.* @@192.168.1.200:514     # TCP (mais confiável)
```

### Encaminhamento seguro com TLS

```bash
# Para encaminhar logs com TLS (evitar interceptação em trânsito)
sudo apt install rsyslog-gnutls

# /etc/rsyslog.conf
$DefaultNetstreamDriver gtls
$ActionSendStreamDriverMode 1
$ActionSendStreamDriverAuthMode x509/name
*.* @@logs.empresa.com:6514
```

---

## 6. Logrotate — gerenciamento de tamanho e retenção

```bash
cat /etc/logrotate.conf
ls /etc/logrotate.d/

# Exemplo de configuração para um serviço customizado
sudo nano /etc/logrotate.d/meu-servico
```

```
/var/log/meu-servico/*.log {
    daily
    rotate 90
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
    postrotate
        systemctl reload meu-servico > /dev/null 2>&1 || true
    endscript
}
```

```bash
# Testar configuração sem executar
sudo logrotate -d /etc/logrotate.d/meu-servico

# Forçar rotação imediatamente
sudo logrotate -f /etc/logrotate.conf
```

---

## 7. Detectando alteração ou remoção de logs

A primeira coisa que um atacante faz após comprometer um sistema é apagar os rastros. Detectar alteração de logs é parte da resposta a incidente.

```bash
# Verificar data de modificação dos logs principais
ls -la /var/log/auth.log /var/log/syslog /var/log/kern.log

# Verificar se o journal foi alterado
sudo journalctl --verify

# Verificar gaps no journal (períodos sem registro podem indicar remoção)
sudo journalctl --list-boots

# Checar integridade do auditd
sudo auditctl -s | grep enabled
# enabled = 2 significa que as regras estão imutáveis (configurado com -e 2)

# Monitorar o próprio diretório de logs com auditd
# (adicionar às regras de auditoria)
-w /var/log/ -p wa -k log_modification
```

---

## 8. Fluxo de investigação com logs

Sequência estruturada para investigar um evento suspeito usando logs:

```bash
# Passo 1: Definir a janela de tempo
# Identifique quando o evento suspeito possivelmente ocorreu

# Passo 2: Verificar logins na janela de tempo
sudo journalctl -u sshd --since "2024-01-15 00:00:00" --until "2024-01-16 00:00:00" | \
    grep -E "Accepted|Failed"

# Passo 3: Verificar comandos sudo executados
sudo ausearch -k privilege_escalation --start "01/15/2024 00:00:00" -i

# Passo 4: Verificar alterações em arquivos críticos
sudo ausearch -k identity --start "01/15/2024 00:00:00" -i

# Passo 5: Verificar execuções como root
sudo ausearch -k root_commands --start "01/15/2024 00:00:00" -i | \
    grep -E "EXECVE|PROCTITLE"

# Passo 6: Verificar instalações de pacotes
grep "2024-01-15" /var/log/dpkg.log | grep -E "install|remove"

# Passo 7: Verificar alterações em crontabs
sudo ausearch -k cron_modification --start "01/15/2024 00:00:00" -i

# Passo 8: Correlacionar com logs de rede
sudo journalctl -u nftables --since "2024-01-15 00:00:00"
sudo grep "2024-01-15" /var/log/syslog | grep "nftables"
```

---

## Lab — Coloque em prática

### Exercício 1 — Consulta estruturada ao journal

```bash
# 1. Quantas mensagens de nível erro ou superior foram geradas hoje?
sudo journalctl -p err --since today | wc -l

# 2. Quais serviços geraram erros críticos no último boot?
sudo journalctl -b -p crit -o cat

# 3. Liste os 5 serviços com mais entradas no journal hoje
sudo journalctl --since today -o json | \
    python3 -c "
import sys, json
from collections import Counter
units = [json.loads(l).get('_SYSTEMD_UNIT','unknown') for l in sys.stdin if l.strip()]
for unit, count in Counter(units).most_common(5):
    print(f'{count:6d}  {unit}')
"
```

---

### Exercício 2 — Configurando auditd

Configure e teste uma regra de auditoria para monitorar alterações no arquivo `/etc/hosts`:

```bash
# 1. Adicionar regra temporária
sudo auditctl -w /etc/hosts -p wa -k hosts_modification

# 2. Gerar um evento
echo "# teste de auditoria" | sudo tee -a /etc/hosts
sudo sed -i '/# teste de auditoria/d' /etc/hosts

# 3. Verificar o registro do evento
sudo ausearch -k hosts_modification -i

# 4. Ver o relatório de execuções relacionadas
sudo aureport -f | grep hosts
```

<details>
<summary>O que analisar na saída do ausearch</summary>

```
# A saída deve conter entradas similares a:
type=SYSCALL ... comm="tee" exe="/usr/bin/tee" key="hosts_modification"
type=PATH ... name="/etc/hosts" nametype=NORMAL

# Campos importantes:
# auid  — UID real do usuário que iniciou a sessão (persiste mesmo com sudo)
# uid   — UID efetivo no momento da chamada
# comm  — nome do processo
# exe   — caminho completo do executável
# key   — chave da regra que foi acionada
```
</details>

---

### Exercício 3 — Investigação dirigida

Simule e investigue um acesso privilegiado:

```bash
# 1. Execute alguns comandos como root
sudo ls /root
sudo cat /etc/shadow | head -3
sudo id

# 2. Aguarde alguns segundos e investigue
sudo ausearch -k root_commands --start "1 minute ago" -i

# 3. Gere o relatório de execuções
sudo aureport -x --start "1 minute ago"
```

Identifique: qual usuário executou os comandos, qual o UID efetivo e real, e qual o executável chamado em cada evento.

---

## Checklist de segurança — auditoria de logs

- [ ] `auditd` instalado, habilitado e em execução
- [ ] Regras de auditoria cobrindo arquivos de identidade (`/etc/passwd`, `/etc/shadow`, `/etc/sudoers`)
- [ ] Regras cobrindo execuções como root (`-F euid=0`)
- [ ] Regras cobrindo modificações em crontab
- [ ] Regras cobrindo execuções em `/tmp`, `/var/tmp` e `/dev/shm`
- [ ] Regras imutáveis configuradas (`-e 2`) como última linha
- [ ] Logs centralizados em servidor remoto (rsyslog com TLS)
- [ ] Retenção de logs configurada via logrotate (mínimo 90 dias)
- [ ] Journal do systemd com tamanho máximo configurado em `journald.conf`
- [ ] Diretório `/var/log/` monitorado pelo auditd contra modificações
- [ ] Procedimento de investigação documentado e testado

---

## Referências

- `man journalctl` / `man auditctl` / `man ausearch` / `man aureport`
- [Red Hat — Using the Linux Audit System](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/auditing-the-system_security-hardening)
- [CIS Benchmark — Logging and Auditing](https://www.cisecurity.org/cis-benchmarks)
- [auditd Rules — Linux Audit Documentation](https://github.com/linux-audit/audit-documentation)

---

<div align="center">

**Módulo anterior: [SSH Seguro](ssh-seguro.md)**  
**Próximo módulo: [Persistência via Cron](crontab-suspeito.md)**

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-darkred?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-black?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

</div>