# notes-mcp

> Parte do [cérebro Atlas](../README.md). MCP server **local** (stdio) que dá ao **Claude Desktop** acesso ao vault Obsidian em `$NOTES_VAULT`.

Tudo roda na tua máquina: os arquivos são lidos do disco e os embeddings são gerados
localmente (modelo `all-MiniLM-L6-v2` via transformers.js). Nada do segundo cérebro sai pra fora.

---

## Tools expostas

| Tool | O que faz |
|------|-----------|
| `search_notes` | Busca `hybrid` (BM25 + semântica, padrão), `fulltext` ou `semantic`. Retorna trechos rankeados + path. |
| `read_note` | Lê uma nota (por path relativo ou nome) + frontmatter + links de saída resolvidos + **backlinks**. |
| `list_notes` | Lista notas por pasta (`0-inbox`, `1-contexts`, ...) e por mais recente ou alfabético. |
| `create_note` | Cria nota nova (padrão em `0-inbox/`). Recusa sobrescrever. |
| `append_note` | Anexa conteúdo ao fim de uma nota existente. |

---

## Como funciona o índice

- Na primeira execução: baixa o modelo (~90MB, fica em cache) e gera embeddings das ~700 notas (~30s).
- Cache de embeddings em `~/.cache/notes-mcp/embeddings.json` (fora do vault, não polui o git).
- Boots seguintes são **incrementais**: só recalcula embedding de notas com `mtime` alterado (~0.5s).
- O índice é reconstruído a cada start do server (que o Claude Desktop dispara ao abrir).

---

## Rodar / manter

```bash
cd ~/cangaco/.ai/notes-mcp

pnpm install        # uma vez (precisa de build nativo: sharp + onnxruntime)
pnpm build          # compila TS -> dist/
pnpm reindex        # força reconstrução total do cache de embeddings
pnpm start          # sobe o server manualmente (normalmente quem sobe é o Claude Desktop)
```

> **Nota sobre Node:** o binário é gerenciado por `fnm`. O caminho usado no config do Desktop aponta
> para a versão instalada (`~/.local/share/fnm/node-versions/<versão>/...`). Se você trocar a versão
> default do Node, atualize o `command` no `claude_desktop_config.json`.

### Quando reindexar manualmente?

Não é obrigatório: o boot incremental já pega notas alteradas. Rode `pnpm reindex` só se quiser
forçar tudo do zero (ex.: muitas notas mudaram de uma vez e você quer pré-aquecer antes de abrir o app).

---

## Instalação no Claude Desktop

Adicionar ao `~/Library/Application Support/Claude/claude_desktop_config.json`:

**Personal** (`$HOME=/Users/grippado`):

```json
{
  "mcpServers": {
    "notes": {
      "command": "/Users/grippado/.local/share/fnm/node-versions/v25.8.1/installation/bin/node",
      "args": ["/Users/grippado/cangaco/.ai/notes-mcp/dist/index.js"],
      "env": {
        "NOTES_VAULT_PATH": "/Users/grippado/.notes"
      }
    }
  }
}
```

**Arco** (`$HOME=/Users/gabriel.gripp`) — ajustar paths:

```json
{
  "mcpServers": {
    "notes": {
      "command": "/Users/gabriel.gripp/.local/share/fnm/node-versions/v25.8.1/installation/bin/node",
      "args": ["/Users/gabriel.gripp/cangaco/.ai/notes-mcp/dist/index.js"],
      "env": {
        "NOTES_VAULT_PATH": "/Users/gabriel.gripp/.notes"
      }
    }
  }
}
```

Depois: **reinicie o Claude Desktop** (Cmd+Q e abrir de novo). O server `notes` aparece no ícone de
conectores/ferramentas.

---

## Variáveis de ambiente

| Var | Padrão | Descrição |
|-----|--------|-----------|
| `NOTES_VAULT_PATH` | `~/.notes` | Raiz do vault Obsidian (`$NOTES_VAULT` via `env.sh`). |
| `NOTES_MCP_CACHE_DIR` | `~/.cache/notes-mcp` | Onde guardar o cache de embeddings. |

---

## Docs relacionados

- [`.ai/README.md`](../README.md) — hub Atlas
- [README principal](../../README.md) — mapa do cangaço
