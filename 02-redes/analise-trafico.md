[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Módulo 02 — Análise de Tráfego de Rede

> **Pré-requisito:** [Firewall com nftables](firewall-nftables.md)  
> **Tempo estimado:** 60 minutos  
> **Distro testada:** Ubuntu 22.04 / RHEL 9 / Debian 12

---

## Por que análise de tráfego é habilidade central em segurança

Logs de aplicação, alertas de IDS e eventos de SIEM todos descrevem o que aconteceu. A análise de tráfego mostra exatamente como aconteceu — byte a byte, pacote a pacote. É a diferença entre saber que houve uma exfiltração de dados e conseguir provar o que foi extraído, para onde foi e quando. Toda investigação séria de incidente passa em algum momento por captura e análise de pacotes.

---

## 1. A pilha de protocolos na prática

Antes de analisar tráfego, é necessário entender o que você está vendo. Cada pacote capturado é um conjunto de camadas encapsuladas:

```
[ Ethernet Frame                                              ]
  [ IP Header            ][ TCP Header  ][ Payload / Dados   ]
    src: 192.168.1.10       src: 54321     GET /index.html
    dst: 93.184.216.34      dst: 80        Host: example.com
```

Campos relevantes para segurança em cada camada:

**Camada 2 — Ethernet:**
- `src MAC` / `dst MAC` — identifica dispositivos na rede local
- Spoofing de MAC é o primeiro passo em ataques ARP

**Camada 3 — IP:**
- `TTL` — cada roteador decrementa em 1; valor inicial indica o OS do emissor (Linux=64, Windows=128, Cisco=255)
- `Flags` — DF (Don't Fragment), MF (More Fragments)
- Endereços de origem forjados indicam spoofing

**Camada 4 — TCP:**
- Flags: SYN, ACK, FIN, RST, PSH, URG
- Número de sequência — usado em ataques de sequestro de sessão
- Janela de recepção — indica controle de fluxo

---

## 2. tcpdump — captura em linha de comando

O `tcpdump` já foi introduzido no módulo de comandos de rede. Aqui o foco é em uso forense e de análise profunda.

### Captura para investigação

```bash
# Captura completa com timestamps precisos
sudo tcpdump -i any -tttt -nn -v -w /tmp/captura_$(date +%Y%m%d_%H%M%S).pcap

# Captura com rotação de arquivo (100MB por arquivo, mantém 10 arquivos)
sudo tcpdump -i eth0 -w /tmp/captura_%Y%m%d_%H%M%S.pcap \
    -G 3600 -C 100 -W 10 -Z root

# Captura de tamanho limitado (primeiros 200 bytes de cada pacote)
# Suficiente para ver cabeçalhos sem capturar payload completo
sudo tcpdump -i eth0 -s 200 -w captura.pcap
```

### Filtros avançados (BPF — Berkeley Packet Filter)

```bash
# Tráfego entre dois hosts específicos
sudo tcpdump -i eth0 host 192.168.1.10 and host 192.168.1.20

# Apenas pacotes SYN (início de conexões TCP)
sudo tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0 and tcp[tcpflags] & tcp-ack == 0'

# Pacotes SYN-ACK (resposta do servidor)
sudo tcpdump -i eth0 'tcp[tcpflags] & (tcp-syn|tcp-ack) == (tcp-syn|tcp-ack)'

# Pacotes RST (conexões resetadas — possível varredura ou rejeição)
sudo tcpdump -i eth0 'tcp[tcpflags] & tcp-rst != 0'

# DNS (consultas e respostas)
sudo tcpdump -i eth0 port 53 -v

# HTTP sem HTTPS (tráfego não criptografado)
sudo tcpdump -i eth0 tcp port 80 -A

# Tráfego ICMP com tipo específico
sudo tcpdump -i eth0 'icmp[icmptype] == icmp-echo'

# Pacotes maiores que 1000 bytes (possível transferência de dados)
sudo tcpdump -i eth0 'len > 1000'

# Tráfego para subnets específicas excluindo SSH
sudo tcpdump -i eth0 'dst net 10.0.0.0/8 and not port 22'
```

### Lendo capturas salvas

```bash
sudo tcpdump -r captura.pcap                    # leitura básica
sudo tcpdump -r captura.pcap -nn                # sem resolução de nomes
sudo tcpdump -r captura.pcap -X port 80         # payload em hex+ASCII
sudo tcpdump -r captura.pcap -A port 80         # payload apenas em ASCII
sudo tcpdump -r captura.pcap -q                 # formato resumido
sudo tcpdump -r captura.pcap 'host 192.168.1.5' # filtra na leitura
```

---

## 3. tshark — Wireshark em linha de comando

O `tshark` é a interface de linha de comando do Wireshark. Oferece dissecção profunda de protocolos e extração estruturada de dados — muito mais poderoso que o `tcpdump` para análise, mas mais pesado para captura.

```bash
# Instalar
sudo apt install tshark -y
sudo dnf install wireshark-cli -y

# Listar interfaces disponíveis
tshark -D

# Captura básica
sudo tshark -i eth0

# Captura com filtro de exibição
sudo tshark -i eth0 -Y "http"
sudo tshark -i eth0 -Y "dns"
sudo tshark -i eth0 -Y "tcp.flags.syn == 1 and tcp.flags.ack == 0"

# Extrair campos específicos em formato legível
sudo tshark -i eth0 -Y "http.request" \
    -T fields \
    -e ip.src \
    -e ip.dst \
    -e http.request.method \
    -e http.request.uri \
    -e http.host

# Ler arquivo pcap e extrair campos
tshark -r captura.pcap -Y "dns" \
    -T fields \
    -e frame.time \
    -e ip.src \
    -e dns.qry.name \
    -e dns.resp.addr

# Estatísticas de conversações
tshark -r captura.pcap -q -z conv,tcp

# Estatísticas de protocolos
tshark -r captura.pcap -q -z io,phs

# Top IPs por volume de dados
tshark -r captura.pcap -q -z endpoints,ip
```

---

## 4. Wireshark — análise visual

O Wireshark é a ferramenta padrão da indústria para análise visual de capturas. Em servidores sem interface gráfica, capture com `tcpdump` e transfira o `.pcap` para análise no Wireshark localmente.

```bash
# Capturar no servidor remoto
sudo tcpdump -i eth0 -w /tmp/captura.pcap

# Transferir para análise local
scp usuario@servidor:/tmp/captura.pcap ~/Desktop/
```

### Filtros de exibição essenciais no Wireshark

```
# Protocolo
http
dns
tcp
udp
icmp
ssh
tls

# IP
ip.addr == 192.168.1.10
ip.src == 192.168.1.10
ip.dst == 8.8.8.8

# Porta
tcp.port == 80
tcp.dstport == 443
udp.port == 53

# Flags TCP
tcp.flags.syn == 1
tcp.flags.reset == 1
tcp.flags.fin == 1

# Combinações
ip.src == 192.168.1.10 and tcp.dstport == 443
http and ip.dst == 93.184.216.34
tcp.flags.syn == 1 and not tcp.flags.ack == 1

# Conteúdo no payload
frame contains "password"
http.request.uri contains "/admin"
dns.qry.name contains "pastebin"
```

### Follow TCP Stream

No Wireshark, clique com o botão direito em qualquer pacote TCP e selecione **Follow > TCP Stream**. Isso reconstrói a conversa completa entre cliente e servidor em texto legível — essencial para analisar sessões HTTP não criptografadas, comandos enviados via telnet ou qualquer protocolo em texto claro.

---

## 5. Padrões de tráfego suspeito

### Varredura de portas (port scan)

```bash
# Detectar no tcpdump: muitos SYN sem ACK para portas diferentes
sudo tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0 and tcp[tcpflags] & tcp-ack == 0' -nn

# Característica no pcap:
# - Um IP de origem
# - Muitos destinos de porta em sequência
# - Intervalo curto entre pacotes
# - Maioria dos pacotes recebe RST em resposta (porta fechada)
```

### Exfiltração de dados via DNS (DNS tunneling)

```bash
# Consultas DNS com nomes muito longos são suspeitas
sudo tcpdump -i eth0 port 53 -v 2>/dev/null | grep -E "A\? .{40,}"

# No tshark: extrair todos os nomes consultados
tshark -r captura.pcap -Y "dns.flags.response == 0" \
    -T fields -e dns.qry.name | sort | uniq -c | sort -rn
```

Indicadores de DNS tunneling:
- Subdomínios com mais de 50 caracteres
- Alto volume de consultas para um único domínio
- Registros do tipo TXT com conteúdo longo e codificado
- Consultas para domínios inexistentes com padrão base64

### Beaconing — malware chamando para casa

```bash
# Identificar conexões periódicas regulares para IPs externos
tshark -r captura.pcap -Y "tcp.flags.syn == 1" \
    -T fields -e frame.time_epoch -e ip.dst -e tcp.dstport \
    | awk '{print $2}' | sort | uniq -c | sort -rn
```

Indicadores de beaconing:
- Conexões para o mesmo IP externo em intervalos regulares (a cada 30s, 60s, 5min)
- Pacotes de tamanho fixo ou muito similar
- Horários de conexão fora do horário comercial
- Destino sem nome DNS registrado (IP direto)

### Movimento lateral na rede interna

```bash
# Conexões entre hosts internos em portas administrativas
sudo tcpdump -i eth0 \
    'src net 192.168.0.0/16 and dst net 192.168.0.0/16 and \
    (dst port 22 or dst port 445 or dst port 3389 or dst port 5985)'
```

---

## 6. Extração de artefatos de capturas

### Extrair arquivos transferidos via HTTP (não criptografado)

```bash
# Com tcpflow
sudo apt install tcpflow
tcpflow -r captura.pcap -o /tmp/extraido/

# Com tshark
tshark -r captura.pcap --export-objects http,/tmp/http_objects/
```

### Extrair credenciais de protocolos em texto claro

```bash
# FTP — usuário e senha em texto claro
tshark -r captura.pcap -Y "ftp" -T fields \
    -e frame.time -e ip.src -e ftp.request.command -e ftp.request.arg

# HTTP Basic Auth (base64)
tshark -r captura.pcap -Y "http.authorization" \
    -T fields -e ip.src -e http.authorization

# Telnet — tudo em texto claro, incluindo senhas
tcpflow -r captura.pcap -o /tmp/telnet/ port 23
```

> **Ponto de segurança:** qualquer captura de rede em um segmento que ainda use FTP, Telnet ou HTTP Basic Auth vai expor credenciais em texto claro. Esses protocolos devem ser eliminados de qualquer ambiente que processe dados sensíveis.

### Extrair certificados TLS

```bash
tshark -r captura.pcap -Y "tls.handshake.certificate" \
    -T fields \
    -e tls.handshake.certificate \
    | head -5
```

---

## 7. Ferramentas complementares

### ngrep — grep no tráfego de rede

```bash
sudo apt install ngrep

# Busca por padrão no payload em tempo real
sudo ngrep -d eth0 "password" tcp port 80
sudo ngrep -d eth0 "Authorization:" tcp port 80
sudo ngrep -d any "User-Agent:" tcp port 80 -W byline
```

### iftop — monitoramento de largura de banda por conexão

```bash
sudo apt install iftop
sudo iftop -i eth0           # monitoramento por pares de hosts
sudo iftop -i eth0 -n        # sem resolução de nomes
```

### nethogs — uso de rede por processo

```bash
sudo apt install nethogs
sudo nethogs eth0            # banda consumida por processo em tempo real
```

### ss com estatísticas detalhadas

```bash
# Conexões TCP com timers e detalhes de estado
ss -tiO

# Verificar retransmissões (indica problemas de rede ou bloqueio)
ss -ti | grep retrans
```

---

## 8. Fluxo de análise em resposta a incidente

Quando há suspeita de comprometimento com atividade de rede, siga esta sequência:

```bash
# Fase 1: Captura imediata
# Inicie a captura ANTES de qualquer outra ação investigativa
sudo tcpdump -i any -w /tmp/evidencia_$(hostname)_$(date +%Y%m%d_%H%M%S).pcap &
TCPDUMP_PID=$!

# Fase 2: Estado atual das conexões
ss -antp > /tmp/conexoes_$(date +%Y%m%d_%H%M%S).txt
ip route > /tmp/rotas_$(date +%Y%m%d_%H%M%S).txt

# Fase 3: Identificar processos por trás de conexões suspeitas
# (ver módulo de processos para continuação)

# Fase 4: Análise da captura
# Após encerrar a captura:
kill $TCPDUMP_PID

# Verificar volume por IP externo
tshark -r /tmp/evidencia_*.pcap -q -z endpoints,ip | head -20

# Verificar consultas DNS suspeitas
tshark -r /tmp/evidencia_*.pcap -Y "dns.flags.response == 0" \
    -T fields -e dns.qry.name | sort | uniq -c | sort -rn

# Verificar conexões estabelecidas para IPs externos
tshark -r /tmp/evidencia_*.pcap \
    -Y "tcp.flags.syn == 1 and not ip.dst == 192.168.0.0/16" \
    -T fields -e ip.dst -e tcp.dstport | sort | uniq -c | sort -rn
```

---

## Lab — Coloque em prática

### Exercício 1 — Captura e análise básica

```bash
# Terminal 1: inicie a captura
sudo tcpdump -i lo -w /tmp/lab-trafico.pcap &

# Terminal 2: gere tráfego variado
curl -s http://localhost > /dev/null 2>&1 || true
dig google.com
ping -c 3 127.0.0.1
nc -zv localhost 22

# Encerre a captura
sudo kill $(pgrep tcpdump)

# Analise com tshark
tshark -r /tmp/lab-trafico.pcap -q -z io,phs
tshark -r /tmp/lab-trafico.pcap -T fields -e frame.protocols | sort | uniq -c
```

---

### Exercício 2 — Extração de informações estruturadas

Usando o arquivo gerado no exercício anterior, extraia:

1. Todos os IPs de origem únicos
2. Todas as portas de destino únicas
3. O protocolo com maior volume de pacotes

<details>
<summary>Ver gabarito</summary>

```bash
# IPs de origem únicos
tshark -r /tmp/lab-trafico.pcap -T fields -e ip.src | sort -u

# Portas de destino únicas
tshark -r /tmp/lab-trafico.pcap -T fields -e tcp.dstport -e udp.dstport \
    | grep -v '^\s*$' | sort -u

# Protocolo com maior volume
tshark -r /tmp/lab-trafico.pcap -q -z io,phs
```
</details>

---

### Exercício 3 — Simulação de detecção de varredura

```bash
# Instale o nmap para simular varredura
sudo apt install nmap -y

# Terminal 1: capture o tráfego
sudo tcpdump -i lo -w /tmp/scan.pcap &

# Terminal 2: execute uma varredura
sudo nmap -sS -p 1-1000 127.0.0.1

# Encerre a captura
sudo kill $(pgrep tcpdump)

# Analise os padrões
tshark -r /tmp/scan.pcap -Y "tcp.flags.syn == 1 and tcp.flags.ack == 0" \
    -T fields -e ip.src -e ip.dst -e tcp.dstport \
    | wc -l

# Quantas portas responderam com RST (fechadas)?
tshark -r /tmp/scan.pcap -Y "tcp.flags.reset == 1" \
    -T fields -e tcp.srcport | wc -l
```

Documente: quantos pacotes SYN foram enviados, quantas portas responderam e qual a diferença entre uma porta aberta e uma fechada no padrão de flags TCP observado.

---

## Checklist de segurança — análise de tráfego

- [ ] Ferramenta de captura disponível e testada no ambiente (`tcpdump`, `tshark`)
- [ ] Espaço em disco suficiente para capturas em `/tmp` ou volume dedicado
- [ ] Procedimento documentado de início de captura em caso de incidente
- [ ] Capturas armazenadas com nome contendo hostname e timestamp
- [ ] Nenhum protocolo em texto claro (FTP, Telnet, HTTP) em uso com dados sensíveis
- [ ] Baseline de tráfego normal documentado para comparação em incidentes
- [ ] Acesso ao Wireshark disponível na estação de análise forense

---

## Referências

- `man tcpdump` / `man tshark`
- [Wireshark Display Filters Reference](https://www.wireshark.org/docs/dfref/)
- [tcpdump BPF Filter Syntax](https://www.tcpdump.org/manpages/pcap-filter.7.html)
- [SANS — Packet Analysis Cheat Sheet](https://www.sans.org/blog/sans-cheat-sheet-tcpdump/)

---

<div align="center">

**Módulo anterior: [Firewall com nftables](firewall-nftables.md)**  
**Próximo módulo: [SSH Seguro](../03-hardening/ssh-seguro.md)**

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-darkred?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-black?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

</div>