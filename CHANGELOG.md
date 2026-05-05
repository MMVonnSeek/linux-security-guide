# Changelog

Todas as alterações relevantes deste projeto serão documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/)
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

---

## [1.0.0] — 2025-01-01

### Adicionado

- Módulo `01-fundamentos/permissoes.md` — chmod, chown, SUID, SGID, Sticky Bit
- Módulo `01-fundamentos/processos.md` — gerenciamento e investigação de processos
- Módulo `01-fundamentos/usuarios-grupos.md` — usuários, grupos, sudo e PAM
- Módulo `02-redes/comandos-essenciais.md` — diagnóstico e monitoramento de rede
- Módulo `02-redes/firewall-nftables.md` — filtragem de pacotes com nftables
- Módulo `02-redes/analise-trafico.md` — tcpdump, tshark e detecção de padrões suspeitos
- Módulo `03-hardening/ssh-seguro.md` — hardening completo do OpenSSH
- Módulo `03-hardening/auditoria-logs.md` — journald, auditd e rsyslog
- Módulo `03-hardening/crontab-suspeito.md` — persistência via cron e mecanismos relacionados
- Lab `04-labs/lab-01-permissoes.md` — permissões, SUID e escalonamento de privilégios
- Lab `04-labs/lab-02-firewall.md` — nftables do zero com sets e rate limiting
- Lab `04-labs/lab-03-ssh-hardening.md` — hardening completo com fail2ban e análise de logs
- `README.md` com estrutura completa e badges de identidade
- `LICENSE` — MIT License
- `CONTRIBUTING.md` — padrões de contribuição e estilo
- `SECURITY.md` — política de divulgação responsável
- `CHANGELOG.md` — este arquivo

---

## Formato de versões futuras

```
## [X.Y.Z] — AAAA-MM-DD

### Adicionado
- Novos módulos, labs ou seções

### Alterado
- Atualizações de conteúdo existente, novos exemplos, reestruturação

### Corrigido
- Erros técnicos, comandos incorretos, informações desatualizadas

### Removido
- Conteúdo obsoleto ou incorreto removido
```

---

[1.0.0]: https://github.com/MMVonnSeek/linux-security-guide/releases/tag/v1.0.0