[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Lab 01 — Permissões, SUID e Escalonamento de Privilégios

> **Módulo de referência:** [Permissões no Linux](../01-fundamentos/permissoes.md)  
> **Nível:** Iniciante — Intermediário  
> **Tempo estimado:** 45 minutos  
> **Requisitos:** Sistema Linux com acesso sudo, dois usuários de teste

---

## Objetivo

Ao concluir este lab, você será capaz de:

- Configurar permissões corretamente para diferentes cenários de uso
- Identificar configurações de permissão que representam risco de segurança
- Compreender na prática como SUID pode ser explorado para escalonamento de privilégios
- Executar uma varredura de segurança básica em permissões do sistema

---

## Preparação do ambiente

Execute os comandos abaixo antes de iniciar os exercícios. Todos os recursos criados serão removidos na etapa de limpeza ao final.

```bash
# Criar diretório de trabalho
mkdir -p ~/lab01 && cd ~/lab01

# Criar usuários de teste
sudo useradd -m -s /bin/bash aluno_a
sudo useradd -m -s /bin/bash aluno_b
sudo echo "aluno_a:senha123" | sudo chpasswd
sudo echo "aluno_b:senha123" | sudo chpasswd

# Criar grupo de projeto
sudo groupadd projeto_lab

# Adicionar aluno_a ao grupo
sudo usermod -aG projeto_lab aluno_a

# Confirmar criação
id aluno_a
id aluno_b
```

---

## Exercício 1 — Permissões básicas e seu impacto

**Objetivo:** compreender como cada bit de permissão afeta o acesso real ao arquivo.

### Parte A — Criando e testando arquivos

```bash
cd ~/lab01

# Criar arquivos de teste
echo "conteudo do arquivo secreto" > secreto.txt
echo "#!/bin/bash" > script.sh && echo "echo 'script executado'" >> script.sh
echo "dado publico" > publico.txt

# Estado inicial
ls -la
```

Configure cada arquivo conforme a tabela abaixo e teste cada caso:

| Arquivo | Permissão alvo | Octal | Teste esperado |
|---------|---------------|-------|----------------|
| `secreto.txt` | Só o dono lê e escreve | `600` | Outros usuários não conseguem ler |
| `script.sh` | Dono executa, outros só leem | `744` | Outros não conseguem executar |
| `publico.txt` | Todos leem, só dono escreve | `644` | Qualquer um lê, só dono altera |

```bash
# Aplique as permissões e verifique
chmod 600 secreto.txt
chmod 744 script.sh
chmod 644 publico.txt

ls -la
```

### Parte B — Testando como outro usuário

```bash
# Tentar acessar secreto.txt como aluno_a
sudo -u aluno_a cat ~/lab01/secreto.txt

# Tentar executar script.sh como aluno_a
sudo -u aluno_a bash ~/lab01/script.sh

# Tentar modificar publico.txt como aluno_a
sudo -u aluno_a bash -c "echo 'tentativa' >> ~/lab01/publico.txt"
```

<details>
<summary>Resultados esperados</summary>

```
# secreto.txt — deve retornar:
cat: /home/seu_usuario/lab01/secreto.txt: Permission denied

# script.sh — deve executar com sucesso (bash não exige bit x no script)
# IMPORTANTE: bash script.sh funciona mesmo sem bit x
# Para bloquear execução completamente, remova permissão de leitura também

# publico.txt — deve retornar:
bash: /home/seu_usuario/lab01/publico.txt: Permission denied
```

**Observação importante:** `bash script.sh` não exige o bit de execução — o bash é invocado diretamente e lê o script como entrada. O bit `x` é necessário apenas para `./script.sh`. Isso é relevante para segurança: remover apenas o bit `x` não impede a execução se o arquivo for legível.
</details>

---

## Exercício 2 — Diretório compartilhado com Sticky Bit

**Objetivo:** configurar um diretório compartilhado onde múltiplos usuários podem criar arquivos mas não podem excluir arquivos uns dos outros.

```bash
# Criar diretório compartilhado
sudo mkdir /opt/compartilhado
sudo chmod 1777 /opt/compartilhado

# Verificar a configuração
ls -la /opt/ | grep compartilhado
# Deve mostrar: drwxrwxrwt
```

### Testando o sticky bit

```bash
# Criar arquivo como aluno_a
sudo -u aluno_a touch /opt/compartilhado/arquivo_de_a.txt
sudo -u aluno_a echo "criado por aluno_a" > /opt/compartilhado/arquivo_de_a.txt

# Criar arquivo como aluno_b
sudo -u aluno_b touch /opt/compartilhado/arquivo_de_b.txt

# Listar conteúdo
ls -la /opt/compartilhado/

# Tentar deletar arquivo de aluno_a sendo aluno_b
sudo -u aluno_b rm /opt/compartilhado/arquivo_de_a.txt
```

<details>
<summary>Resultado esperado e análise</summary>

```
rm: cannot remove '/opt/compartilhado/arquivo_de_a.txt': Operation not permitted
```

O sticky bit (`t` no campo de outros) garante que apenas o dono do arquivo ou root podem deletá-lo, mesmo que o diretório tenha permissão de escrita para todos. Este é exatamente o comportamento do `/tmp` no sistema.

Verifique: `ls -la / | grep tmp` — deve mostrar `drwxrwxrwt`.
</details>

---

## Exercício 3 — SGID em diretório de projeto

**Objetivo:** configurar um diretório onde todos os arquivos criados herdam automaticamente o grupo do diretório, independente do grupo primário do usuário que os criou.

```bash
# Criar diretório do projeto
sudo mkdir /opt/projeto_equipe
sudo chown root:projeto_lab /opt/projeto_equipe
sudo chmod 2775 /opt/projeto_equipe

# Verificar
ls -la /opt/ | grep projeto_equipe
# Deve mostrar: drwxrwsr-x ... projeto_lab

# Testar criação de arquivo como aluno_a (membro do grupo projeto_lab)
sudo -u aluno_a touch /opt/projeto_equipe/arquivo_aluno_a.txt
ls -la /opt/projeto_equipe/

# Qual grupo pertence o arquivo criado?
```

<details>
<summary>Resultado esperado e análise</summary>

```
-rw-rw-r-- 1 aluno_a projeto_lab 0 ... arquivo_aluno_a.txt
```

O arquivo pertence ao grupo `projeto_lab` mesmo que o grupo primário de `aluno_a` seja diferente. Isso é o SGID em diretório — garante que toda a equipe tenha acesso aos arquivos sem precisar que cada usuário configure manualmente o grupo na criação.

Sem SGID: o arquivo herdaria o grupo primário do usuário que o criou, quebrando o acesso compartilhado.
</details>

---

## Exercício 4 — Identificando SUID no sistema

**Objetivo:** localizar binários com SUID, entender por que cada um precisa dessa permissão e identificar quais representam risco.

```bash
# Listar todos os binários SUID do sistema
sudo find /usr/bin /usr/sbin /bin /sbin -perm -4000 -type f 2>/dev/null | sort
```

Para cada binário encontrado, pesquise:

1. Qual a função desse binário?
2. Por que ele precisa de SUID (acesso como root)?
3. Existe alguma técnica de exploração documentada no [GTFOBins](https://gtfobins.github.io/)?

### Binários SUID comuns e sua justificativa

| Binário | Motivo do SUID |
|---------|---------------|
| `/usr/bin/passwd` | Precisa escrever em `/etc/shadow` (dono: root) |
| `/usr/bin/sudo` | Precisa elevar privilégios para root |
| `/usr/bin/su` | Precisa autenticar e trocar de usuário |
| `/usr/bin/ping` | Precisa criar sockets raw (requer root) |
| `/usr/bin/newgrp` | Precisa trocar o grupo primário da sessão |

### Parte prática — removendo SUID desnecessário

```bash
# Verificar se o ping ainda funciona sem SUID em kernels modernos
# (Linux 4.x+ permite ping sem SUID via capabilities)
ls -la /usr/bin/ping

# Ver capabilities do ping (alternativa moderna ao SUID)
getcap /usr/bin/ping

# Se o ping tiver SUID, verifique se capabilities funcionam como substituto
sudo setcap cap_net_raw+ep /usr/bin/ping
sudo chmod u-s /usr/bin/ping
ping -c 1 127.0.0.1    # ainda deve funcionar via capabilities
```

<details>
<summary>Análise de segurança</summary>

Capabilities são mais seguras que SUID porque concedem apenas a permissão específica necessária, não acesso total como root. `cap_net_raw` permite criar sockets raw sem precisar de UID 0 completo.

O princípio é o mesmo do menor privilégio aplicado a binários: conceda apenas o que é necessário, nada além.
</details>

---

## Exercício 5 — Varredura de segurança de permissões

**Objetivo:** executar uma varredura estruturada e interpretar os resultados como faria um analista de segurança.

```bash
#!/bin/bash
# Salve como ~/lab01/scan-permissoes.sh e execute com: bash scan-permissoes.sh

echo "======================================"
echo "VARREDURA DE PERMISSOES - $(date)"
echo "======================================"

echo -e "\n[1] Usuários com UID 0 (backdoor potencial):"
awk -F: '$3 == 0 {print $1}' /etc/passwd

echo -e "\n[2] Binários SUID encontrados:"
find /usr/bin /usr/sbin /bin /sbin -perm -4000 -type f 2>/dev/null | sort

echo -e "\n[3] Binários SGID encontrados:"
find /usr/bin /usr/sbin /bin /sbin -perm -2000 -type f 2>/dev/null | sort

echo -e "\n[4] Arquivos world-writable fora de /tmp e /proc:"
find / -perm -o+w -type f \
    -not -path "/proc/*" \
    -not -path "/tmp/*" \
    -not -path "/var/tmp/*" \
    -not -path "/sys/*" \
    2>/dev/null | head -20

echo -e "\n[5] Arquivos sem dono definido:"
find / -nouser -not -path "/proc/*" 2>/dev/null | head -10

echo -e "\n[6] Diretórios world-writable sem sticky bit:"
find / -type d -perm -o+w -not -perm -1000 \
    -not -path "/proc/*" \
    -not -path "/sys/*" \
    2>/dev/null | head -10

echo -e "\n======================================"
echo "FIM DA VARREDURA"
```

```bash
bash ~/lab01/scan-permissoes.sh
```

Documente cada item encontrado e classifique como: esperado, a investigar, ou risco confirmado.

---

## Limpeza do ambiente

```bash
# Remover usuários e arquivos de teste
sudo userdel -r aluno_a
sudo userdel -r aluno_b
sudo groupdel projeto_lab
sudo rm -rf /opt/compartilhado
sudo rm -rf /opt/projeto_equipe
rm -rf ~/lab01
```

---

## Perguntas de revisão

Responda sem consultar o material antes. Use o módulo de referência para verificar suas respostas.

1. Um arquivo com permissão `4755` — o que o `4` representa e qual o risco associado?
2. Por que `chmod -R 777 /var/www` é uma configuração perigosa em um servidor web?
3. Qual a diferença entre remover o bit `x` de um script e remover o bit `r`? Qual é mais efetivo para impedir execução?
4. Um diretório tem permissão `2770` e pertence ao grupo `devs`. Um usuário que não é membro do grupo `devs` consegue listar o conteúdo do diretório? Por quê?
5. O que significa encontrar um arquivo em `/tmp` com SUID e dono `root`?

<details>
<summary>Respostas</summary>

1. O `4` ativa o SUID — o arquivo executa com os privilégios do dono (root), não do usuário que executou. Risco: se o binário tiver vulnerabilidade, pode ser explorado para obter shell root.

2. Qualquer processo rodando no servidor (incluindo código injetado por atacante) pode ler, modificar e executar qualquer arquivo. Um atacante que comprometer qualquer conta do sistema tem acesso total ao webroot.

3. Remover `r` é mais efetivo. Sem leitura, o conteúdo do script não pode ser passado para o interpretador. Remover apenas `x` ainda permite `bash script.sh` porque o bash é invocado separadamente e lê o arquivo como entrada.

4. Não. A permissão `2770` concede acesso apenas ao dono e ao grupo `devs`. O `7` para outros não está presente — outros usuários não têm nenhuma permissão.

5. É um indicador grave de comprometimento. Arquivos em `/tmp` não devem ter SUID, e especialmente não devem pertencer a root. Isso é uma técnica clássica de escalonamento de privilégios — o atacante colocou um binário que, quando executado por qualquer usuário, roda como root.
</details>

---

<div align="center">

**Próximo lab: [Lab 02 — Firewall com nftables](lab-02-firewall.md)**

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-darkred?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-black?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

</div>