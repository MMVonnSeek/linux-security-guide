[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Módulo 02 — Comandos Essenciais de Rede

> **Pré-requisito:** [Usuários e Grupos](../01-fundamentos/usuarios-grupos.md)  
> **Tempo estimado:** 50 minutos  
> **Distro testada:** Ubuntu 22.04 / RHEL 9 / Debian 12

---

## Por que diagnóstico de rede é habilidade de segurança

Reconhecer o estado normal da rede de um sistema é pré-requisito para identificar o anormal. Conexões inesperadas, portas abertas sem justificativa e tráfego para endereços desconhecidos são os primeiros sinais visíveis de um comprometimento. Todas essas verificações partem dos comandos deste módulo.

---

## 1. Interfaces de rede

### ip — substituto moderno do ifconfig

O comando `ip` é a ferramenta padrão em distribuições modernas. O `ifconfig` é legado e não deve ser usado em novos ambientes.

```bash
ip addr                         # lista interfaces e endereços IP
ip addr show eth0               # detalha uma interface específica
ip link                         # estado das interfaces (up/down)
ip link show eth0
ip -s link                      # estatísticas de tráfego por interface
ip route                        # tabela de roteamento
ip route show default           # apenas o gateway padrão
ip neigh                        # tabela ARP (vizinhos conhecidos)
```

Interpretando a saída do `ip addr`:

```
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP
    link/ether 00:1a:2b:3c:4d:5e brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.10/24 brd 192.168.1.255 scope global eth0
    inet6 fe80::21a:2bff:fe3c:4d5e/64 scope link
```

| Campo | Significado |
|-------|-------------|
| `UP` | Interface ativa |
| `mtu 1500` | Tamanho máximo de pacote |
| `link/ether` | Endereço MAC |
| `inet` | Endereço IPv4 com prefixo CIDR |
| `inet6` | Endereço IPv6 |
| `scope global` | Endereço roteável externamente |
| `scope link` | Endereço válido apenas na rede local |

### Configuração temporária de rede

```bash
# Atribuir IP temporário (perdido no reboot)
sudo ip addr add 192.168.1.20/24 dev eth0
sudo ip addr del 192.168.1.20/24 dev eth0

# Ativar/desativar interface
sudo ip link set eth0 up
sudo ip link set eth0 down

# Adicionar rota
sudo ip route add 10.0.0.0/8 via 192.168.1.1
sudo ip route del 10.0.0.0/8
```

> **Ponto de segurança:** interfaces em modo promíscuo (`PROMISC` na saída do `ip link`) capturam todo o tráfego da rede, não apenas o destinado a elas. Esse modo é usado por sniffers. Verifique com `ip link | grep PROMISC`.

---

## 2. Conectividade e diagnóstico

### ping — teste de alcançabilidade

```bash
ping 8.8.8.8                    # teste básico de conectividade
ping -c 4 8.8.8.8               # limita a 4 pacotes
ping -i 0.2 8.8.8.8             # intervalo de 0.2s entre pacotes
ping -s 1400 8.8.8.8            # testa com pacotes de 1400 bytes (diagnóstico de MTU)
ping6 ::1                       # ping IPv6
```

### traceroute — caminho até o destino

```bash
traceroute 8.8.8.8              # rota com UDP (padrão)
traceroute -T 8.8.8.8           # usa TCP (atravessa mais firewalls)
traceroute -I 8.8.8.8           # usa ICMP
traceroute -n 8.8.8.8           # sem resolução de nomes (mais rápido)
mtr 8.8.8.8                     # traceroute contínuo com estatísticas
```

### dig e resolvconf — DNS

```bash
dig google.com                  # consulta DNS completa
dig google.com A                # apenas registros A (IPv4)
dig google.com MX               # registros de e-mail
dig google.com ANY              # todos os registros
dig @8.8.8.8 google.com        # consulta servidor DNS específico
dig -x 8.8.8.8                  # resolução reversa (IP para nome)
dig +short google.com           # apenas o resultado, sem cabeçalho

# Verificar configuração DNS local
cat /etc/resolv.conf
resolvectl status               # systemd-resolved
```

> **Ponto de segurança:** DNS é um vetor frequente de ataque. Verifique periodicamente `/etc/resolv.conf` — servidores DNS não autorizados inseridos ali podem redirecionar todo o tráfego de nomes do sistema.

---

## 3. Monitoramento de conexões e portas

Esta é a área mais crítica para segurança. Saber o que está ouvindo em cada porta e quais conexões estão ativas é fundamental para triagem de incidentes.

### ss — substituto moderno do netstat

```bash
ss -tlnp             # TCP, listening, numérico, com processo
ss -ulnp             # UDP, listening, numérico, com processo
ss -tlnp             # portas TCP abertas com PID e nome do processo
ss -s                # resumo estatístico de conexões
ss -anp              # todas as conexões com processos
ss -tnp state established   # apenas conexões estabelecidas
ss -tnp dst 8.8.8.8         # conexões para um destino específico
ss -tnp sport = :443        # conexões na porta de origem 443
```

Interpretando a saída do `ss -tlnp`:

```
State   Recv-Q  Send-Q  Local Address:Port  Peer Address:Port  Process
LISTEN  0       128     0.0.0.0:22          0.0.0.0:*          users:(("sshd",pid=1234))
LISTEN  0       511     127.0.0.1:3306      0.0.0.0:*          users:(("mysqld",pid=5678))
```

| Campo | Significado |
|-------|-------------|
| `0.0.0.0:22` | Escutando em todas as interfaces na porta 22 |
| `127.0.0.1:3306` | Escutando apenas em loopback (não acessível externamente) |
| `0.0.0.0:*` | Aceita conexão de qualquer origem |
| `Recv-Q` alto | Dados recebidos aguardando processamento — possível sobrecarga |

> **Ponto de segurança:** serviços que deveriam ser internos (banco de dados, cache, APIs internas) escutando em `0.0.0.0` ao invés de `127.0.0.1` são uma das configurações incorretas mais comuns e perigosas.

### netstat — legado, ainda presente em muitos ambientes

```bash
# Instalar se necessário
sudo apt install net-tools

netstat -tlnp        # equivalente ao ss -tlnp
netstat -anp         # todas as conexões
netstat -rn          # tabela de roteamento
netstat -s           # estatísticas por protocolo
```

---

## 4. Transferência e teste de conectividade

### curl — cliente HTTP de linha de comando

```bash
curl https://exemplo.com                        # GET simples
curl -I https://exemplo.com                     # apenas cabeçalhos HTTP
curl -o arquivo.html https://exemplo.com        # salva em arquivo
curl -L https://exemplo.com                     # segue redirecionamentos
curl -u usuario:senha https://api.exemplo.com   # autenticação básica
curl -X POST -d '{"key":"value"}' \
     -H "Content-Type: application/json" \
     https://api.exemplo.com/endpoint           # POST com JSON
curl -v https://exemplo.com                     # verbose (diagnóstico)
curl --max-time 5 https://exemplo.com           # timeout de 5 segundos
curl -k https://exemplo.com                     # ignora erro de certificado TLS
```

> **Ponto de segurança:** `-k` (ou `--insecure`) desabilita a verificação do certificado TLS. Nunca use em produção ou em scripts automatizados — isso abre espaço para ataques man-in-the-middle.

### wget — download de arquivos

```bash
wget https://exemplo.com/arquivo.tar.gz
wget -O destino.tar.gz https://exemplo.com/arquivo.tar.gz
wget -c https://exemplo.com/arquivo.tar.gz      # retoma download interrompido
wget -q https://exemplo.com/arquivo.tar.gz      # silencioso (sem progresso)
wget --no-check-certificate https://exemplo.com # equivalente ao curl -k (evite)
```

### nc (netcat) — canivete suíço de rede

```bash
# Testar conectividade TCP em uma porta específica
nc -zv 192.168.1.1 22           # testa porta 22
nc -zv 192.168.1.1 80 443 8080  # testa múltiplas portas
nc -zvw3 192.168.1.1 22         # timeout de 3 segundos

# Escutar em uma porta (diagnóstico)
nc -lvp 4444                    # escuta na porta 4444

# Transferência simples de arquivo
# No receptor:
nc -lvp 9999 > arquivo_recebido.txt
# No emissor:
nc 192.168.1.2 9999 < arquivo.txt
```

> **Ponto de segurança:** `nc -lvp` é exatamente como um reverse shell ou bind shell é configurado. Processos netcat escutando em portas em um servidor de produção devem ser investigados imediatamente.

---

## 5. Análise de tráfego com tcpdump

`tcpdump` captura pacotes em tempo real diretamente da interface de rede. É a ferramenta de diagnóstico e forense de rede mais importante do Linux.

```bash
# Captura básica
sudo tcpdump -i eth0                            # captura tudo na interface eth0
sudo tcpdump -i any                             # captura em todas as interfaces

# Filtros essenciais
sudo tcpdump -i eth0 host 192.168.1.1           # tráfego de/para um host
sudo tcpdump -i eth0 port 80                    # tráfego na porta 80
sudo tcpdump -i eth0 src 192.168.1.1            # apenas tráfego originado de
sudo tcpdump -i eth0 dst 192.168.1.1            # apenas tráfego destinado a
sudo tcpdump -i eth0 tcp                        # apenas TCP
sudo tcpdump -i eth0 udp port 53                # DNS
sudo tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0'  # apenas pacotes SYN

# Combinando filtros
sudo tcpdump -i eth0 host 192.168.1.1 and port 443
sudo tcpdump -i eth0 not port 22                # tudo exceto SSH

# Opções de saída
sudo tcpdump -i eth0 -n                         # sem resolução de nomes
sudo tcpdump -i eth0 -nn                        # sem resolução de nomes nem portas
sudo tcpdump -i eth0 -v                         # verbose
sudo tcpdump -i eth0 -X                         # mostra payload em hex e ASCII
sudo tcpdump -i eth0 -w captura.pcap            # salva em arquivo para análise
sudo tcpdump -r captura.pcap                    # lê arquivo salvo
sudo tcpdump -i eth0 -c 100                     # captura apenas 100 pacotes
```

> **Ponto de segurança:** salvar capturas com `-w` para análise posterior no Wireshark é prática padrão em resposta a incidentes. Ao identificar tráfego suspeito, inicie a captura imediatamente e preserve o arquivo — ele é evidência.

---

## 6. Informações de rede do sistema

```bash
# Nome do host
hostname
hostname -f                     # FQDN (fully qualified domain name)

# Interfaces e IPs de forma resumida
ip -br addr                     # formato compacto

# Verificar se uma porta está acessível externamente
curl -s https://portchecker.co/check -d "host=meuservidor.com&port=80"

# ARP — mapeamento IP para MAC na rede local
ip neigh
arp -n

# Estatísticas de rede do kernel
cat /proc/net/dev               # bytes/pacotes por interface
cat /proc/net/tcp               # conexões TCP em formato bruto
cat /proc/net/udp               # conexões UDP em formato bruto
ss -s                           # resumo legível
```

---

## 7. Sequência de triagem de rede em incidente

Quando há suspeita de comprometimento, execute esta sequência em ordem. Cada etapa depende da anterior para construir o quadro completo.

```bash
# 1. Interfaces ativas e endereços
ip addr
ip link | grep PROMISC          # interface em modo promíscuo?

# 2. Conexões estabelecidas e portas abertas
ss -antp

# 3. Processos por trás de cada conexão suspeita
ss -antp | grep <porta_suspeita>
# Com o PID em mãos, investigue conforme o módulo de processos
ls -la /proc/<PID>/exe
cat /proc/<PID>/cmdline | tr '\0' ' '

# 4. Tráfego em tempo real para o IP suspeito
sudo tcpdump -i any host <IP_suspeito> -nn -X -w evidencia.pcap

# 5. Rotas suspeitas (exfiltração via rota específica?)
ip route

# 6. Cache DNS (nomes resolvidos recentemente)
resolvectl statistics
sudo journalctl -u systemd-resolved | grep <dominio_suspeito>
```

---

## Lab — Coloque em prática

### Exercício 1 — Mapeamento de portas abertas

Liste todas as portas TCP em estado LISTEN no sistema, identifique o processo responsável por cada uma e classifique quais deveriam estar acessíveis externamente e quais deveriam estar restritas ao loopback.

<details>
<summary>Ver gabarito</summary>

```bash
ss -tlnp

# Análise esperada:
# Porta 22 (sshd)     → 0.0.0.0 é aceitável se o acesso SSH for necessário
# Porta 3306 (mysqld) → DEVE estar em 127.0.0.1, nunca em 0.0.0.0
# Porta 6379 (redis)  → DEVE estar em 127.0.0.1, nunca em 0.0.0.0
# Porta 80/443        → 0.0.0.0 é esperado para servidores web públicos
```
</details>

---

### Exercício 2 — Diagnóstico de conectividade

Simule um diagnóstico completo de conectividade, documentando cada resultado:

```bash
# 1. Verifique se há rota para a internet
ip route show default

# 2. Teste alcançabilidade da gateway
ping -c 3 $(ip route show default | awk '/default/ {print $3}')

# 3. Teste resolução DNS
dig +short google.com

# 4. Teste conectividade HTTP
curl -Is https://google.com | head -5
```

<details>
<summary>O que cada resultado indica</summary>

1. Ausência de rota padrão = sem saída para internet
2. Ping à gateway falha = problema na camada 2/3 local
3. dig falha mas ping à gateway funciona = problema de DNS
4. curl falha mas dig funciona = problema de roteamento ou firewall na porta 443
</details>

---

### Exercício 3 — Captura e análise de tráfego DNS

```bash
# Terminal 1: inicie a captura de tráfego DNS
sudo tcpdump -i any port 53 -nn -v

# Terminal 2: gere tráfego DNS
dig google.com
dig github.com
dig @8.8.8.8 linux.org
```

Observe a captura e identifique: IP de origem, IP do servidor DNS consultado, nome consultado e tipo de registro.

---

## Checklist de segurança — rede

- [ ] Nenhuma interface em modo promíscuo sem justificativa
- [ ] Serviços internos (banco de dados, cache) escutando apenas em `127.0.0.1`
- [ ] Nenhuma porta aberta sem processo identificado e justificado
- [ ] `/etc/resolv.conf` com servidores DNS autorizados
- [ ] Nenhum processo `nc`, `ncat` ou `socat` escutando em portas em produção
- [ ] Tabela de roteamento sem entradas não autorizadas

---

## Referências

- `man ip` / `man ss` / `man tcpdump` / `man curl`
- [Red Hat — Configuring and Managing Networking](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_networking)
- [tcpdump filters — pcap-filter man page](https://www.tcpdump.org/manpages/pcap-filter.7.html)

---

<div align="center">

**Módulo anterior: [Usuários e Grupos](../01-fundamentos/usuarios-grupos.md)**  
**Próximo módulo: [Firewall com nftables](firewall-nftables.md)**

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-darkred?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-black?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

</div>