#!/usr/bin/env bash
#
# ide-adapter: claude-desktop (STUB — documentado, sem fonte local utilizavel)
#
# DIAGNOSTICO (verificado em 2026-06-07, READ-ONLY):
#   A nota antiga de "~9GB de IndexedDB" estava ERRADA. Os 9GB sao do diretorio
#   inteiro do app (~/Library/Application Support/Claude: VM bundles, caches,
#   Code Cache, GPUCache, etc.), NAO do IndexedDB.
#
#   O IndexedDB de fato e' minusculo (~4.5MB):
#     ~/Library/Application Support/Claude/IndexedDB/
#       https_claude.ai_0.indexeddb.leveldb   (~1.1MB .log + ~10KB .ldb)
#       https_claude.ai_0.indexeddb.blob/     (~2.4MB de blobs binarios)
#
#   Conteudo do leveldb (object store unico: "keyval-store"):
#     - Estado de UI persistido (Zustand): {"state":{"starredIds":[...]},...}
#       -> so IDs de itens "starred" (ex.: local_<uuid>). SEM titulo, SEM texto.
#     - "tipTapEditorState": o rascunho atual NAO enviado do composer. Conteudo
#       efemero (uma mensagem em digitacao), serializado em V8 structured-clone
#       e entrelacado com bytes binarios — NAO e' texto limpo/parseavel.
#   O Local Storage leveldb tem um cache do React Query com a chave
#   "conversations_v2", mas com "queries":[] (vazio): nada de conversa persiste
#   localmente.
#
#   CONCLUSAO: o Claude Desktop e' um wrapper web de claude.ai. O historico de
#   conversas e as memorias vivem no SERVIDOR (claude.ai), nao em disco. NAO ha
#   uma object store local de conversas/memorias para parsear. Extrair "titulos
#   de conversa" deste IndexedDB e' impossivel hoje porque esses dados nao estao
#   aqui — o problema nao e' "falta de ferramenta", e' "fonte inexistente".
#
# O QUE FALTARIA para tornar isto real (NENHUM caminho e' barato/seguro hoje):
#   (a) Decodificar V8 structured-clone do leveldb. Mesmo assim so renderia o
#       rascunho do composer e IDs starred — nao conversas. Precisaria de uma lib
#       de leitura de IndexedDB do Chromium (ccl_chromium_indexeddb / plyvel),
#       que NAO esta instalada (checado: `import plyvel` falha; idem ccl_leveldb,
#       ccl_chromium_indexeddb). Baixo retorno: nao ha conversa pra extrair.
#   (b) API/export de claude.ai (onde os dados realmente estao). Exigiria
#       credenciais/sessao e chamada de rede — fora do escopo READ-ONLY-em-disco
#       deste harvester e com risco de vazar segredos.
#   => Por isso este adapter permanece STUB. Reavaliar so se o Claude Desktop
#      passar a persistir conversas/memorias localmente (ex.: nova object store
#      "conversations"/"memories" com titulo+texto). Hoje nao persiste.
#
# CONTRATO (mantido p/ quando virar real):
#   - Invocado como: claude-desktop.sh --since "<epoch_ms_ou_iso_ou_vazio>"
#   - So roda em modo deep (entrypoint exporta IDE_DEEP=1 com --ide-deep).
#   - Emite SOMENTE JSONL normalizado em stdout; diagnostico vai pra stderr.
#   - SEMPRE exit 0.
#   - Item normalizado:
#       { tool, item_id, title, summary, timestamp, cwd_hint, source_path, kind }
#     kind="conversation"; title<=120; summary<=500 (SUMARIZAR, nunca dumpar
#     blob cru); item_id = sha1 estavel; cwd_hint="" (Desktop nao tem workspace).
#   - READ-ONLY ABSOLUTO: nunca abrir o leveldb ativo em modo rw. Copiar os
#     arquivos pra $TMPDIR e ler a copia. PROIBIDO emitir segredos (sk-ant-,
#     sk-, Bearer, refresh_token, access_token, oauth, credenciais).
# ---------------------------------------------------------------------------

set -uo pipefail

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

# Gate de custo/opt-in: so faz qualquer coisa quando o entrypoint pede
# --ide-deep (que exporta IDE_DEEP=1). Sem isso, no-op silencioso.
if [ "${IDE_DEEP:-}" != "1" ]; then
  exit 0
fi

# Modo deep: STUB. A fonte local (IndexedDB do Claude Desktop) so guarda estado
# de UI (starredIds + rascunho do composer); o historico de conversas vive no
# servidor claude.ai e nao em disco. Nada a emitir. Loga claramente e sai 0.
echo "claude-desktop adapter: STUB — sem fonte local de conversas/memorias." >&2
echo "claude-desktop adapter: IndexedDB local so tem estado de UI (starredIds + rascunho do composer); historico de conversas e' server-side (claude.ai). Zero itens. Ver header do script." >&2

# Zero itens em stdout. Sempre exit 0.
exit 0
