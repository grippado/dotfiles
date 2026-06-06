#!/usr/bin/env bash
#
# ide-adapter: claude-desktop (STUB)
#
# Este e o adapter mais caro do conjunto. O Claude Desktop guarda o historico
# de conversas em um IndexedDB baseado em LevelDB que pode chegar a ~9GB em:
#   ~/Library/Application Support/Claude/IndexedDB
#
# Por custo (varredura de LevelDB de varios GB), o entrypoint NAO roda este
# adapter por padrao: so o invoca com --ide-deep, exportando IDE_DEEP=1.
#
# ---------------------------------------------------------------------------
# TODO (abordagem futura para a implementacao real):
#   1. Localizar o diretorio LevelDB do Claude Desktop:
#        ~/Library/Application Support/Claude/IndexedDB/<origin>/<db>.leveldb
#   2. READ-ONLY: nunca abrir o LevelDB ativo direto (lock + WAL/MANIFEST). Em
#      vez disso, copiar o diretorio .leveldb inteiro pra $TMPDIR e ler a copia,
#      OU usar um leitor que respeite o lock. Nunca escrever na fonte.
#   3. Parsear via leveldb/plyvel (Python) ou equivalente. IndexedDB serializa
#      os valores em V8 structured-clone; sera preciso decodificar esse formato
#      (ex.: biblioteca tipo ccl_chromium_indexeddb / chromedb) pra extrair as
#      conversas. Filtrar pelas object stores de mensagens/conversas.
#   4. Para cada conversa: emitir UMA linha JSON normalizada com kind="conversation".
#      - title: titulo da conversa, capado em 120 chars.
#      - summary: resumo de 2-3 linhas (max 500 chars). SUMARIZAR — NUNCA dumpar
#        o conteudo cru das mensagens, blobs, anexos ou base64.
#      - item_id: sha1 estavel (ex.: conversation_id + source_path), hex.
#      - timestamp: melhor esforco (updatedAt/createdAt da conversa).
#      - cwd_hint: "" (Claude Desktop nao tem workspace), source_path do .leveldb.
#   5. Respeitar --since (epoch_ms|iso|vazio): so emitir conversas mais novas.
#   6. PROIBIDO emitir segredos: nunca tocar/emitir tokens, sk-ant-, sk-,
#      refresh_token, access_token, Bearer, credenciais de conta.
#   7. SEMPRE exit 0; diagnostico vai pra stderr; stdout e JSONL puro.
# ---------------------------------------------------------------------------

set -euo pipefail

# Parse de argumentos (contrato: --since "<epoch_ms_ou_iso_ou_vazio>").
# O stub aceita e ignora --since; mantido aqui pra compatibilidade do contrato.
SINCE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --since)
      SINCE="${2-}"
      shift 2 || shift
      ;;
    --since=*)
      SINCE="${1#--since=}"
      shift
      ;;
    *)
      # Argumentos desconhecidos sao ignorados (forward-compat).
      shift
      ;;
  esac
done

# Gate de custo: so faz qualquer coisa quando o entrypoint pede --ide-deep
# (que exporta IDE_DEEP=1). Sem isso, no-op silencioso.
if [ "${IDE_DEEP:-}" != "1" ]; then
  exit 0
fi

# Modo deep: por ora ainda nao implementado. Loga em stderr e emite zero itens.
echo "claude-desktop adapter: LevelDB parse nao implementado (TODO)" >&2

# Zero itens em stdout. Sempre exit 0.
exit 0
