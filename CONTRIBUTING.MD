[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Voltar ao Repositório](https://img.shields.io/badge/Voltar-Repositório_Principal-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)

---

# Guia de Contribuição

Obrigado pelo interesse em contribuir com o **linux-security-guide**. Este documento define os padrões e o processo para que toda contribuição mantenha a qualidade e consistência do projeto.

---

## Código de conduta

Todas as contribuições devem ser respeitosas, técnicas e construtivas. Discussões devem se manter no âmbito do conteúdo — segurança Linux, precisão técnica e clareza didática. Contribuições com linguagem ofensiva, spam ou conteúdo fora do escopo serão encerradas sem avaliação.

---

## O que você pode contribuir

### Bem-vindo

- Correções de erros técnicos — comandos incorretos, sintaxe desatualizada, comportamento descrito incorretamente
- Correções ortográficas e gramaticais em português
- Adição de exemplos práticos relevantes dentro dos módulos existentes
- Novos labs seguindo o padrão dos existentes em `04-labs/`
- Atualização de conteúdo para versões mais recentes de ferramentas (ex: nftables, OpenSSH)
- Melhoria de explicações sem alterar a estrutura do módulo

### Não aceito neste momento

- Novos módulos fora da estrutura definida no README sem discussão prévia via issue
- Traduções para outros idiomas (o projeto é intencionalmente em português)
- Conteúdo sobre distribuições não cobertas (Arch, Gentoo, Alpine) sem issue prévia
- Alterações no estilo visual dos badges ou na identidade do projeto

---

## Processo de contribuição

### 1. Verifique se já existe uma issue

Antes de abrir um PR, procure em [Issues](https://github.com/MMVonnSeek/linux-security-guide/issues) se o problema ou a melhoria já foi reportado. Se sim, comente na issue existente.

### 2. Abra uma issue antes de PRs grandes

Para contribuições que vão além de uma correção pontual — novo lab, nova seção, refatoração de módulo — abra uma issue primeiro descrevendo o que pretende fazer. Isso evita trabalho duplicado ou na direção errada.

### 3. Fork e branch

```bash
# Fork pelo GitHub e clone localmente
git clone https://github.com/seu-usuario/linux-security-guide.git
cd linux-security-guide

# Crie uma branch descritiva
git checkout -b fix/permissoes-suid-exemplo
git checkout -b add/lab-auditoria-processos
git checkout -b update/nftables-sintaxe-v1.0
```

Convenção de nomes de branch:

| Prefixo | Uso |
|---------|-----|
| `fix/` | Correção de erro técnico ou ortográfico |
| `add/` | Novo conteúdo (lab, seção, exemplo) |
| `update/` | Atualização de conteúdo existente |
| `docs/` | Alterações apenas em documentação de projeto |

### 4. Faça as alterações

Siga os padrões de estilo descritos na seção abaixo.

### 5. Commit com mensagem descritiva

```bash
# Formato: tipo(escopo): descrição curta em português
git commit -m "fix(permissoes): corrige exemplo octal do chmod 644"
git commit -m "add(labs): adiciona lab de auditoria de processos"
git commit -m "update(ssh-seguro): atualiza algoritmos para OpenSSH 9.x"
```

Tipos de commit:

| Tipo | Uso |
|------|-----|
| `fix` | Correção de erro |
| `add` | Novo conteúdo |
| `update` | Atualização de conteúdo existente |
| `refactor` | Reorganização sem alterar conteúdo |
| `docs` | Alterações em arquivos de documentação do projeto |

### 6. Abra o Pull Request

- Título claro descrevendo o que foi alterado
- Descrição explicando o problema e a solução, ou o que foi adicionado e por quê
- Referencie a issue relacionada com `Closes #numero` se aplicável
- PRs sem descrição serão solicitados a completar antes de revisão

---

## Padrões de estilo

### Linguagem e tom

- Português brasileiro, direto e técnico
- Sem emojis no conteúdo dos módulos
- Sem frases introdutórias genéricas ("Neste módulo veremos...", "Como sabemos...")
- Voz ativa, presente

### Estrutura de módulo

Todo módulo em `01-fundamentos/`, `02-redes/` ou `03-hardening/` deve seguir:

```markdown
[![badges de identidade]](links para o repositório)

---

# Título do Módulo

> Pré-requisito, tempo estimado, distro testada

---

## Por que [tema] importa para segurança

[parágrafo de contexto — por que isso importa do ponto de vista de segurança]

---

## 1. Primeiro conceito
...

## N. Último conceito

---

## Lab — Coloque em prática
[exercícios com gabarito em <details>]

---

## Checklist de segurança
[lista de verificação]

---

## Referências
[man pages e documentação oficial]

---

<div align="center">
[navegação entre módulos]
[badges de rodapé]
</div>
```

### Estrutura de lab

Todo lab em `04-labs/` deve incluir obrigatoriamente:

- Seção **Objetivo** com lista de habilidades adquiridas
- Seção **Preparação do ambiente** com comandos reproduzíveis
- Mínimo de 3 exercícios com progressão de dificuldade
- Gabaritos dentro de `<details>` recolhíveis
- Seção **Limpeza do ambiente** removendo tudo que foi criado
- Seção **Perguntas de revisão** com 5 perguntas e respostas em `<details>`

### Comandos e código

- Blocos de código com a linguagem especificada (` ```bash `, ` ```nftables `, ` ```ini `)
- Comentários explicativos dentro dos blocos para comandos não óbvios
- Saídas esperadas mostradas como comentários ou em blocos separados
- Nenhum comando destrutivo sem aviso explícito antes do bloco

### Badges

Não altere os badges de identidade. Cada arquivo deve manter os badges no topo e no rodapé apontando para `https://github.com/MMVonnSeek/linux-security-guide`.

---

## Reportando erros técnicos

Se encontrar um erro técnico — comando que não funciona, comportamento descrito incorretamente, informação desatualizada — abra uma issue com:

- **Título:** `[ERRO] Módulo X — descrição curta do problema`
- **Distro e versão:** Ubuntu 22.04, RHEL 9, etc.
- **Versão da ferramenta:** saída de `ssh -V`, `nft --version`, etc.
- **Comportamento esperado:** o que o módulo afirma
- **Comportamento observado:** o que realmente acontece
- **Comando executado:** bloco de código exato

---

## Dúvidas sobre o conteúdo

Issues não são o canal para dúvidas de aprendizado. Para dúvidas sobre o conteúdo dos módulos:

- Abra uma [Discussion](https://github.com/MMVonnSeek/linux-security-guide/discussions) no GitHub
- Entre em contato via [LinkedIn](https://www.linkedin.com/in/max-muller-685705248/)

---

## Reconhecimento

Contribuidores com PRs aceitos serão adicionados à seção de contribuidores no README. Contribuições significativas serão destacadas nas release notes.

---

<div align="center">

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-black?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

</div>