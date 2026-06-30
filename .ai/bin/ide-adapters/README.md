# ide-adapters

> Parte do [cérebro Atlas](../../README.md). Adapters do harvester de memórias de IDEs/CLIs de IA.

Cada adapter extrai itens de **uma** fonte (Cursor, gemini-cli, opencode, copilot, claude-desktop, …) e os
emite no contrato normalizado abaixo. O entrypoint
[`ide-memory-harvest`](../ide-memory-harvest) orquestra, faz merge e deduplica.

Coloque cada adapter aqui como `<name>.sh` (executável). O `<name>` (sem `.sh`)
é usado como chave de `--since` no watermark e deve bater com o campo `tool`
dos itens emitidos.

## Uso rápido

```bash
# harvest incremental (lê watermark do vault, emite JSONL novo em stdout)
~/cangaco/.ai/bin/ide-memory-harvest

# backfill desde uma data
~/cangaco/.ai/bin/ide-memory-harvest --since 2026-01-01

# incluir claude-desktop (custo: LevelDB grande)
~/cangaco/.ai/bin/ide-memory-harvest --ide-deep

# aplicar: avança watermark e registra item_ids vistos
~/cangaco/.ai/bin/ide-memory-harvest --advance-watermark < novos.jsonl
```

Watermark e histórico moram em `~/.notes/6-audits/ide-memories/`.

---

## Item normalizado (UMA linha JSON por item, JSONL puro em stdout)

```json
{
  "tool": "cursor" | "cursor-cli" | "gemini" | "opencode" | "copilot" | "claude-desktop",
  "item_id": "<hash estavel p/ dedup — sha1 de conteudo+source, hex>",
  "title": "<curto, max 120 chars>",
  "summary": "<resumo 2-3 linhas, max 500 chars, SEM blobs/codigo bruto>",
  "timestamp": "<ISO8601 ou epoch ms; melhor esforco>",
  "cwd_hint": "<path absoluto do projeto/workspace, ou string vazia>",
  "source_path": "<arquivo de onde veio>",
  "kind": "memory" | "conversation" | "prompt"
}
```

---

## Contrato do ADAPTER

- Invocado como: `<adapter>.sh --since "<epoch_ms_ou_iso_ou_vazio>"`
- Emite SOMENTE JSONL normalizado em stdout (uma linha por item). Nada mais em
  stdout.
- SEMPRE `exit 0`, mesmo sem dados / ferramenta ausente / DB vazio. Diagnostico
  vai pra stderr.
- READ-ONLY absoluto nas fontes: usar `sqlite3` com
  `file:CAMINHO?mode=ro&immutable=1` OU copiar o DB pra `$TMPDIR` antes de ler
  (`state.vscdb` tem WAL e pode estar locked). NUNCA escrever na fonte.
- PROIBIDO ler/emitir segredos: nunca abrir `auth.json`, `oauth_creds.json`,
  `cli-config.json` (tokens), `google_accounts.json`, nem os
  `mcp-oauth-attempts` do Cursor (tem `codeVerifier`). Nunca emitir campo que
  contenha `sk-ant-`, `sk-`, `refresh_token`, `access_token`, `codeVerifier`,
  `Bearer`.
- PROIBIDO dumpar blobs: `title`/`summary` capados; nunca colar conteudo de
  `bubbleId`/`composer`/IndexedDB cru. Resumir.
- `item_id` estavel entre runs (mesmo item -> mesmo id).

---

## Contrato do ENTRYPOINT (referencia)

- Sem args: le watermark em
  `~/.notes/6-audits/ide-memories/.watermark.json` (JSON `{tool: last_ts_ou_last_id}`),
  roda CADA `*.sh` em `ide-adapters/` passando `--since` do watermark daquele
  tool, faz merge do stdout, REMOVE itens ja vistos (dedup por `item_id` contra
  o historico `.seen-ids.txt`), emite JSONL novo em stdout. NAO avanca
  watermark.
- `--ide-deep`: tambem roda o adapter `claude-desktop.sh` (default: pulado por
  custo do LevelDB 9GB).
- `--since <YYYY-MM-DD>`: override global (backfill), ignora watermark.
- `--advance-watermark`: le JSONL do stdin e atualiza
  `~/.notes/6-audits/ide-memories/.watermark.json` com o max timestamp por tool
  e faz append dos novos `item_id` em `.seen-ids.txt`. (Frente 2.5 so chama
  isto em `--apply`.)
- Adapter ausente do diretorio -> simplesmente nao roda. Adapter que falha ->
  log stderr, continua os outros (guard, igual Frente 0.7).

---

## Esqueleto minimo de adapter

```bash
#!/usr/bin/env bash
set -uo pipefail

SINCE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --since) shift; SINCE="${1:-}"; shift ;;
    *) shift ;;
  esac
done

# ... leitura READ-ONLY da fonte, filtragem por $SINCE, emissao de JSONL ...
# Em qualquer erro/fonte ausente: log em stderr e siga; nunca quebre stdout.

exit 0
```

---

## Docs relacionados

- [`.ai/README.md`](../../README.md) — hub Atlas
