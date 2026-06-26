---
description: >-
  Perfila a atividade Slack da máquina atual (últimos ~30 dias) e enriquece o
  slack-channels.json + escreve o mapa de contexto no vault, deixando a Frente
  0.8 do /organize mais certeira. Delega ao agente slack-context-profiler.
  Aceita --since, --machine, --dry-run e flags de tuning (ver argument-hint).
argument-hint: "[--since YYYY-MM-DD] [--machine <nome>] [--dry-run] [--max-calls N] [--top-channels N] [--top-interlocutors N]"
alias_global: true
---

# /slack-profile

Comando fino. Delega TODO o trabalho ao agente **`slack-context-profiler`** via Task.

## Fluxo

1. Verificar guard: se as tools `mcp__plugin_slack_slack__*` não estiverem disponíveis, avisar que o perfil precisa de run interativo com Slack OAuth e parar (não falhar).
2. Repassar os argumentos recebidos (`--since`, `--machine`, `--dry-run`, `--max-calls`, `--top-channels`, `--top-interlocutors`) ao agente.
3. Invocar via Task o subagent `slack-context-profiler` com esses argumentos.
4. Ao final, ecoar o relatório do agente: janela, top canais/interlocutores (por tier), arquivos escritos (caminhos absolutos) e lembrar que os outputs são **local-only por padrão** (gitignored) — versionar é opt-in via `git add -f`.

## Notas
- Não roda git. Os outputs (`slack-channels.json` + `slack/slack-context-map.md`) são **local-only por padrão** (incluem agregados de DM); versionar é decisão manual do usuário (`git add -f`).
- Para atualizar a whitelist consumida pelo /organize, este é o caminho canônico.
