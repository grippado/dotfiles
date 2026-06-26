Gere um relatório em Markdown dos meus PRs nas org(s) informadas.

**Argumentos** (ordem livre):

- **Obrigatório**: uma ou mais orgs no GitHub (tokens posicionais, sem `--`), ex.: `OlaIsaac` ou `OlaIsaac outra-org` (podem aparecer antes ou depois das flags).
- **Janela de datas** (use **uma** das formas abaixo; `--start` / `--end` têm prioridade sobre `--days`):
  - **Padrão**: últimos **30 dias** (UTC, por dia `YYYY-MM-DD`) — mesmo espírito da versão antiga do comando; para um recorte curto use `--days`.
  - **`--days N`**: de **hoje − N dias** até **hoje** (ex.: `--days 3` para a janela de 3 dias).
  - **`--start YYYY-MM-DD`**: início. Sem **`--end`**, o fim é **hoje (UTC)**.
  - **`--end YYYY-MM-DD`**: fim; exige **`--start`**.

**Limite**: até **100 PRs por org** (`gh search prs --limit` em cada busca; JSON final = união).

**Campos JSON**: use `--json title,url,state,createdAt,repository` (sem `body`). Descrições de PR costumam ter caracteres de controle que invalidam JSON ao concatenar com `jq --argjson` entre chamadas.

Exemplos de `$ARGUMENTS`: `minha-org`, `org-a org-b --days 3`, `org-a --start 2026-05-01 org-b`, `org-a org-b --start 2026-05-01 --end 2026-05-05`.

**Dependência**: `jq` no PATH (para unir e ordenar os JSONs).

## Passos

1. Execute o comando abaixo para buscar os PRs. O Cursor expande `$ARGUMENTS` com o que você digitou após o comando.

```bash
set -- $ARGUMENTS
ORGS=()
START_DATE=""
END_DATE=""
DAYS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --start)
      START_DATE="${2:?missing value for --start}"
      shift 2
      ;;
    --end)
      END_DATE="${2:?missing value for --end}"
      shift 2
      ;;
    --days)
      DAYS="${2:?missing value for --days}"
      shift 2
      ;;
    *)
      ORGS+=("$1")
      shift
      ;;
  esac
done

if [ ${#ORGS[@]} -eq 0 ]; then
  echo "Uso: org [org...] [--days N] [--start YYYY-MM-DD] [--end YYYY-MM-DD]" >&2
  exit 1
fi

if [ -n "$END_DATE" ] && [ -z "$START_DATE" ]; then
  echo "Use --start junto com --end, ou omita ambos e use --days (ou o padrão de 30 dias)." >&2
  exit 1
fi

if [ -n "$START_DATE" ] || [ -n "$END_DATE" ]; then
  if [ -n "$DAYS" ]; then
    echo "Não combine --days com --start/--end." >&2
    exit 1
  fi
  if [ -z "$START_DATE" ] && [ -n "$END_DATE" ]; then
    echo "Use --start junto com --end." >&2
    exit 1
  fi
  if [ -n "$START_DATE" ] && [ -z "$END_DATE" ]; then
    END_DATE=$(date -u +%Y-%m-%d)
  fi
else
  if [ -z "$DAYS" ]; then
    DAYS=30
  fi
  case "$DAYS" in
    ''|*[!0-9]*) echo "--days deve ser um inteiro positivo." >&2; exit 1 ;;
  esac
  if [ "$DAYS" -lt 1 ]; then
    echo "--days deve ser pelo menos 1." >&2
    exit 1
  fi
  START_DATE=$(date -u -d "$DAYS days ago" +%Y-%m-%d 2>/dev/null || date -u -v-${DAYS}d +%Y-%m-%d)
  END_DATE=$(date -u +%Y-%m-%d)
fi

CREATED_RANGE="${START_DATE}..${END_DATE}"
AUTHOR=$(gh api user --jq '.login')

COMBINED='[]'
for OWNER in "${ORGS[@]}"; do
  PART=$(gh search prs \
    --author "$AUTHOR" \
    --owner "$OWNER" \
    --created "$CREATED_RANGE" \
    --limit 100 \
    --json title,url,state,createdAt,repository)
  COMBINED=$(jq -n --argjson a "$COMBINED" --argjson b "$PART" '$a + $b')
done

echo "$COMBINED" | jq 'group_by(.url) | map(.[0]) | sort_by(.createdAt) | reverse'
```

2. Com o JSON retornado, gere um relatório Markdown com:
   - **Resumo executivo**: total de PRs, orgs consultadas, **janela de datas usada** (`START_DATE` → `END_DATE` e, se aplicável, que foi padrão 30 dias, `--days N`, ou `--start`/`--end`), repos envolvidos, quantos abertos/merged/closed
   - **Tabela geral**: título, repo, status, data de criação
   - **Agrupado por repositório**: bullets descritivos de cada PR
   - **Highlights**: PRs com maior impacto aparente **a partir do título e do repo** (se precisar do corpo da descrição, busque `body` com `gh pr view <url> --json body` só nos casos escolhidos)

3. Salve o resultado em `pr-report-<data-de-hoje>.md` na pasta atual.
