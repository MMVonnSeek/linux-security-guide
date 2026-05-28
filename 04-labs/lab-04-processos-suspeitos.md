[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

> Lab criado com assistência do GitHub Copilot e revisado em sala de aula.

---

# Lab 04 — Detecção de Processos Suspeitos no Linux

> **Módulo de referência:** [Processos no Linux](../01-fundamentos/processos.md)  
> **Nível:** Intermediário  
> **Tempo estimado:** 50 minutos  
> **Requisitos:** Sistema Linux com acesso sudo, `ps`, `top`, `lsof`, `netstat` e acesso ao diretório `/proc`

---

## Objetivo

Ao concluir este lab, você será capaz de:

- Identificar processos fora do padrão usando `ps` e `top`
- Correlacionar PID, PPID, usuário e linha de comando para achar comportamento suspeito
- Descobrir quais portas e arquivos um processo está usando com `lsof` e `netstat`
- Inspecionar detalhes do processo direto em `/proc`
- Separar atividade normal de sinais práticos de possível comprometimento

---

## Pré-requisitos

Antes de começar, confirme que você tem:

- Um terminal com privilégios `sudo`
- Um sistema Linux com ferramentas básicas de diagnóstico instaladas
- Acesso ao pacote `net-tools` se `netstat` não existir no sistema
- Permissão para executar processos de teste localmente

### Preparação do ambiente

```bash
# Verificar as ferramentas principais
ps --version
top -v 2>/dev/null || top -h 2>/dev/null
lsof -v | head -n 2
netstat -h 2>/dev/null | head -n 2

# Instalar netstat se necessário
sudo apt install net-tools -y   # Debian/Ubuntu
sudo dnf install net-tools -y    # RHEL/Fedora

# Criar um diretório de trabalho seguro
mkdir -p ~/lab-processos-suspeitos
cd ~/lab-processos-suspeitos

# Criar processos de teste benignos
python3 -m http.server 8080 >/tmp/http-lab.log 2>&1 &
HTTP_PID=$!

sh -c 'sleep 600' &
SLEEP_PID=$!

echo "HTTP_PID=$HTTP_PID"
echo "SLEEP_PID=$SLEEP_PID"
```

**Output esperado:**

```text
HTTP_PID=12345
SLEEP_PID=12346
```

Os números mudam a cada execução. O importante é ver dois PIDs válidos e nenhum erro de inicialização.

---

## Exercício 1 — Encontrando processos fora do padrão com `ps`

**Objetivo:** localizar processos que merecem investigação antes de tocar em qualquer coisa.

### Parte A — Visão geral do sistema

```bash
ps aux --sort=-%cpu | head -n 10
```

**Output esperado:**

```text
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.1 170000 12000 ?        Ss   ...     ... /sbin/init
seu_usuario 12345  0.0  0.0  26000  9000 ?     S    ...     ... python3 -m http.server 8080
seu_usuario 12346  0.0  0.0   2900   900 ?     S    ...     ... sh -c sleep 600
```

Você não precisa ver exatamente os mesmos PIDs. O ponto é reconhecer a estrutura: usuário, PID, consumo e linha de comando.

### Parte B — Filtrando por usuário e por PID

```bash
ps -u "$USER" -o pid,ppid,user,stat,%cpu,%mem,comm,args
ps -p "$HTTP_PID","$SLEEP_PID" -o pid,ppid,user,stat,etime,cmd
```

**Output esperado:**

```text
  PID  PPID USER     STAT %CPU %MEM COMMAND         COMMAND
12345  6789 seu_usuario S    0.0  0.0 python3        python3 -m http.server 8080
12346  6789 seu_usuario S    0.0  0.0 sh             sh -c sleep 600

  PID  PPID USER     STAT     ELAPSED CMD
12345  6789 seu_usuario S          00:10 python3 -m http.server 8080
12346  6789 seu_usuario S          00:10 sh -c sleep 600
```

Se o `PPID` for diferente do que você espera, isso já merece atenção. Processos filhos de shell, web server ou serviço de sistema podem indicar execução legítima ou algo iniciado manualmente.

### Parte C — Sinais práticos de alerta no `ps`

```bash
ps -eo pid,ppid,user,stat,cmd --sort=ppid | less
```

Procure por estes sinais:

- Processo com nome legítimo, mas comando estranho
- `PPID` 1 sem motivo claro
- Usuário inesperado, especialmente `root`
- Processo rodando há muito tempo sem explicação operacional
- Vários processos filhos do mesmo binário com consumo incomum

---

## Exercício 2 — Monitorando comportamento com `top`

**Objetivo:** identificar picos e mudanças de consumo em tempo real.

### Parte A — Abrindo o monitor

```bash
top
```

Dentro do `top`, pressione:

- `P` para ordenar por CPU
- `M` para ordenar por memória
- `u` para filtrar por usuário
- `k` para matar um processo apenas se você tiver certeza

**Output esperado:**

```text
top - 10:15:30 up 2 days,  3:12,  1 user,  load average: 0.10, 0.12, 0.09
Tasks: 220 total,   1 running, 219 sleeping,   0 stopped,   0 zombie
%Cpu(s):  1.0 us,  0.4 sy,  0.0 ni, 98.3 id,  0.2 wa,  0.0 hi,  0.1 si,  0.0 st
MiB Mem :   7946.0 total,   1234.0 free,   2100.0 used,   4612.0 buff/cache
PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
12345 seu_usuario  20   0   26000   9000   5000 S   0.0  0.1   0:00.01 python3
12346 seu_usuario  20   0    2900    900    800 S   0.0  0.0   0:00.00 sh
```

Os valores mudam de máquina para máquina. O que importa é conseguir ver o processo suspeito e acompanhar se ele cresce, some ou muda de estado.

### Parte B — Capturando uma linha de `top` sem interação

```bash
top -b -n 1 | head -n 15
```

**Output esperado:**

```text
top - 10:15:35 up 2 days,  3:12,  1 user,  load average: 0.10, 0.12, 0.09
Tasks: 220 total,   1 running, 219 sleeping,   0 zombie
%Cpu(s): ...
MiB Mem : ...
MiB Swap: ...
PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
12345 seu_usuario  20   0   26000   9000   5000 S  0.0  0.1   0:00.01 python3
```

Essa forma é útil em shell scripts, coleta remota e triagem rápida durante incidente.

---

## Exercício 3 — Encontrando rede e arquivos com `netstat` e `lsof`

**Objetivo:** descobrir o que o processo está escutando e quais arquivos ele tocou.

### Parte A — Porta aberta e PID associado

```bash
sudo netstat -tulpn | grep ':8080'
```

**Output esperado:**

```text
tcp        0      0 0.0.0.0:8080      0.0.0.0:*      LISTEN      12345/python3
```

Se aparecer uma porta que você não reconhece, o próximo passo é descobrir qual processo é dono dela e se esse processo faz sentido no servidor.

### Parte B — Mapeando arquivos e sockets com `lsof`

```bash
sudo lsof -p "$HTTP_PID"
sudo lsof -i :8080
sudo lsof -u "$USER" | head -n 15
```

**Output esperado:**

```text
COMMAND  PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
python3 12345 seu_usuario  cwd    DIR  ...    ...  /home/seu_usuario/lab-processos-suspeitos
python3 12345 seu_usuario  txt    REG  ...    ...  /usr/bin/python3
python3 12345 seu_usuario    3u   IPv4 ...    ...  TCP *:8080 (LISTEN)
```

`lsof` mostra três coisas importantes ao mesmo tempo: binário executado, diretório atual e arquivos ou sockets abertos.

### Parte C — O que isso denuncia na prática

Se um processo diz ser um serviço web, mas:

- roda em um diretório temporário
- abre arquivos inesperados em `/tmp`
- escuta em porta não documentada
- pertence a um usuário que não deveria executar serviços

... então ele merece investigação imediata.

---

## Exercício 4 — Inspecionando `/proc` sem depender de ferramentas extras

**Objetivo:** extrair evidências diretamente do kernel para confirmar suspeitas.

### Parte A — Identificando o processo por dentro

```bash
cat /proc/$HTTP_PID/cmdline | tr '\0' ' '
cat /proc/$HTTP_PID/status | sed -n '1,20p'
readlink -f /proc/$HTTP_PID/exe
pwdx "$HTTP_PID" 2>/dev/null
```

**Output esperado:**

```text
python3 -m http.server 8080
Name:   python3
Umask:  0022
State:  S (sleeping)
Tgid:   12345
Pid:    12345
PPid:   6789
Uid:    1000    1000    1000    1000
/usr/bin/python3.11
/home/seu_usuario/lab-processos-suspeitos
```

`cmdline` mostra o comando real. `status` confirma usuário e estado. `exe` e `pwdx` ajudam a checar se o processo está rodando do lugar esperado.

### Parte B — Verificando conexões, diretório e descritores

```bash
ls -la /proc/$HTTP_PID/fd
cat /proc/$HTTP_PID/environ | tr '\0' '\n' | head -n 10
cat /proc/$HTTP_PID/maps | head -n 10
```

**Output esperado:**

```text
lrwx------ 1 seu_usuario seu_usuario 64 ... 0 -> /dev/null
lrwx------ 1 seu_usuario seu_usuario 64 ... 1 -> /tmp/http-lab.log
lrwx------ 1 seu_usuario seu_usuario 64 ... 2 -> /tmp/http-lab.log
lrwx------ 1 seu_usuario seu_usuario 64 ... 3 -> socket:[123456]

USER=seu_usuario
HOME=/home/seu_usuario
PATH=/usr/local/sbin:...

55f... r-xp ... /usr/bin/python3.11
7f...  r--p ... /usr/lib/x86_64-linux-gnu/libc.so.6
```

O `/proc` é útil porque não depende de cache do usuário nem de output bonito. Ele mostra o estado atual do processo no kernel.

### Parte C — Procurando sinais de anomalia em `maps`

```bash
cat /proc/$HTTP_PID/maps | grep -E 'rwx|/tmp|deleted'
```

**Output esperado:**

```text

```

Em um cenário limpo, esse comando pode não retornar nada. Se aparecer memória com `rwx`, binário em `/tmp` ou referência a arquivos `deleted`, investigue antes de encerrar qualquer coisa.

---

## Exercício 5 — Triagem defensiva completa

**Objetivo:** juntar tudo em uma sequência curta de resposta inicial.

```bash
# 1. Listar candidatos
ps aux --sort=-%cpu | head -n 15

# 2. Conferir árvore e pai do processo
ps -eo pid,ppid,user,stat,args --forest | less

# 3. Ver portas abertas
sudo netstat -tulpn

# 4. Mapear arquivos e sockets
sudo lsof -p "$HTTP_PID"

# 5. Validar dentro de /proc
cat /proc/$HTTP_PID/status
readlink -f /proc/$HTTP_PID/exe
```

**Output esperado:**

```text
Uma lista coerente de processos, uma porta 8080 associada ao PID do teste e um caminho de executável compatível com o binário em uso.
```

Se os dados não batem entre si, trate isso como alerta. Processos legítimos contam a mesma história em `ps`, `lsof`, `netstat` e `/proc`.

---

## O que isso significa na prática

Na operação real, processo suspeito raramente se revela por um único comando. O padrão mais útil é cruzar sinais:

- `ps` mostra quem está rodando e com qual árvore de pais
- `top` mostra se o processo está consumindo CPU ou memória de forma anormal
- `lsof` mostra o que ele abriu, incluindo arquivos, sockets e portas
- `netstat` mostra serviços escutando e conexões ativas
- `/proc` confirma o que está acontecendo agora, sem intermediários

Se um processo:

- roda como usuário errado
- escuta em porta inesperada
- usa caminho estranho em `/tmp` ou `/dev/shm`
- tem linha de comando mascarada
- aparece com pai suspeito ou diferente do normal

... você não tem prova final de ataque, mas já tem motivo suficiente para conter, registrar e investigar.

### Regra prática de triagem

1. Confirme o PID.
2. Confirme o usuário.
3. Confirme o executável.
4. Confirme a porta e os arquivos abertos.
5. Confirme o contexto com `/proc`.

Se qualquer uma dessas camadas divergir, pare de assumir que o processo é legítimo.

---

## Limpeza do ambiente

Ao final do lab, encerre os processos de teste:

```bash
kill "$HTTP_PID" "$SLEEP_PID" 2>/dev/null
wait "$HTTP_PID" "$SLEEP_PID" 2>/dev/null

ps -p "$HTTP_PID","$SLEEP_PID"
```

**Output esperado:**

```text
PID TTY          TIME CMD
```

Se ainda aparecer algo, o processo não foi encerrado. Verifique se os PIDs estão corretos antes de insistir com sinais mais agressivos.
