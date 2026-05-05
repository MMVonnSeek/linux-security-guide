[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Lab 02 — Firewall com nftables do Zero

> **Módulo de referência:** [Firewall com nftables](../02-redes/firewall-nftables.md)  
> **Nível:** Intermediário  
> **Tempo estimado:** 60 minutos  
> **Requisitos:** Sistema Linux com acesso sudo e nftables instalado

---

## Objetivo

Ao concluir este lab, você será capaz de:

- Construir um conjunto de regras nftables do zero, sem template
- Aplicar, testar e reverter configurações de firewall com segurança
- Usar sets para gerenciar listas de IPs e portas dinamicamente
- Implementar rate limiting contra força bruta
- Ler e interpretar logs de firewall para identificar tráfego bloqueado

---

## Preparação do ambiente

```bash
# Verificar se nftables está instalado e ativo
sudo nft --version
sudo systemctl status nftables

# Instalar se necessário
sudo apt install nftables -y      # Debian/Ubuntu
sudo dnf install nftables -y      # RHEL/Fedora

# Salvar estado atual das regras (backup antes de qualquer alteração)
sudo nft list ruleset > ~/nftables_backup_$(date +%Y%m%d_%H%M%S).txt
echo "Backup salvo em ~/nftables_backup_*.txt"

# Ver regras atuais
sudo nft list ruleset
```

---

## Exercício 1 — Construindo a estrutura base

**Objetivo:** criar do zero a estrutura de tabela e chains sem nenhuma regra ainda.

### Parte A — Criando a tabela e chains manualmente

```bash
# Limpar todas as regras existentes
sudo nft flush ruleset

# Criar a tabela
sudo nft add table inet filter

# Criar as três chains base
sudo nft add chain inet filter input \
    '{ type filter hook input priority filter; policy drop; }'

sudo nft add chain inet filter forward \
    '{ type filter hook forward priority filter; policy drop; }'

sudo nft add chain inet filter output \
    '{ type filter hook output priority filter; policy accept; }'

# Verificar estrutura criada
sudo nft list ruleset
```

> **Atenção:** com a política `drop` na chain `input` e sem nenhuma regra, você acabou de bloquear toda a conectividade de entrada, incluindo SSH. Continue imediatamente com a Parte B.

### Parte B — Adicionando as regras essenciais

```bash
# Regra 1: aceitar tráfego de loopback
sudo nft add rule inet filter input iifname "lo" accept

# Regra 2: aceitar conexões estabelecidas e relacionadas
sudo nft add rule inet filter input ct state established,related accept

# Regra 3: descartar pacotes inválidos
sudo nft add rule inet filter input ct state invalid drop

# Regra 4: aceitar ICMP
sudo nft add rule inet filter input ip protocol icmp accept
sudo nft add rule inet filter input ip6 nexthdr icmpv6 accept

# Regra 5: aceitar SSH
sudo nft add rule inet filter input tcp dport 22 accept

# Verificar conectividade
ping -c 1 127.0.0.1
ssh localhost exit 2>/dev/null && echo "SSH OK" || echo "SSH indisponivel"
```

### Parte C — Verificando a estrutura com handles

```bash
# Ver regras com handles (necessário para editar regras específicas)
sudo nft -a list ruleset
```

Anote os handles de cada regra — você precisará deles nos próximos exercícios.

---

## Exercício 2 — Adicionando serviços web e validando

**Objetivo:** adicionar regras para HTTP e HTTPS e validar o funcionamento com nc.

```bash
# Adicionar HTTP e HTTPS
sudo nft add rule inet filter input tcp dport { 80, 443 } accept

# Verificar que as regras foram adicionadas
sudo nft list chain inet filter input

# Testar conectividade nas portas (em segundo terminal ou com nc local)
# Simulando um servidor web ouvindo na porta 80
nc -lvp 80 &
NC_PID=$!
sleep 1

# Testar conexão
nc -zv localhost 80 && echo "Porta 80 ACESSIVEL" || echo "Porta 80 BLOQUEADA"

# Encerrar servidor de teste
kill $NC_PID 2>/dev/null
```

---

## Exercício 3 — Salvando para arquivo e aplicando via arquivo

**Objetivo:** migrar das regras aplicadas manualmente para um arquivo de configuração versionável.

```bash
# Exportar regras atuais para arquivo
sudo nft list ruleset > /tmp/meu-firewall.nft

# Ver o arquivo gerado
cat /tmp/meu-firewall.nft

# Limpar regras
sudo nft flush ruleset

# Reaplicar a partir do arquivo
sudo nft -f /tmp/meu-firewall.nft

# Confirmar que foram aplicadas
sudo nft list ruleset

# Mover para o local definitivo
sudo cp /tmp/meu-firewall.nft /etc/nftables.conf

# Testar sintaxe sem aplicar
sudo nft -c -f /etc/nftables.conf && echo "Sintaxe OK"
```

---

## Exercício 4 — Implementando sets para controle de acesso

**Objetivo:** refatorar as regras usando sets nomeados para tornar a configuração gerenciável.

Edite `/etc/nftables.conf` para adicionar sets:

```bash
sudo nano /etc/nftables.conf
```

O arquivo deve ficar assim:

```nftables
#!/usr/sbin/nft -f

flush ruleset

table inet filter {

    # Set de IPs com acesso SSH autorizado
    set ssh_allowed {
        type ipv4_addr
        flags interval
        elements = { 127.0.0.0/8 }
    }

    # Set de portas web abertas publicamente
    set web_ports {
        type inet_service
        elements = { 80, 443 }
    }

    # Blocklist para IPs banidos manualmente
    set blocklist {
        type ipv4_addr
        flags interval
    }

    chain input {
        type filter hook input priority filter; policy drop;

        # Blocklist — sempre no topo
        ip saddr @blocklist drop

        iifname "lo" accept
        ct state established,related accept
        ct state invalid drop

        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept

        # SSH restrito ao set
        ip saddr @ssh_allowed tcp dport 22 accept

        # Web público via set
        tcp dport @web_ports accept

        # Log e drop
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

```bash
# Testar sintaxe
sudo nft -c -f /etc/nftables.conf && echo "Sintaxe OK"

# Aplicar
sudo nft -f /etc/nftables.conf

# Verificar sets criados
sudo nft list sets

# Adicionar sua rede local ao set ssh_allowed
sudo nft add element inet filter ssh_allowed { 192.168.0.0/16 }

# Verificar elementos do set
sudo nft list set inet filter ssh_allowed
```

---

## Exercício 5 — Rate limiting contra força bruta SSH

**Objetivo:** implementar rate limiting para limitar tentativas de conexão SSH a 3 por minuto por IP.

Adicione as seguintes regras no lugar da regra simples de SSH no arquivo:

```nftables
# Substituir a linha:
# ip saddr @ssh_allowed tcp dport 22 accept
# Por:

ip saddr @ssh_allowed tcp dport 22 ct state new \
    limit rate 3/minute burst 5 packets accept

ip saddr @ssh_allowed tcp dport 22 ct state new \
    log prefix "nftables-ssh-ratelimit: " level warn drop
```

```bash
# Aplicar
sudo nft -f /etc/nftables.conf

# Simular múltiplas conexões rápidas para testar o rate limit
for i in $(seq 1 8); do
    nc -zv -w1 localhost 22 2>&1 | grep -E "succeeded|refused|timed"
    sleep 0.2
done

# Verificar que o rate limit foi acionado nos logs
sudo journalctl -k | grep "nftables-ssh-ratelimit" | tail -5
```

---

## Exercício 6 — Testando e lendo logs

**Objetivo:** gerar tráfego bloqueado deliberadamente e interpretar os logs gerados.

```bash
# Terminal 1: monitorar logs em tempo real
sudo journalctl -k -f | grep "nftables"
```

Em outro terminal:

```bash
# Gerar tráfego para portas bloqueadas
nc -zv localhost 3306 2>&1    # MySQL — deve ser bloqueado
nc -zv localhost 6379 2>&1    # Redis — deve ser bloqueado
nc -zv localhost 8080 2>&1    # HTTP alternativo — deve ser bloqueado
nc -zv localhost 5432 2>&1    # PostgreSQL — deve ser bloqueado
```

Para cada entrada de log gerada, identifique:

| Campo no log | O que representa |
|-------------|-----------------|
| `IN=eth0` | Interface de entrada |
| `SRC=x.x.x.x` | IP de origem |
| `DST=x.x.x.x` | IP de destino |
| `DPT=3306` | Porta de destino |
| `PROTO=TCP` | Protocolo |
| `SYN` | Flag TCP SYN (início de conexão) |

---

## Exercício 7 — Blocklist dinâmica

**Objetivo:** bloquear um IP dinamicamente sem recarregar toda a configuração.

```bash
# Adicionar IP à blocklist (sem recarregar o arquivo)
sudo nft add element inet filter blocklist { 198.51.100.1 }

# Verificar que foi adicionado
sudo nft list set inet filter blocklist

# Testar que o IP está bloqueado
# (em um ambiente real, isso seria testado de outra máquina)

# Adicionar uma rede inteira
sudo nft add element inet filter blocklist { 198.51.100.0/24 }

# Remover um IP específico da blocklist
sudo nft delete element inet filter blocklist { 198.51.100.1 }

# Listar novamente
sudo nft list set inet filter blocklist
```

> **Importante:** alterações feitas com `nft add element` são temporárias. Para persistir, exporte as regras atuais para o arquivo de configuração após as alterações.

```bash
# Persistir estado atual
sudo nft list ruleset > /etc/nftables.conf
```

---

## Exercício 8 — Simulação de alteração segura em produção

**Objetivo:** praticar o procedimento seguro de alteração de firewall em um servidor remoto.

```bash
# Passo 1: Fazer backup da configuração atual
sudo cp /etc/nftables.conf /etc/nftables.conf.bak.$(date +%Y%m%d_%H%M%S)

# Passo 2: Agendar reversão automática em 3 minutos
# (segurança caso a nova config bloqueie o acesso)
echo "sudo nft -f /etc/nftables.conf.bak.$(ls -t /etc/nftables.conf.bak.* | head -1 | cut -d. -f4)" \
    | at now + 3 minutes 2>/dev/null || \
    (sleep 180 && sudo nft -f $(ls -t /etc/nftables.conf.bak.* | head -1)) &
REVERT_PID=$!

# Passo 3: Aplicar nova configuração
sudo nft -f /etc/nftables.conf

# Passo 4: Verificar que o acesso ainda funciona
ping -c 1 127.0.0.1 && echo "Conectividade OK"

# Passo 5: Cancelar reversão automática
kill $REVERT_PID 2>/dev/null
sudo atrm $(atq | awk '{print $1}') 2>/dev/null
echo "Reversao automatica cancelada — configuracao confirmada"
```

---

## Desafio final

Configure um firewall completo para um servidor com os seguintes requisitos de negócio:

- Servidor web público (HTTP e HTTPS para qualquer origem)
- SSH acessível apenas da rede `10.0.0.0/8`
- Banco de dados MySQL acessível apenas de `10.0.0.100` e `10.0.0.101`
- Monitoramento via ICMP permitido apenas da rede `10.0.0.0/8`
- Rate limiting de 5 conexões por minuto em SSH
- Blocklist vazia pronta para uso
- Todo tráfego bloqueado deve ser logado com o prefixo `fw-drop:`

Escreva o arquivo `/etc/nftables.conf` completo do zero, teste a sintaxe com `nft -c` e aplique.

<details>
<summary>Ver gabarito</summary>

```nftables
#!/usr/sbin/nft -f

flush ruleset

table inet filter {

    set ssh_allowed {
        type ipv4_addr
        flags interval
        elements = { 10.0.0.0/8 }
    }

    set db_allowed {
        type ipv4_addr
        elements = { 10.0.0.100, 10.0.0.101 }
    }

    set icmp_allowed {
        type ipv4_addr
        flags interval
        elements = { 10.0.0.0/8 }
    }

    set blocklist {
        type ipv4_addr
        flags interval
    }

    chain input {
        type filter hook input priority filter; policy drop;

        ip saddr @blocklist drop

        iifname "lo" accept
        ct state established,related accept
        ct state invalid drop

        ip saddr @icmp_allowed ip protocol icmp accept
        ip6 nexthdr icmpv6 accept

        ip saddr @ssh_allowed tcp dport 22 ct state new \
            limit rate 5/minute burst 10 packets accept
        ip saddr @ssh_allowed tcp dport 22 ct state new \
            log prefix "fw-drop: " drop

        tcp dport { 80, 443 } accept

        ip saddr @db_allowed tcp dport 3306 accept

        log prefix "fw-drop: " level warn drop
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

## Limpeza do ambiente

```bash
# Restaurar backup original (se desejar voltar ao estado anterior ao lab)
sudo nft -f ~/nftables_backup_*.txt 2>/dev/null || sudo nft flush ruleset
```

---

## Perguntas de revisão

1. Por que a regra `ct state invalid drop` deve vir antes das regras de `accept`?
2. Qual a diferença entre `drop` e `reject` como política padrão? Quando usar cada um?
3. Se você adicionar um IP ao set `blocklist` via linha de comando e reiniciar o servidor, o IP ainda estará bloqueado? Por quê?
4. O que `limit rate 3/minute burst 5 packets` significa exatamente? O burst de 5 pacotes serve para quê?
5. Por que o arquivo `/etc/nftables.conf` começa com `flush ruleset`?

<details>
<summary>Respostas</summary>

1. Pacotes inválidos não pertencem a nenhuma conexão rastreada — se chegarem antes das regras de `established,related`, podem corresponder erroneamente a outros critérios. Descartar inválidos cedo evita processamento desnecessário e previne alguns tipos de evasão.

2. `drop` descarta silenciosamente — o cliente aguarda timeout sem resposta. `reject` envia ICMP port-unreachable — o cliente recebe resposta imediata de recusa. Use `drop` em interfaces públicas (não revela que o host existe). Use `reject` em redes internas onde o feedback rápido melhora a experiência sem risco.

3. Não. Elementos adicionados via linha de comando são somente em memória. Para persistir, é necessário exportar com `nft list ruleset > /etc/nftables.conf` após as alterações.

4. Permite no máximo 3 novas conexões por minuto de cada IP. O burst de 5 pacotes é uma tolerância inicial — os primeiros 5 pacotes passam imediatamente, depois o rate de 3/min é aplicado. Serve para não bloquear conexões legítimas que chegam em pequenas rajadas normais.

5. Para garantir que o estado inicial seja sempre limpo e conhecido. Sem `flush ruleset`, aplicar o arquivo sobre regras existentes pode resultar em regras duplicadas ou conflitantes. O `flush` garante que apenas as regras do arquivo estejam ativas após a aplicação.
</details>

---

<div align="center">

**Lab anterior: [Lab 01 — Permissões](lab-01-permissoes.md)**  
**Próximo lab: [Lab 03 — SSH Hardening](lab-03-ssh-hardening.md)**

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-darkred?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-black?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

</div>