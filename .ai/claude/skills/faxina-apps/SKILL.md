---
name: faxina-apps
description: >-
  Faz uma varredura dos apps graficos (/Applications) e ferramentas de CLI
  (~/.local/bin, ~/bin, Homebrew leaves) instalados na maquina, identifica
  os que estao ocupando espaco em disco sem estar em uso ativo (comparando
  ultimo uso, processo rodando e login items), apresenta um relatorio pro
  Gabriel decidir, e remove com seguranca (sempre para a Lixeira ou via
  `brew uninstall --zap`, nunca rm -rf direto) apenas o que for confirmado
  explicitamente. Use quando o Gabriel pedir pra "limpar apps", "fazer uma
  faxina no disco", "ver o que da pra desinstalar", ou mencionar apps
  especificos que quer remover por nao estar mais usando.
---

# faxina-apps

Rotina de auditoria e limpeza de apps/binarios locais que estao parados mas
ocupando espaco. Roda em 5 fases. **Nunca pule a fase de confirmacao.**

## Fase 1 — Scan (read-only, sempre primeiro)

Rodar `scan.sh` (neste mesmo diretorio) para levantar dados reais:

```bash
bash ~/cangaco/.ai/claude/skills/faxina-apps/scan.sh [dias_limiar opcional, default 60]
```

O script cobre:
- Apps graficos em `/Applications` e `~/Applications`: tamanho, ultimo uso
  (Spotlight `kMDItemLastUsedDate`), se e gerenciado por Homebrew cask, se
  tem processo rodando agora, se e login item.
- Binarios CLI standalone em `~/.local/bin` e `~/bin`: tamanho e `atime`
  como proxy de ultimo uso.
- `brew leaves` (formulas explicitamente instaladas, sem dependentes): heuristica
  de atime do binario no prefix do Homebrew.

Qualquer app/binario com processo rodando ou marcado como login item é
automaticamente sinalizado como "EM USO" e **nao deve ser sugerido para
remocao**, mesmo que o Spotlight/atime diga "nunca usado" — background
agents (sync, drivers, menu bar) nao sempre disparam essas metricas.

## Fase 2 — Relatorio

Apresentar a tabela de saida do scan pro Gabriel, organizada por tamanho
decrescente dentro de cada sinal (CANDIDATO primeiro, maiores ganhos de
espaco no topo). Resumir em texto corrido os 3-5 maiores candidatos com
tamanho + tempo parado, sem enterrar isso numa tabela gigante.

## Fase 3 — Confirmacao (obrigatoria)

Nunca remover nada so com base no sinal "CANDIDATO". Perguntar explicitamente
quais itens da lista o Gabriel quer remover (por nome). Se ele pedir "todos
os candidatos", ainda assim relistar os nomes antes de executar, pra
confirmacao final clara.

## Fase 4 — Execucao (so apos confirmacao)

Regras de remocao, sempre reversiveis:
- **App gerenciado por Homebrew cask**: `brew uninstall --zap <cask>`
  (o `--zap` roda o stanza de limpeza do cask, removendo prefs/cache
  residuais tambem).
- **App .app instalado manualmente**: mover para a Lixeira via
  `osascript -e 'tell application "Finder" to delete POSIX file "<path>"'`
  — nunca `rm -rf`. Depois, varrer residuos com
  `find ~/Library/{Application Support,Caches,Preferences,Saved Application State} ~/.config -maxdepth 1 -iname "*<nome>*"`
  e mover os achados pra Lixeira tambem (mesma tecnica), listando o que foi
  encontrado antes de mexer.
- **Binario CLI standalone**: remover o binario e o diretorio de config
  associado (ex: `~/.config/<nome>`) — aqui pode ser `rm` direto pois sao
  arquivos pequenos e o binario normalmente e reinstalavel com um comando;
  ainda assim, avisar o que foi removido.
- **Formula Homebrew (leaf)**: `brew uninstall <formula>` (sem `--zap`,
  formulas de CLI raramente tem stanza de zap).

## Fase 5 — Resumo

Reportar o espaco total liberado (soma dos tamanhos removidos, ou
`df -h /` antes/depois) e listar o que foi removido vs. o que ficou de fora
por decisao do usuario.

## Principios inegociaveis

- Scan e sempre read-only e roda primeiro, sem excecao.
- Nada e removido sem confirmacao explicita e nomeada (nao vale "remove os
  candidatos" sem re-listar os nomes primeiro).
- Remocao e sempre reversivel (Lixeira ou `brew uninstall`), nunca `rm -rf`
  em apps ou pastas grandes.
- Apps com processo rodando ou login item ativo nunca sao candidatos, mesmo
  se o Spotlight achar que "nunca foram usados".
