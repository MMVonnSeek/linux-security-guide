<!-- BADGES DE IDENTIDADE -->
[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/←_Voltar-Repositório_Principal-blue?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Módulo 01 — Permissões no Linux

> **Pré-requisito:** Saber navegar no terminal (cd, ls, pwd)  
> **Tempo estimado:** 40 minutos de leitura + labs  
> **Distro testada:** Ubuntu 22.04 / Debian 12

---

## Por que permissões importam para segurança?

A maioria das vulnerabilidades de escalonamento de privilégios em Linux explora **permissões mal configuradas**. Entender esse sistema não é só administração de sistema — é a base de qualquer trabalho em segurança ofensiva ou defensiva.

---

## 1. O modelo de permissões do Linux

Todo arquivo e diretório no Linux tem três informações de propriedade:

```
-rwxr-xr-- 1 max professores 4096 Jan 10 09:00 script.sh
│└┬┘└┬┘└┬┘
│ │  │  └── outros (others)
│ │  └───── grupo (group)
│ └──────── dono (user/owner)
└────────── tipo: - arquivo | d diretório | l link simbólico
```

### As três permissões básicas

| Símbolo | Número | Em arquivo | Em diretório |
|---------|--------|------------|--------------|
| `r` | 4 | Lê o conteúdo | Lista os arquivos (`ls`) |
| `w` | 2 | Modifica o conteúdo | Cria/remove arquivos dentro |
| `x` | 1 | Executa | Entra no diretório (`cd`) |
| `-` | 0 | Sem permissão | Sem permissão |

---

## 2. Lendo permissões na prática

```bash
ls -la /etc/passwd
```
```
-rw-r--r-- 1 root root 2847 Jan 10 09:00 /etc/passwd
```

Lendo da esquerda para a direita:
- `-` → é um arquivo comum
- `rw-` → dono (root) pode ler e escrever
- `r--` → grupo (root) só pode ler
- `r--` → qualquer usuário só pode ler

> **Impacto de segurança:** `/etc/passwd` precisa ser legível por todos para que o sistema funcione, mas se estiver com `rw-rw-rw-` qualquer usuário poderia modificar e adicionar contas.

---

## 3. chmod — alterando permissões

### Modo octal (o mais usado no mercado)

Cada conjunto de permissões vira um número somando os valores:

```
rwx = 4+2+1 = 7
rw- = 4+2+0 = 6
r-x = 4+0+1 = 5
r-- = 4+0+0 = 4
--- = 0+0+0 = 0
```

```bash
# Sintaxe: chmod [dono][grupo][outros] arquivo
chmod 755 script.sh     # rwxr-xr-x  (script executável padrão)
chmod 644 arquivo.txt   # rw-r--r--  (arquivo de texto padrão)
chmod 600 chave.pem     # rw-------  (chave privada SSH — só o dono lê)
chmod 700 /home/max     # rwx------  (diretório pessoal restrito)
```

### Modo simbólico (mais legível)

```bash
# u=user, g=group, o=others, a=all
# +=adiciona, -=remove, ==define exato

chmod u+x script.sh          # adiciona execução para o dono
chmod g-w arquivo.conf       # remove escrita do grupo
chmod o= arquivo_secreto     # remove TUDO dos outros
chmod a+r documento.txt      # todos podem ler
chmod u=rw,g=r,o= config.txt # define tudo de uma vez
```

### Recursivo (cuidado!)

```bash
chmod -R 755 /var/www/html   # aplica em todos os arquivos e subpastas
```

> **Erro comum:** usar `chmod -R 777` em produção. Isso dá permissão total para qualquer usuário do sistema — nunca faça isso em servidor.

---

## 4. chown — alterando propriedade

```bash
# chown dono:grupo arquivo
chown max arquivo.txt              # muda só o dono
chown max:professores arquivo.txt  # muda dono e grupo
chown :professores arquivo.txt     # muda só o grupo
chown -R www-data:www-data /var/www # recursivo (servidor web)
```

---

## 5. Permissões especiais — onde mora o perigo

### SUID (Set User ID) — bit 4000

Quando um arquivo com SUID é executado, ele roda com os privilégios do **dono**, não do usuário que executou.

```bash
ls -la /usr/bin/passwd
-rwsr-xr-x 1 root root 68208 /usr/bin/passwd
#   ↑ s no lugar do x = SUID ativo
```

O `passwd` precisa do SUID porque precisa de acesso root para modificar `/etc/shadow`, mas qualquer usuário pode trocar sua própria senha.

```bash
# Encontrar todos os arquivos com SUID no sistema:
find / -perm -4000 -type f 2>/dev/null
```

> **Risco de segurança:** Arquivos com SUID pertencentes a root que podem ser manipulados são vetores clássicos de escalonamento de privilégios. Essa busca é uma das primeiras coisas que um pentester faz após ganhar acesso a um sistema.

### SGID (Set Group ID) — bit 2000

Semelhante ao SUID, mas aplica o **grupo** do arquivo/diretório.

```bash
# Em diretórios: novos arquivos criados herdam o grupo do diretório
chmod g+s /projetos/equipe

# Encontrar SGID:
find / -perm -2000 -type f 2>/dev/null
```

### Sticky Bit — bit 1000

Em diretórios, impede que um usuário delete arquivos de **outros usuários**, mesmo tendo permissão de escrita no diretório.

```bash
ls -la /tmp
drwxrwxrwt ... /tmp
#         ↑ t = sticky bit ativo

# Sem sticky bit, qualquer usuário com acesso ao /tmp poderia
# deletar arquivos de outros usuários!

chmod +t /pasta/compartilhada
# ou
chmod 1777 /pasta/compartilhada
```

### Tabela resumo das permissões especiais

| Permissão | Octal | Em arquivo | Em diretório |
|-----------|-------|------------|--------------|
| SUID | 4000 | Executa como dono | (sem efeito) |
| SGID | 2000 | Executa como grupo | Novos arquivos herdam grupo |
| Sticky | 1000 | (sem efeito) | Só dono deleta seu arquivo |

---

## 6. umask — permissão padrão ao criar arquivos

A `umask` define quais permissões são **removidas** por padrão na criação de novos arquivos.

```bash
umask        # ver valor atual (geralmente 022)
umask 027    # define nova umask para a sessão
```

**Como calcular:**
- Arquivo base: `666` (rw-rw-rw-)
- Diretório base: `777` (rwxrwxrwx)
- Resultado: base - umask

```
umask 022:
  Arquivo:    666 - 022 = 644 (rw-r--r--)
  Diretório:  777 - 022 = 755 (rwxr-xr-x)

umask 027:
  Arquivo:    666 - 027 = 640 (rw-r-----)
  Diretório:  777 - 027 = 750 (rwxr-x---)
```

> **Boa prática em servidores:** usar `umask 027` para que arquivos criados não fiquem acessíveis a "outros usuários" por padrão.

---

## 7. Verificando permissões de forma eficiente

```bash
# Ver permissões em formato octal
stat -c "%a %n" arquivo.txt

# Ver permissões de vários arquivos de uma vez
stat -c "%a %U:%G %n" /etc/passwd /etc/shadow /etc/sudoers

# Encontrar arquivos sem dono (possível resquício de usuário deletado)
find / -nouser -o -nogroup 2>/dev/null

# Arquivos world-writable (qualquer um pode escrever) — risco de segurança
find / -perm -o+w -type f -not -path "/proc/*" 2>/dev/null
```

---

## Lab — Coloque em prática

### Preparação

```bash
mkdir ~/lab-permissoes && cd ~/lab-permissoes
touch arquivo1.txt arquivo2.sh config.conf
mkdir pasta_equipe
```

### Exercícios

**Exercício 1 — Permissões básicas**
Configure as permissões abaixo e verifique com `ls -la`:
- `arquivo1.txt` → dono lê/escreve, grupo só lê, outros sem acesso
- `arquivo2.sh` → dono tem tudo, grupo lê/executa, outros sem acesso
- `config.conf` → só o dono lê (chave privada simulada)

<details>
<summary>👁️ Ver gabarito</summary>

```bash
chmod 640 arquivo1.txt
chmod 750 arquivo2.sh
chmod 400 config.conf
```
</details>

---

**Exercício 2 — Sticky Bit em diretório compartilhado**

Crie dois usuários de teste, configure o diretório com sticky bit e tente deletar o arquivo do outro usuário.

```bash
# Crie o ambiente (requer sudo)
sudo useradd -m aluno1
sudo useradd -m aluno2
sudo mkdir /tmp/compartilhado
sudo chmod 1777 /tmp/compartilhado

# Teste como aluno1
sudo -u aluno1 touch /tmp/compartilhado/arquivo_aluno1.txt

# Tente deletar como aluno2 — deve falhar!
sudo -u aluno2 rm /tmp/compartilhado/arquivo_aluno1.txt
```

<details>
<summary>👁️ O que deve acontecer</summary>

```
rm: cannot remove '/tmp/compartilhado/arquivo_aluno1.txt': Operation not permitted
```

Sem o sticky bit, `aluno2` conseguiria deletar o arquivo de `aluno1` por ter permissão de escrita no diretório. Com sticky bit, só o dono do arquivo (ou root) pode deletar.
</details>

---

**Exercício 3 — Caça ao SUID**

```bash
# Liste todos os binários SUID do sistema
find /usr/bin /usr/sbin -perm -4000 -type f 2>/dev/null

# Pesquise cada um que encontrar:
# - Por que esse binário precisa de SUID?
# - Existe algum exploit conhecido para ele?
```

---

## Checklist de segurança — permissões

Antes de colocar um servidor em produção, verifique:

- [ ] Nenhum arquivo com `777` fora de `/tmp`
- [ ] `/tmp` e `/var/tmp` com sticky bit (`1777`)
- [ ] Arquivos de configuração sensíveis com `600` ou `640`
- [ ] Binários SUID mapeados e justificados
- [ ] `umask` configurada como `027` em `/etc/profile`
- [ ] Sem arquivos `world-writable` fora de diretórios temporários
- [ ] Sem arquivos sem dono (`-nouser`)

---

## Referências

- `man chmod` / `man chown` / `man umask`
- [Linux Permissions — The Definitive Guide](https://linuxhandbook.com/linux-file-permissions/)
- [GTFOBins — SUID exploitation](https://gtfobins.github.io/)

---

<div align="center">

**Próximo módulo → [Processos no Linux](../01-fundamentos/processos.md)**

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/❤️_Apoie_este_projeto-Sponsor-ea4aaa?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)

</div>