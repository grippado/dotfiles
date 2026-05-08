# FlagBridge VPS Setup — Checklist

Ambiente remoto de desenvolvimento no Hostinger (Ubuntu 22.04).
Acesso: `ssh hq`

## Ordem de execução

### Fase 1 — SSH Key do GitHub (na VPS)

```bash
ssh hq

# Gerar chave SSH (se ainda não existe)
ssh-keygen -t ed25519 -C "gabriel@flagbridge.dev"

# Copiar chave pública
cat ~/.ssh/id_ed25519.pub
```

Colar em: https://github.com/settings/ssh/new

Testar:
```bash
ssh -T git@github.com
# "Hi grippado! You've successfully authenticated..."
```

### Fase 2 — Dotfiles + VPS Setup (na VPS)

```bash
# Clonar dotfiles
git clone git@github.com:grippado/dotfiles.git ~/.dotfiles

# Rodar setup completo (ou só a parte Claude):
~/.dotfiles/claude/vps-setup.sh

# Opcionalmente, rodar dotfiles completo pra ter ZSH + aliases:
~/.dotfiles/install.sh
```

### Fase 3 — Sync configs (na máquina LOCAL)

```bash
# Sincronizar Claude Code configs, memory, project commands
~/.dotfiles/claude/sync-to-vps.sh
```

### Fase 4 — Login e MCPs (na VPS)

```bash
# Login no Claude Code com plano Pro
claude auth login

# MCP global — Figma
claude mcp add figma-remote-mcp \
  --transport http \
  --url https://mcp.figma.com/mcp

# MCP projeto — ClickUp (dentro do dir flagbridge)
cd ~/www/flagbridge
claude mcp add clickup \
  --transport http \
  --url https://mcp.clickup.com/mcp \
  -s project

# Verificar MCPs
claude mcp list
```

Os MCPs HTTP (Figma e ClickUp) vão pedir autenticação OAuth no primeiro uso dentro de uma sessão Claude Code.

### Fase 5 — Teste final (na VPS)

```bash
# Iniciar tmux
tmux new -s flagbridge

# Abrir Claude Code no workspace
cd ~/www/flagbridge
claude

# Testar: perguntar algo que use memory
# Exemplo: "qual o status do Sprint 3?"
```

### Fase 6 — Alias no computador da empresa

No computador do trabalho, adicionar ao `.zshrc` ou `.bashrc`:

```bash
alias fb-remote="ssh -t hq 'tmux new-session -A -s flagbridge'"
```

Assim, `fb-remote` conecta direto na sessão tmux do FlagBridge.

## Re-sync (quando mudar configs locais)

Qualquer alteração em agents, commands, memory, ou settings locais:

```bash
~/.dotfiles/claude/sync-to-vps.sh
```

## Notas

- **tmux é essencial**: a sessão sobrevive a desconexões SSH
- **Claude Code enterprise (Arco)** permanece isolado no laptop da empresa — zero conflito
- Os hooks `notify.sh` (`$SUPERSET_HOME_DIR`) não existem na VPS, mas falham silenciosamente (`|| true`)
- Memory path muda automaticamente na VPS (baseado no home dir do user)
