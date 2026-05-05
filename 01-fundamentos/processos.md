[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Módulo 01 — Gerenciamento de Processos no Linux

> **Pré-requisito:** [Permissões no Linux](permissoes.md)  
> **Tempo estimado:** 45 minutos  
> **Distro testada:** Ubuntu 22.04 / RHEL 9 / Debian 12

---

## Por que processos importam para segurança?

Todo ataque em execução é um processo. Saber listar, inspecionar e encerrar processos é a habilidade central de qualquer analista que responde a incidentes ou faz análise forense em sistemas Linux.

---

## 1. O que é um processo

Quando um programa é executado, o kernel cria um processo e atribui a ele:

- Um **PID** (Process ID) — identificador único
- Um **PPID** (Parent Process ID) — quem criou esse processo
- Um **UID/GID** — usuário e grupo sob os quais o processo roda
- Um **estado** — running, sleeping, stopped, zombie

```bash
# Todo processo tem um pai. O primeiro processo do sistema é o init/systemd (PID 1)
ps -p 1
```

---

## 2. Listando processos

### ps — fotografia do momento

```bash
ps aux                        # todos os processos, formato BSD
ps -ef                        # todos os processos, formato UNIX (mostra PPID)
ps aux --sort=-%cpu           # ordenado por CPU decrescente
ps aux --sort=-%mem           # ordenado por memória decrescente
ps -u www-data                # processos de um usuário específico
ps -p 1234                    # processo por PID específico
```

Colunas importantes do `ps aux`:

| Coluna | Significado |
|--------|-------------|
| USER | Usuário dono do processo |
| PID | ID do processo |
| %CPU | Uso de CPU |
| %MEM | Uso de memória |
| VSZ | Memória virtual alocada (KB) |
| RSS | Memória física em uso (KB) |
| STAT | Estado do processo |
| COMMAND | Comando que originou o processo |

### Estados do processo (coluna STAT)

| Estado | Significado |
|--------|-------------|
| R | Running — em execução ou na fila |
| S | Sleeping — aguardando evento |
| D | Uninterruptible sleep — aguardando I/O (não pode ser morto) |
| Z | Zombie — encerrado mas não coletado pelo pai |
| T | Stopped — pausado por sinal |
| < | Alta prioridade |
| N | Baixa prioridade (nice) |
| s | Líder de sessão |
| l | Multi-thread |
| + | Processo em foreground |

> **Ponto de segurança:** processos em estado `Z` (zombie) em grande número indicam problema no processo pai — pode ser sinal de comportamento anormal.

### top e htop — monitoramento em tempo real

```bash
top               # monitor padrão, atualiza a cada 3 segundos
top -u www-data   # filtra por usuário
top -p 1234,5678  # monitora PIDs específicos
```

Atalhos dentro do `top`:

| Tecla | Ação |
|-------|------|
| `P` | Ordena por CPU |
| `M` | Ordena por memória |
| `k` | Encerra processo (pede PID) |
| `r` | Altera prioridade (renice) |
| `u` | Filtra por usuário |
| `q` | Sai |

```bash
# htop é mais legível — instale se não tiver
apt install htop    # Debian/Ubuntu
dnf install htop    # RHEL/Fedora

htop
```

---

## 3. Árvore de processos

Visualizar a hierarquia pai-filho é fundamental para entender como processos foram iniciados — e detectar processos que não deveriam existir como filhos de determinados pais.

```bash
pstree                  # árvore completa
pstree -p               # inclui PIDs
pstree -u               # inclui usuários
pstree -p www-data      # árvore de um usuário específico
ps -ef --forest         # formato forest no ps
```

> **Ponto de segurança:** um processo `bash` sendo filho de `apache2` ou `nginx` é sinal claro de execução remota de código (RCE). Monitorar a árvore de processos é uma das técnicas de detecção mais eficazes.

---

## 4. Inspecionando processos em detalhe

### /proc — o sistema de arquivos de processos

Cada processo tem um diretório em `/proc/PID/` com informações completas em tempo real.

```bash
ls /proc/1234/              # estrutura do processo

cat /proc/1234/cmdline      # comando completo que iniciou o processo
cat /proc/1234/environ      # variáveis de ambiente do processo
cat /proc/1234/status       # estado, memória, UIDs
ls -la /proc/1234/fd/       # arquivos abertos pelo processo
cat /proc/1234/maps         # regiões de memória mapeadas
```

### lsof — arquivos abertos por processos

```bash
lsof -p 1234                # todos os arquivos abertos pelo PID 1234
lsof -u www-data            # arquivos abertos por um usuário
lsof -i :80                 # processo usando a porta 80
lsof -i TCP                 # todas as conexões TCP abertas
lsof /var/log/syslog        # quem está usando esse arquivo
```

### /proc/PID/maps — detectando injeção de código

```bash
# Regiões de memória com escrita E execução simultâneas são suspeitas
cat /proc/1234/maps | grep -E "rwx|r-x"
```

---

## 5. Sinais — comunicando com processos

Sinais são notificações enviadas a processos pelo kernel ou por outros processos.

```bash
kill -l                     # lista todos os sinais disponíveis
```

Sinais mais usados:

| Sinal | Número | Comportamento |
|-------|--------|---------------|
| SIGHUP | 1 | Recarrega configuração (sem encerrar) |
| SIGINT | 2 | Interrupção (equivale a Ctrl+C) |
| SIGKILL | 9 | Encerramento forçado — não pode ser ignorado |
| SIGTERM | 15 | Encerramento gracioso — padrão do `kill` |
| SIGSTOP | 19 | Pausa o processo — não pode ser ignorado |
| SIGCONT | 18 | Retoma processo pausado |

```bash
kill 1234                   # envia SIGTERM (15) — encerramento gracioso
kill -9 1234                # envia SIGKILL — encerramento forçado
kill -HUP 1234              # recarrega configuração (útil para nginx, sshd)
killall nginx               # encerra todos os processos com esse nome
pkill -u www-data           # encerra todos os processos de um usuário
```

> **Regra prática:** sempre tente `SIGTERM` antes de `SIGKILL`. O SIGTERM permite que o processo encerre de forma limpa (fecha arquivos, libera locks). O SIGKILL pode deixar arquivos corrompidos.

---

## 6. Prioridade de processos — nice e renice

O kernel usa valores de prioridade de `-20` (mais prioritário) a `19` (menos prioritário). O padrão é `0`.

```bash
nice -n 10 tar -czf backup.tar.gz /var/www    # inicia com prioridade baixa
renice -n 5 -p 1234                           # altera prioridade de processo existente
renice -n 10 -u backup                        # altera todos os processos de um usuário

# Ver prioridade atual
ps -o pid,ni,comm -p 1234
```

> Processos com prioridade alta consumindo CPU inesperadamente são indicativos de comportamento anormal — verifique com `ps aux --sort=-%cpu`.

---

## 7. Processos em background e foreground

```bash
comando &               # inicia processo em background
jobs                    # lista processos em background da sessão atual
fg %1                   # traz processo 1 para foreground
bg %1                   # envia processo pausado para background
Ctrl+Z                  # pausa processo em foreground (SIGSTOP)
Ctrl+C                  # encerra processo em foreground (SIGINT)

nohup comando &         # processo continua mesmo após fechar o terminal
disown %1               # desvincula processo do terminal atual
```

---

## 8. Monitoramento avançado

```bash
# Uso de recursos por processo em tempo real
pidstat 1               # atualiza a cada 1 segundo (pacote sysstat)
pidstat -u -p 1234 1    # CPU de um processo específico

# Histórico de chamadas do sistema
strace -p 1234          # intercepta syscalls em tempo real
strace -p 1234 -e trace=network   # filtra só chamadas de rede

# Bibliotecas carregadas por um processo
ldd /usr/bin/sshd
cat /proc/1234/maps | grep "\.so"
```

> **Ponto de segurança:** `strace` é uma ferramenta de análise forense poderosa. Em um sistema comprometido, verificar as syscalls de um processo suspeito pode revelar o que ele está fazendo sem precisar analisar o binário.

---

## 9. Identificando processos suspeitos

Sequência de investigação para um processo desconhecido:

```bash
# 1. Identificar o processo
ps aux | grep <nome_suspeito>

# 2. Ver o comando completo (pode diferir do nome exibido)
cat /proc/<PID>/cmdline | tr '\0' ' '

# 3. Ver o binário real (processo pode ter alterado seu nome)
ls -la /proc/<PID>/exe

# 4. Ver arquivos abertos e conexões de rede
lsof -p <PID>

# 5. Ver variáveis de ambiente
cat /proc/<PID>/environ | tr '\0' '\n'

# 6. Ver de onde foi iniciado (diretório de trabalho)
ls -la /proc/<PID>/cwd

# 7. Verificar hash do binário
md5sum /proc/<PID>/exe
sha256sum /proc/<PID>/exe
```

> **Ponto de segurança:** malwares frequentemente alteram o nome do processo para se camuflar como processos legítimos (ex: `kworker`, `systemd-udev`). Verificar `/proc/PID/exe` revela o binário real independente do nome exibido.

---

## Lab — Coloque em prática

### Preparação

```bash
# Instale as ferramentas necessárias
sudo apt install htop sysstat lsof procps -y
```

### Exercício 1 — Mapeamento de processos

Liste todos os processos em execução, ordene por consumo de memória e identifique os 5 que mais consomem. Para cada um, descubra: qual usuário o iniciou, qual o PID pai e há quanto tempo está rodando.

<details>
<summary>Ver gabarito</summary>

```bash
ps aux --sort=-%mem | head -6

# Para cada PID encontrado:
ps -o pid,ppid,user,etime,cmd -p <PID>
```
</details>

---

### Exercício 2 — Investigação de processo

Inicie um processo em background, inspecione seu diretório em `/proc` e encerre-o de forma gracioso.

```bash
# Inicie o processo
sleep 300 &

# Capture o PID
PID=$!
echo "PID: $PID"
```

Agora responda sem usar `ps`:
1. Qual o comando completo do processo?
2. Qual o estado atual?
3. Qual o PID pai?

<details>
<summary>Ver gabarito</summary>

```bash
cat /proc/$PID/cmdline | tr '\0' ' '
grep -E "^State|^PPid" /proc/$PID/status

# Encerramento gracioso
kill -15 $PID
```
</details>

---

### Exercício 3 — Simulação de triagem de incidente

Um processo com nome `python3` está consumindo CPU anormalmente. Faça a triagem completa para determinar se é legítimo ou suspeito.

```bash
# Simule o processo suspeito
python3 -c "while True: pass" &
PID=$!
```

Execute a sequência de investigação da seção 9 e documente cada achado.

<details>
<summary>Ver gabarito</summary>

```bash
cat /proc/$PID/cmdline | tr '\0' ' '
ls -la /proc/$PID/exe
lsof -p $PID
cat /proc/$PID/environ | tr '\0' '\n'
ls -la /proc/$PID/cwd

# Após análise, encerre
kill -9 $PID
```
</details>

---

## Checklist de segurança — processos

- [ ] Nenhum processo `bash` ou `sh` como filho de serviços web (apache, nginx, php-fpm)
- [ ] Processos rodando com o menor privilégio necessário (não como root)
- [ ] Nenhum processo com `/proc/PID/exe` apontando para `/tmp` ou `/dev/shm`
- [ ] Ausência de processos zumbi em quantidade elevada
- [ ] Processos de serviços críticos (sshd, cron) com PIDs estáveis entre reinicializações
- [ ] Binários de processos em execução com hash verificado contra baseline

---

## Referências

- `man ps` / `man kill` / `man proc`
- [The /proc Filesystem — kernel.org](https://www.kernel.org/doc/html/latest/filesystems/proc.html)
- [Linux Process States — Red Hat Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/)

---

<div align="center">

**Módulo anterior: [Permissões no Linux](permissoes.md)**  
**Próximo módulo: [Usuários e Grupos](usuarios-grupos.md)**

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-darkred?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-black?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

</div>