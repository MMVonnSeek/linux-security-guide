[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Módulo 02 — Firewall com nftables

> **Pré-requisito:** [Comandos Essenciais de Rede](comandos-essenciais.md)  
> **Tempo estimado:** 60 minutos  
> **Distro testada:** Ubuntu 22.04 / RHEL 9 / Debian 12

---

## Por que nftables e não iptables

O `iptables` é legado. Desde o kernel 3.13 o `nftables` é o framework oficial de filtragem de pacotes no Linux. RHEL 8+, Ubuntu 20.04+ e Debian 10+ usam `nftables` como backend padrão — inclusive o `firewalld` e o `ufw` são frontends que geram regras nftables por baixo. Entender o nftables diretamente elimina a camada de abstração e dá controle total sobre o comportamento do firewall.

---

## 1. Arquitetura do nftables

O nftables organiza as regras em uma hierarquia de três níveis:

```
Tabela (table)
└── Chain (chain)
    └── Regra (rule)
```

### Tabelas

Tabelas são contêineres lógicos. Cada tabela pertence a uma família de protocolos:

| Família | Escopo |
|---------|--------|
| `ip` | IPv4 apenas |
| `ip6` | IPv6 apenas |
| `inet` | IPv4 e IPv6 (recomendado para regras unificadas) |
| `arp` | Pacotes ARP |
| `bridge` | Tráfego de bridge (camada 2) |
| `netdev` | Ingress/egress por interface (alta performance) |

### Chains

Chains são listas de regras dentro de uma tabela. Existem dois tipos:

**Base chains** — conectadas aos hooks do kernel (onde o tráfego passa):

| Hook | Quando é acionado |
|------|------------------|
| `prerouting` | Todo pacote que entra, antes do roteamento |
| `input` | Pacotes destinados ao próprio sistema |
| `forward` | Pacotes em trânsito (roteamento entre interfaces) |
| `output` | Pacotes gerados pelo próprio sistema |
| `postrouting` | Todo pacote que sai, após o roteamento |

**Regular chains** — chamadas por `jump` ou `goto` de outras chains, usadas para organizar regras.

### Prioridade

A prioridade define a ordem de execução quando múltiplas chains estão no mesmo hook. Valores menores executam primeiro.

| Prioridade nomeada | Valor | Uso típico |
|-------------------|-------|------------|
| `raw` | -300 | Antes do conntrack |
| `mangle` | -150 | Modificação de pacotes |
| `dstnat` | -100 | DNAT (port forwarding) |
| `filter` | 0 | Filtragem padrão |
| `srcnat` | 100 | SNAT/masquerade |

### Políticas padrão

Define o que acontece com pacotes que não casam com nenhuma regra:

- `accept` — deixa passar (default permissivo)
- `drop` — descarta silenciosamente
- `reject` — descarta e envia mensagem de erro ICMP

---

## 2. Instalação e primeiros passos

```bash
# Instalar
sudo apt install nftables -y          # Debian/Ubuntu
sudo dnf install nftables -y          # RHEL/Fedora

# Habilitar e iniciar
sudo systemctl enable --now nftables

# Verificar regras atuais
sudo nft list ruleset

# Verificar tabelas existentes
sudo nft list tables

# Verificar uma tabela específica
sudo nft list table inet filter
```

---

## 3. Estrutura de um arquivo de configuração

O arquivo principal é `/etc/nftables.conf`. Sempre edite via arquivo — nunca aplique regras isoladas em produção sem refletir no arquivo, pois serão perdidas no reboot.

```bash
sudo nano /etc/nftables.conf
```

Estrutura base recomendada para um servidor:

```nftables
#!/usr/sbin/nft -f

# Limpa todas as regras antes de aplicar
flush ruleset

table inet filter {

    # Chain para tráfego de entrada
    chain input {
        type filter hook input priority filter; policy drop;

        # Aceita tráfego loopback
        iifname "lo" accept

        # Aceita conexões estabelecidas e relacionadas
        ct state established,related accept

        # Descarta pacotes inválidos
        ct state invalid drop

        # Aceita ICMP (ping)
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept

        # Aceita SSH
        tcp dport 22 accept
    }

    # Chain para tráfego encaminhado (roteamento)
    chain forward {
        type filter hook forward priority filter; policy drop;
    }

    # Chain para tráfego de saída
    chain output {
        type filter hook output priority filter; policy accept;
    }
}
```

Aplicar a configuração:

```bash
sudo nft -f /etc/nftables.conf

# Verificar se foi aplicada corretamente
sudo nft list ruleset

# Recarregar via systemd
sudo systemctl reload nftables
```

---

## 4. Sintaxe de regras

### Estrutura de uma regra

```
rule [handle N] [posição] expressão [declaração]
```

Exemplos de expressões (o que casa):

```nftables
ip saddr 192.168.1.0/24          # IP de origem
ip daddr 10.0.0.1                # IP de destino
tcp dport 80                     # porta TCP de destino
tcp sport 1024-65535             # faixa de portas de origem
udp dport { 53, 67, 68 }         # conjunto de portas UDP
iifname "eth0"                   # interface de entrada
oifname "eth1"                   # interface de saída
ct state established             # estado de conexão
```

Declarações (o que fazer quando casa):

```nftables
accept    # permite
drop      # descarta silenciosamente
reject    # descarta com mensagem ICMP
log       # registra no syslog
counter   # incrementa contador (para auditoria)
jump chain_name   # salta para outra chain
```

### Regras combinadas

```nftables
# IP específico, porta específica
ip saddr 10.0.0.5 tcp dport 22 accept

# Faixa de IPs
ip saddr 192.168.1.0/24 tcp dport { 80, 443 } accept

# Log antes de dropar
log prefix "nftables-drop: " level warn drop

# Contador com accept (auditoria sem bloquear)
tcp dport 443 counter accept
```

---

## 5. Gerenciamento de regras em tempo real

Em produção, às vezes é necessário adicionar ou remover regras sem recarregar o arquivo inteiro. Use handles para isso.

```bash
# Ver regras com handles (necessário para edição pontual)
sudo nft -a list ruleset

# Adicionar regra no final da chain
sudo nft add rule inet filter input tcp dport 8080 accept

# Adicionar regra no início da chain (insert)
sudo nft insert rule inet filter input tcp dport 8080 accept

# Adicionar regra após handle específico
sudo nft add rule inet filter input handle 10 tcp dport 8080 accept

# Remover regra pelo handle
sudo nft delete rule inet filter input handle 15

# Limpar todas as regras de uma chain
sudo nft flush chain inet filter input

# Limpar todas as regras de todas as tabelas
sudo nft flush ruleset
```

> **Atenção:** regras adicionadas via linha de comando são temporárias. Sempre reflita as mudanças no `/etc/nftables.conf` para que persistam após reboot.

---

## 6. Sets — agrupando endereços e portas

Sets permitem agrupar IPs, redes ou portas e referenciar o grupo em múltiplas regras. Isso elimina repetição e simplifica a manutenção.

### Sets anônimos (inline)

```nftables
# Múltiplas portas em uma regra
tcp dport { 22, 80, 443, 8080 } accept

# Múltiplos IPs
ip saddr { 192.168.1.10, 192.168.1.11, 10.0.0.5 } accept
```

### Sets nomeados (persistentes)

```nftables
table inet filter {

    # Definição do set
    set admin_hosts {
        type ipv4_addr
        elements = { 192.168.1.10, 192.168.1.11, 10.0.0.5 }
    }

    set web_ports {
        type inet_service
        elements = { 80, 443, 8443 }
    }

    chain input {
        type filter hook input priority filter; policy drop;

        # Usando os sets nas regras
        ip saddr @admin_hosts tcp dport 22 accept
        tcp dport @web_ports accept
    }
}
```

Gerenciando elementos de sets em tempo real:

```bash
# Adicionar elemento ao set
sudo nft add element inet filter admin_hosts { 192.168.1.15 }

# Remover elemento do set
sudo nft delete element inet filter admin_hosts { 192.168.1.15 }

# Listar elementos do set
sudo nft list set inet filter admin_hosts
```

---

## 7. Conntrack — rastreamento de conexões

O conntrack (connection tracking) é o mecanismo que permite ao nftables entender o estado de cada conexão, não apenas pacotes individuais.

```nftables
ct state established,related accept   # permite resposta de conexões iniciadas pelo sistema
ct state invalid drop                  # descarta pacotes que não pertencem a nenhuma conexão válida
ct state new tcp dport 22 accept      # permite apenas o início de novas conexões SSH
```

Estados do conntrack:

| Estado | Significado |
|--------|-------------|
| `new` | Primeiro pacote de uma nova conexão |
| `established` | Conexão em andamento (handshake concluído) |
| `related` | Conexão relacionada a uma existente (ex: FTP data) |
| `invalid` | Pacote que não pertence a nenhum estado rastreado |
| `untracked` | Conexão marcada para não ser rastreada |

---

## 8. Logging

Logging é essencial para auditoria e resposta a incidentes. Registre tráfego bloqueado para identificar tentativas de acesso não autorizado.

```nftables
chain input {
    type filter hook input priority filter; policy drop;

    iifname "lo" accept
    ct state established,related accept
    ct state invalid drop

    tcp dport 22 accept

    # Loga e descarta todo o resto
    log prefix "nftables-input-drop: " level warn flags all drop
}
```

```bash
# Ver logs gerados
sudo journalctl -k | grep "nftables"
sudo dmesg | grep "nftables"

# Monitorar em tempo real
sudo journalctl -k -f | grep "nftables"
```

Formato de log gerado:

```
nftables-input-drop: IN=eth0 OUT= MAC=... SRC=45.33.32.156 DST=192.168.1.10 
LEN=44 TOS=0x00 PREC=0x00 TTL=241 ID=54321 PROTO=TCP SPT=45678 DPT=3306 
WINDOW=1024 RES=0x00 SYN URGP=0
```

> **Ponto de segurança:** tentativas repetidas de acesso à porta 3306 (MySQL) ou 6379 (Redis) vindas de IPs externos, visíveis nos logs, indicam varredura automatizada. Com os IPs em mãos, você pode bloquear faixas inteiras com um set.

---

## 9. Configurações práticas completas

### Servidor web (HTTP/HTTPS + SSH restrito)

```nftables
#!/usr/sbin/nft -f

flush ruleset

table inet filter {

    set ssh_allowed {
        type ipv4_addr
        flags interval
        elements = { 192.168.1.0/24, 10.0.0.5 }
    }

    chain input {
        type filter hook input priority filter; policy drop;

        iifname "lo" accept
        ct state established,related accept
        ct state invalid drop

        ip protocol icmp icmp type { echo-request, echo-reply } accept
        ip6 nexthdr icmpv6 accept

        # SSH restrito a IPs autorizados
        ip saddr @ssh_allowed tcp dport 22 accept

        # Web público
        tcp dport { 80, 443 } accept

        # Log e drop do restante
        log prefix "nftables-drop: " level warn drop
    }

    chain forward {
        type filter hook forward priority filter; policy drop;
    }

    chain output {
        type filter hook output priority filter; policy accept;
    }
}
```

### Rate limiting — proteção contra força bruta

```nftables
chain input {
    type filter hook input priority filter; policy drop;

    iifname "lo" accept
    ct state established,related accept
    ct state invalid drop

    # Limita novas conexões SSH a 3 por minuto por IP
    tcp dport 22 ct state new limit rate 3/minute burst 5 packets accept
    tcp dport 22 ct state new log prefix "nftables-ssh-ratelimit: " drop

    tcp dport { 80, 443 } accept

    log prefix "nftables-drop: " level warn drop
}
```

### NAT / Port forwarding

```nftables
table ip nat {

    chain prerouting {
        type nat hook prerouting priority dstnat;

        # Redireciona porta 8080 externa para 80 interno
        tcp dport 8080 dnat to :80

        # Forward para servidor interno
        ip daddr 203.0.113.1 tcp dport 443 dnat to 192.168.1.100:443
    }

    chain postrouting {
        type nat hook postrouting priority srcnat;

        # Masquerade para saída à internet (gateway/roteador)
        oifname "eth0" masquerade
    }
}
```

---

## 10. Salvando e restaurando configurações

```bash
# Salvar estado atual para o arquivo de configuração
sudo nft list ruleset > /etc/nftables.conf

# Backup antes de alterações
sudo cp /etc/nftables.conf /etc/nftables.conf.bak.$(date +%Y%m%d)

# Testar nova configuração sem aplicar permanentemente
sudo nft -c -f /etc/nftables.conf     # -c = check only, não aplica

# Aplicar e verificar
sudo nft -f /etc/nftables.conf
sudo nft list ruleset
```

> **Prática recomendada em produção:** ao fazer alterações remotas via SSH, configure um cron job temporário para limpar as regras em 5 minutos. Se a nova configuração bloquear o acesso, o cron restaura. Cancele o cron após confirmar que o acesso continua funcionando.

```bash
# Agendamento de segurança antes de testar nova config
echo "sudo nft flush ruleset && sudo systemctl restart nftables" | at now + 5 minutes

# Aplicar nova configuração
sudo nft -f /etc/nftables.conf

# Se tudo funcionar, cancelar o agendamento
sudo atrm $(atq | awk '{print $1}')
```

---

## Lab — Coloque em prática

### Exercício 1 — Configuração base

Configure um firewall para um servidor com os seguintes requisitos:

- Política padrão de entrada: drop
- Aceitar loopback
- Aceitar conexões estabelecidas e relacionadas
- Descartar pacotes inválidos
- Aceitar SSH apenas da rede `192.168.1.0/24`
- Aceitar HTTP e HTTPS de qualquer origem
- Logar e descartar todo o resto

<details>
<summary>Ver gabarito</summary>

```nftables
#!/usr/sbin/nft -f

flush ruleset

table inet filter {

    chain input {
        type filter hook input priority filter; policy drop;

        iifname "lo" accept
        ct state established,related accept
        ct state invalid drop
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept
        ip saddr 192.168.1.0/24 tcp dport 22 accept
        tcp dport { 80, 443 } accept
        log prefix "nftables-drop: " level warn drop
    }

    chain forward {
        type filter hook forward priority filter; policy drop;
    }

    chain output {
        type filter hook output priority filter; policy accept;
    }
}
```
</details>

---

### Exercício 2 — Bloqueio dinâmico com set

Adicione ao firewall do exercício anterior um set chamado `blocklist` e insira o IP `45.33.32.156` nele. Crie uma regra que descarte silenciosamente qualquer tráfego originado desse set, antes de qualquer outra verificação.

<details>
<summary>Ver gabarito</summary>

```nftables
set blocklist {
    type ipv4_addr
    flags interval
    elements = { 45.33.32.156 }
}

chain input {
    type filter hook input priority filter; policy drop;

    # Blocklist no topo da chain
    ip saddr @blocklist drop

    iifname "lo" accept
    ct state established,related accept
    # ... restante das regras
}
```

```bash
# Adicionar IPs dinamicamente sem recarregar o arquivo
sudo nft add element inet filter blocklist { 198.51.100.0/24 }
```
</details>

---

### Exercício 3 — Análise de log

Gere tráfego bloqueado e analise os logs:

```bash
# Terminal 1: monitore os logs
sudo journalctl -k -f | grep "nftables-drop"

# Terminal 2: gere tráfego para portas bloqueadas
# (de outra máquina ou usando loopback para teste)
nc -zv localhost 3306
nc -zv localhost 6379
nc -zv localhost 8888
```

Identifique nos logs: IP de origem, porta de destino e protocolo de cada tentativa bloqueada.

---

## Checklist de segurança — firewall

- [ ] Política padrão da chain `input` configurada como `drop`
- [ ] Regra de `ct state invalid drop` presente antes das regras de accept
- [ ] SSH restrito a IPs ou redes específicas, não aberto para `0.0.0.0`
- [ ] Rate limiting em SSH para mitigar força bruta
- [ ] Logging ativo para tráfego descartado
- [ ] Configuração salva em `/etc/nftables.conf` e versionada
- [ ] Backup realizado antes de qualquer alteração em produção
- [ ] Regras testadas com `nft -c` antes de aplicar
- [ ] Serviço `nftables` habilitado no systemd para iniciar com o sistema

---

## Referências

- `man nft`
- [nftables Wiki — netfilter.org](https://wiki.nftables.org)
- [Red Hat — Getting started with nftables](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_firewalls_and_packet_filters/getting-started-with-nftables_firewall-packet-filters)
- [nftables Quick Reference](https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes)

---

<div align="center">

**Módulo anterior: [Comandos Essenciais de Rede](comandos-essenciais.md)**  
**Próximo módulo: [Análise de Tráfego](analise-trafico.md)**

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-darkred?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-black?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

</div>