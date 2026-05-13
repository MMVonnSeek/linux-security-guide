<!-- BADGES DE IDENTIDADE - ESTRATÉGIA ANTI-FORK -->
[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Repositório Original](https://img.shields.io/badge/Repositório-Original-black?style=for-the-badge&logo=github)](https://github.com/MMVonnSeek/linux-security-guide)
[![Linux](https://img.shields.io/badge/Linux-Segurança_Prática-darkred?style=for-the-badge&logo=linux&logoColor=black)](https://github.com/MMVonnSeek/linux-security-guide)
[![Licença](https://img.shields.io/badge/Licença-MIT-black?style=for-the-badge)](LICENSE)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-ea4aaa?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)

---

<div align="center">

# Guia Prático de Linux para Cibersegurança

**Do terminal ao hardening — conteúdo real, sem enrolação.**

*Criado e testado em sala de aula*

</div>

---

## Sobre este projeto

Este repositório reúne conteúdo prático de Linux com foco em segurança da informação. Não é um guia teórico — cada módulo tem comandos reais, labs executáveis e situações que você vai encontrar no mercado de trabalho.

O conteúdo nasceu das aulas do curso técnico de **Desenvolvimento de Sistemas** e do curso **Fullstack** no SENAI, e foi refinado com base nas dúvidas reais de dezenas de alunos.

> Se este material já te ajudou, considere deixar uma ⭐ ou [apoiar o projeto](https://github.com/sponsors/MMVonnSeek).

---

## Estrutura do Repositório
``` 
linux-security-guide/
│
├── README.md
├── LICENSE
├── CHANGELOG.md
├── SECURITY.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
│
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── pull_request_template.md
│
├── 01-fundamentos/
│   ├── permissoes.md
│   ├── processos.md
│   └── usuarios-grupos.md
│
├── 02-redes/
│   ├── comandos-essenciais.md
│   ├── firewall-nftables.md
│   └── analise-trafico.md
│
├── 03-hardening/
│   ├── ssh-seguro.md
│   ├── auditoria-logs.md
│   └── crontab-suspeito.md
│
└── 04-labs/
    ├── lab-01-permissoes.md
    ├── lab-02-firewall.md
    └── lab-03-ssh-hardening.md
``` 
---

## Como usar este guia

Você pode seguir os módulos em ordem ou pular direto para o tema que precisa.

**Recomendação para iniciantes:** siga a sequência `01 → 02 → 03 → Labs`

**Recomendação para quem quer emprego:** comece pelos labs em `04-labs/` e vá para os módulos conforme surgir dúvida.

> **Dica:** Clone o repositório e abra no VS Code com a extensão Markdown Preview para melhor leitura.

```bash
git clone https://github.com/MMVonnSeek/linux-security-guide.git
cd linux-security-guide
```

---

## Módulos disponíveis

### 01 — Fundamentos
| Tópico | O que você vai aprender |
|--------|------------------------|
| [Permissões](01-fundamentos/permissoes.md) | chmod octal/simbólico, SUID, SGID, Sticky Bit, casos reais de vulnerabilidade |
| [Processos](01-fundamentos/processos.md) | Gerenciamento de processos, sinais, prioridades |
| [Usuários e Grupos](01-fundamentos/usuarios-grupos.md) | Criação segura, sudoers, princípio do menor privilégio |

### 02 — Redes
| Tópico | O que você vai aprender |
|--------|------------------------|
| [Comandos Essenciais](02-redes/comandos-essenciais.md) | Diagnóstico de rede, monitoramento de conexões |
| [Firewall com nftables](02-redes/firewall-nftables.md) | Regras de entrada/saída, tabelas, chains, logging |
| [Análise de Tráfego](02-redes/analise-trafico.md) | Captura e análise de pacotes em tempo real |

### 03 — Hardening
| Tópico | O que você vai aprender |
|--------|------------------------|
| [SSH Seguro](03-hardening/ssh-seguro.md) | Autenticação por chave, desabilitar root, fail2ban |
| [Auditoria de Logs](03-hardening/auditoria-logs.md) | Leitura de logs do sistema, auditd, alertas |
| [Persistência via Cron](03-hardening/crontab-suspeito.md) | Como atacantes usam cron e como detectar |

### 04 — Labs Práticos
| Lab | Nível | Tempo estimado |
|-----|-------|----------------|
| [Lab 01 — Permissões](04-labs/lab-01-permissoes.md) | Iniciante | 30 min |
| [Lab 02 — Firewall](04-labs/lab-02-firewall.md) | Intermediário | 45 min |
| [Lab 03 — SSH Hardening](04-labs/lab-03-ssh-hardening.md) | Intermediário | 40 min |

---

## Para quem é este guia

- Estudantes de TI que querem entrar na área de segurança
- Desenvolvedores que precisam administrar seus próprios servidores Linux
- Profissionais de suporte que querem migrar para segurança
- Alunos do SENAI e cursos técnicos de informática

---

## Como contribuir

Contribuições são bem-vindas! Veja como:

1. Faça um fork do projeto
2. Crie uma branch: `git checkout -b minha-contribuicao`
3. Commit suas mudanças: `git commit -m 'Adiciona conteúdo sobre X'`
4. Push para a branch: `git push origin minha-contribuicao`
5. Abra um Pull Request

> **Atenção:** Se você fez fork deste repositório, o [repositório original está aqui](https://github.com/MMVonnSeek/linux-security-guide). Encontrou algo desatualizado? Abra uma issue lá.

Veja o arquivo [CONTRIBUTING.md](CONTRIBUTING.md) para mais detalhes.

---

## Contato e Apoio

| Canal | Link |
|-------|------|
| 🐙 GitHub | [@MMVonnSeek](https://github.com/MMVonnSeek) |
| ❤️ Sponsor | [github.com/sponsors/MMVonnSeek](https://github.com/sponsors/MMVonnSeek) |

---

## Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

Você pode usar, copiar, modificar e distribuir livremente — **desde que mantenha os créditos ao autor original**.

---

<div align="center">

[![Professor Max](https://img.shields.io/badge/Material_do_Professor_Max-Oficial-darkred?style=for-the-badge&logo=google-scholar&logoColor=white)](https://github.com/MMVonnSeek/linux-security-guide)
[![Sponsor](https://img.shields.io/badge/Apoie_este_projeto-Sponsor-ea4aaa?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/MMVonnSeek)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Max_Muller-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/max-muller-685705248/)

*Feito com* ☕ *e muito terminal por Professor Max*

[Voltar ao topo](#-guia-prático-de-linux-para-cibersegurança)

</div>
