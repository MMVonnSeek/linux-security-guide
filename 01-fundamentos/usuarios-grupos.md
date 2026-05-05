[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Módulo 01 — Usuários, Grupos e Controle de Acesso

> **Pré-requisito:** [Processos no Linux](processos.md)  
> **Tempo estimado:** 50 minutos  
> **Distro testada:** Ubuntu 22.04 / RHEL 9 / Debian 12

---

## Por que este módulo é base para segurança?

Escalonamento de privilégios, movimentação lateral e persistência — os três pilares de qualquer ataque pós-exploração — exploram diretamente falhas na configuração de usuários, grupos e sudo. Antes de configurar firewall ou auditoria, o sistema de identidade local precisa estar correto.

---

## 1. Arquivos fundamentais

Quatro arquivos controlam toda a identidade local do sistema. Conhecê-los em detalhe é obrigatório.

### /etc/passwd — cadastro de usuários

```bash
cat /etc/passwd
```

Formato de cada linha:

```
root:x:0:0:root:/root:/bin/bash
 │   │ │ │  │     │       └── shell padrão
 │   │ │ │  │     └────────── diretório home
 │   │ │ │  └──────────────── comentário (GECOS)
 │   │ │ └─────────────────── GID primário
 │   │ └───────────────────── UID
 │   └───────────────────────  x = senha em /etc/shadow
 └───────────────────────────── nome do usuário
```

UIDs com significado especial:

| Faixa | Tipo |
|-------|------|
| 0 | root |
| 1–999 | contas de sistema e serviços |
| 1000+ | usuários humanos reais |
| 65534 | nobody — usuário sem privilégios |

> **Ponto de segurança:** qualquer conta com UID 0 além de root é uma backdoor. Verifique com: `awk -F: '$3 == 0' /etc/passwd`

### /etc/shadow — senhas criptografadas

```bash
sudo cat /etc/shadow
```

Formato:

```
max:$6$salt$hash:19500:0:99999:7:::
 │      │          │   │   │   └── dias até expirar conta
 │      │          │   │   └────── dias para aviso de expiração
 │      │          │   └────────── mínimo de dias entre trocas
 │      │          └────────────── dias desde 01/01/1970 da última troca
 │      └───────────────────────── hash da senha ($6$ = SHA-512)
 └──────────────────────────────── nome do usuário
```

Prefixos de algoritmo de hash:

| Prefixo | Algoritmo | Status |
|---------|-----------|--------|
| `$1$` | MD5 | Inseguro — nunca use |
| `$5$` | SHA-256 | Aceitável |
| `$6$` | SHA-512 | Padrão recomendado |
| `$y$` | yescrypt | Moderno — RHEL 9, Ubuntu 22.04+ |

> **Ponto de segurança:** contas com `!` ou `*` no campo de senha estão bloqueadas para login por senha. Contas com campo vazio (`::`) não têm senha — risco crítico.

```bash
# Detectar contas sem senha
sudo awk -F: '$2 == ""' /etc/shadow

# Detectar contas com hash MD5 (legado inseguro)
sudo awk -F: '$2 ~ /^\$1\$/' /etc/shadow
```

### /etc/group — cadastro de grupos

```bash
cat /etc/group
```

Formato:

```
sudo:x:27:max,aluno1
  │  │  │   └── membros adicionais
  │  │  └────── GID
  │  └────────── x = senha (raramente usada)
  └──────────── nome do grupo
```

### /etc/gshadow — senhas de grupos

Raramente manipulado diretamente, mas relevante para auditoria:

```bash
sudo cat /etc/gshadow
```

---

## 2. Gerenciando usuários

### Criação

```bash
# Forma recomendada — cria home, shell e estrutura completa
sudo useradd -m -s /bin/bash -c "Analista de Segurança" -G sudo,adm joao

# Parâmetros importantes
# -m          cria diretório home em /home/nome
# -s          define o shell padrão
# -c          comentário/descrição (campo GECOS)
# -G          grupos secundários (separados por vírgula)
# -u          define UID manualmente
# -e          data de expiração da conta (YYYY-MM-DD)
# -r          cria conta de sistema (UID < 1000, sem home)

# Definir senha imediatamente após criar
sudo passwd joao

# Criar conta de serviço sem shell (para daemons)
sudo useradd -r -s /usr/sbin/nologin -M meu-servico
```

### Modificação

```bash
sudo usermod -aG docker joao        # adiciona ao grupo docker (sem remover dos outros)
sudo usermod -s /bin/zsh joao       # muda o shell
sudo usermod -L joao                # bloqueia a conta (Lock)
sudo usermod -U joao                # desbloqueia a conta (Unlock)
sudo usermod -e 2025-12-31 joao     # define expiração
sudo usermod -l novonome joao       # renomeia o usuário
```

> **Atenção:** `usermod -G grupo joao` (sem `-a`) **substitui** todos os grupos secundários. Sempre use `-aG` para adicionar sem remover.

### Remoção

```bash
sudo userdel joao               # remove o usuário mas mantém o home
sudo userdel -r joao            # remove o usuário E o diretório home
sudo userdel -r -f joao         # força remoção mesmo com processos ativos

# Antes de remover, verificar arquivos do usuário no sistema
find / -user joao 2>/dev/null
find / -uid 1001 2>/dev/null    # busca por UID caso o usuário já não exista
```

### Expiração e envelhecimento de senhas

```bash
sudo chage -l joao              # lista política de senha do usuário
sudo chage -M 90 joao           # senha expira em 90 dias
sudo chage -m 7 joao            # mínimo de 7 dias entre trocas
sudo chage -W 14 joao           # avisa 14 dias antes de expirar
sudo chage -E 2025-12-31 joao   # conta expira na data
sudo chage -E -1 joao           # remove expiração da conta
sudo chage -d 0 joao            # força troca de senha no próximo login
```

---

## 3. Gerenciando grupos

```bash
sudo groupadd seguranca                     # cria grupo
sudo groupadd -g 1500 seguranca             # cria com GID específico
sudo groupdel seguranca                     # remove grupo (não remove usuários)
sudo groupmod -n sec-team seguranca         # renomeia grupo

# Adicionar/remover membros
sudo gpasswd -a joao seguranca              # adiciona joao ao grupo
sudo gpasswd -d joao seguranca              # remove joao do grupo
sudo gpasswd -M joao,maria,pedro seguranca  # define lista completa de membros

# Verificar grupos de um usuário
groups joao
id joao
```

> **Atenção:** alterações de grupo só têm efeito em novas sessões. O usuário precisa fazer logout e login para que o novo grupo apareça em `id`.

---

## 4. sudo — controle de privilégios elevados

### Estrutura do sudoers

O arquivo `/etc/sudoers` **nunca deve ser editado diretamente**. Use sempre `visudo`, que valida a sintaxe antes de salvar.

```bash
sudo visudo
```

Formato de uma regra:

```
usuário  host=(usuário_alvo:grupo_alvo)  comando
  │        │          │                     └── o que pode executar
  │        │          └──────────────────────── como quem pode executar
  │        └─────────────────────────────────── em qual host
  └──────────────────────────────────────────── quem recebe a permissão
```

### Exemplos práticos

```bash
# Acesso total (equivale a ser root)
joao ALL=(ALL:ALL) ALL

# Sem senha (conveniente, mas arriscado)
joao ALL=(ALL:ALL) NOPASSWD: ALL

# Apenas comandos específicos
joao ALL=(ALL) /usr/bin/systemctl restart nginx, /usr/bin/journalctl

# Grupo inteiro (recomendado — gerencie pelo grupo, não por usuário)
%seguranca ALL=(ALL) /usr/bin/tcpdump, /usr/bin/nmap

# Proibir comando específico mesmo com acesso amplo
joao ALL=(ALL) ALL, !/bin/su, !/usr/bin/passwd root
```

### Arquivos drop-in — a forma correta em produção

Em vez de editar `/etc/sudoers` diretamente, crie arquivos em `/etc/sudoers.d/`:

```bash
sudo visudo -f /etc/sudoers.d/equipe-seguranca
```

Isso permite gerenciar permissões por equipe ou função sem tocar no arquivo principal.

```bash
# Listar regras efetivas do usuário atual
sudo -l

# Listar regras de outro usuário (requer root)
sudo -l -U joao
```

> **Ponto de segurança:** `NOPASSWD` em sudoers elimina uma camada de verificação. Em servidores de produção, exija sempre a senha. Reserve `NOPASSWD` apenas para automação com contas de serviço e apenas para os comandos estritamente necessários.

---

## 5. Princípio do menor privilégio na prática

O princípio do menor privilégio determina que cada usuário, processo e serviço deve ter apenas as permissões mínimas necessárias para sua função.

### Contas de serviço

```bash
# Crie uma conta dedicada para cada serviço — nunca rode serviços como root
sudo useradd -r -s /usr/sbin/nologin -M -d /nonexistent app-backend

# Verifique que o serviço roda com o usuário correto
ps aux | grep app-backend
```

### Shell restrito para usuários de acesso limitado

```bash
# Usuário que só faz transferência de arquivos (SFTP)
sudo useradd -s /usr/sbin/nologin joao-sftp

# Verificar shells válidos no sistema
cat /etc/shells
```

### Revisão periódica de acesso

```bash
# Quem tem acesso ao sudo?
grep -E "^sudo|^wheel" /etc/group
getent group sudo

# Quem pode fazer login com shell válido?
grep -v "/nologin\|/false" /etc/passwd

# Contas que nunca fizeram login (possíveis órfãs)
sudo lastlog | grep "Never logged"

# Últimos logins
last | head -20
lastb | head -20    # tentativas falhas de login
```

---

## 6. PAM — Pluggable Authentication Modules

PAM é a camada que controla como a autenticação acontece no Linux. Entendê-lo é necessário para implementar políticas de senha e bloqueio de conta.

```bash
ls /etc/pam.d/          # um arquivo por serviço
cat /etc/pam.d/sshd     # política de autenticação do SSH
cat /etc/pam.d/sudo     # política de autenticação do sudo
```

### Política de senha com pam_pwquality

```bash
sudo apt install libpam-pwquality    # Debian/Ubuntu
sudo dnf install pam_pwquality       # RHEL/Fedora

sudo nano /etc/security/pwquality.conf
```

Configurações recomendadas:

```ini
minlen = 12          # mínimo de 12 caracteres
dcredit = -1         # pelo menos 1 número
ucredit = -1         # pelo menos 1 maiúscula
lcredit = -1         # pelo menos 1 minúscula
ocredit = -1         # pelo menos 1 caractere especial
maxrepeat = 3        # máximo de 3 caracteres repetidos consecutivos
gecoscheck = 1       # proíbe uso do nome do usuário na senha
dictcheck = 1        # verifica contra dicionário
```

### Bloqueio de conta por tentativas falhas

```bash
sudo nano /etc/security/faillock.conf
```

```ini
deny = 5             # bloqueia após 5 tentativas falhas
unlock_time = 900    # desbloqueia após 15 minutos
fail_interval = 900  # janela de tempo para contar tentativas
```

```bash
# Ver status de bloqueio de um usuário
faillock --user joao

# Desbloquear manualmente
sudo faillock --user joao --reset
```

---

## Lab — Coloque em prática

### Exercício 1 — Auditoria de contas

Execute os comandos abaixo e interprete cada resultado:

```bash
# 1. Contas com UID 0
awk -F: '$3 == 0' /etc/passwd

# 2. Contas sem senha definida
sudo awk -F: '$2 == ""' /etc/shadow

# 3. Contas com shell de login válido
grep -v "/nologin\|/false\|/sync" /etc/passwd | cut -d: -f1,7

# 4. Membros do grupo sudo/wheel
getent group sudo wheel
```

<details>
<summary>O que analisar em cada resultado</summary>

1. Somente `root` deve aparecer. Qualquer outro usuário com UID 0 é uma backdoor.
2. Qualquer conta listada aqui permite login sem senha — risco crítico, bloqueie imediatamente com `sudo passwd -l <usuario>`.
3. Apenas usuários humanos ativos devem ter shell de login. Contas de serviço devem usar `/usr/sbin/nologin`.
4. Apenas usuários que realmente precisam de acesso administrativo devem estar nesses grupos.
</details>

---

### Exercício 2 — Configuração de conta de serviço

Crie um usuário para simular um serviço web seguindo o princípio do menor privilégio:

```bash
# 1. Crie a conta de serviço
sudo useradd -r -s /usr/sbin/nologin -M -d /var/www -c "Web Application Service" webapp

# 2. Verifique que não é possível fazer login
su - webapp
sudo -u webapp /bin/bash

# 3. Confirme as propriedades da conta
id webapp
grep webapp /etc/passwd
```

<details>
<summary>Ver gabarito</summary>

```bash
# O login deve falhar com:
# su: warning: cannot change directory to /var/www: No such file or directory
# This account is currently not available.

# A conta deve aparecer em /etc/passwd como:
# webapp:x:999:999:Web Application Service:/var/www:/usr/sbin/nologin
```
</details>

---

### Exercício 3 — Regra sudo restrita

Configure o sudo para que o usuário `webapp` possa apenas reiniciar o nginx, sem senha, sem acesso a nenhum outro comando:

<details>
<summary>Ver gabarito</summary>

```bash
sudo visudo -f /etc/sudoers.d/webapp

# Conteúdo do arquivo:
webapp ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx

# Teste:
sudo -l -U webapp
sudo -u webapp systemctl restart nginx      # deve funcionar
sudo -u webapp systemctl restart sshd       # deve falhar
```
</details>

---

## Checklist de segurança — usuários e grupos

- [ ] Nenhum usuário com UID 0 além de root
- [ ] Nenhuma conta com campo de senha vazio em `/etc/shadow`
- [ ] Senhas usando SHA-512 (`$6$`) ou yescrypt (`$y$`) — sem MD5 (`$1$`)
- [ ] Contas de serviço com shell `/usr/sbin/nologin` e sem diretório home
- [ ] Grupo sudo/wheel com apenas usuários que realmente precisam
- [ ] Regras sudoers por grupo, não por usuário individual
- [ ] Sem `NOPASSWD` para comandos amplos em contas humanas
- [ ] Política de senha configurada via `pam_pwquality`
- [ ] Bloqueio de conta após tentativas falhas configurado via `faillock`
- [ ] Revisão periódica de `lastlog` para identificar contas inativas

---

## Referências

- `man useradd` / `man usermod` / `man sudoers` / `man pam`
- [Red Hat — Managing Users and Groups](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_basic_system_settings/managing-users-and-groups)
- [CIS Benchmark — Linux](https://www.cisecurity.org/cis-benchmarks)

---

<div align="center">

**Módulo anterior: [Processos no Linux](processos.md)**  
**Próximo módulo: [Comandos Essenciais de Rede](../02-redes/comandos-essenciais.md)**

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-darkred?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-black?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

</div>