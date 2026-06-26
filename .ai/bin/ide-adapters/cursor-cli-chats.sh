#!/usr/bin/env bash
#
# ide-adapter: cursor-cli-chats
#
# Fonte: ~/.cursor/chats/<hash>/<uuid>/store.db (varios SQLite, um por conversa).
#   Tabelas:
#     blobs(id TEXT PRIMARY KEY, data BLOB)  -- conteudo content-addressed (sha256)
#     meta(key TEXT PRIMARY KEY, value TEXT) -- value e JSON hex-encoded com
#                                               {agentId,name,mode,createdAt,...}
#   Os blobs que comecam com '{"' sao mensagens JSON da conversa, no formato
#   AI-SDK ({role: user|assistant|tool|system, content: str|[{type,text}]}).
#   Os demais blobs sao protobuf (arvore de versoes) e NAO sao tocados.
#
# CONTRATO (ver entrypoint ide-memory-harvest):
#   - Invocado como: cursor-cli-chats.sh --since "<epoch_ms_ou_iso_ou_vazio>"
#   - Emite SOMENTE JSONL normalizado em stdout (uma linha por conversa).
#   - SEMPRE exit 0. Diagnostico vai pra stderr.
#   - READ-ONLY absoluto: abre store.db com mode=ro&immutable=1. WAL pode estar
#     locked -> copia o store.db (e -wal/-shm) pra $TMPDIR e le a copia. Nunca
#     escreve na fonte.
#   - NAO dumpa blobs: emite UM item kind=conversation por store.db, com title e
#     summary resumidos e capados. Nunca cola conteudo cru.
#   - Sem segredos: este formato nao carrega tokens; ainda assim, qualquer linha
#     que contenha um padrao tipo segredo e descartada do summary por seguranca.
#   - item_id estavel: sha1(path absoluto do store.db).
#
# Saida (uma linha JSON por conversa):
#   {tool, item_id, title, summary, timestamp, cwd_hint, source_path, kind}

set -euo pipefail

# ---------------------------------------------------------------------------
# Parse de argumentos.
# ---------------------------------------------------------------------------
SINCE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --since)      SINCE="${2-}"; shift 2 || shift ;;
    --since=*)    SINCE="${1#--since=}"; shift ;;
    *)            shift ;;  # forward-compat: ignora desconhecidos
  esac
done

CHATS_DIR="${HOME}/.cursor/chats"

# Sem fonte -> no-op silencioso, exit 0.
if [ ! -d "$CHATS_DIR" ]; then
  echo "cursor-cli-chats: $CHATS_DIR ausente; nada a fazer" >&2
  exit 0
fi

# python3 e necessario pra parsear os blobs JSON com seguranca. Sem ele, sai
# limpo (exit 0) e loga em stderr.
if ! command -v python3 >/dev/null 2>&1; then
  echo "cursor-cli-chats: python3 ausente; pulando" >&2
  exit 0
fi

# Lista de store.db. Sem nenhum -> exit 0.
DBS=()
while IFS= read -r f; do
  [ -n "$f" ] && DBS+=("$f")
done < <(find "$CHATS_DIR" -type f -name store.db 2>/dev/null)

if [ "${#DBS[@]}" -eq 0 ]; then
  echo "cursor-cli-chats: nenhum store.db em $CHATS_DIR" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Toda a logica de leitura/normalizacao vive no Python abaixo (read-only,
# resumo, --since, item_id estavel). O script Python e materializado num arquivo
# temporario (nao da pra ler script do stdin E receber dados pelo stdin ao mesmo
# tempo). Os paths dos store.db vao pelo stdin; SINCE vai pelo env.
# ---------------------------------------------------------------------------
export CURSOR_SINCE="$SINCE"

PYTMP="$(mktemp "${TMPDIR:-/tmp}/cursor-cli-chats.XXXXXX.py")"
trap 'rm -f "$PYTMP"' EXIT

cat > "$PYTMP" <<'PYEOF'
import sys, os, json, re, hashlib, sqlite3, shutil, tempfile

SINCE_RAW = os.environ.get("CURSOR_SINCE", "").strip()

# Padroes de segredo: se aparecerem numa linha, a linha e descartada do summary.
SECRET_RE = re.compile(
    r'(sk-ant-|sk-[A-Za-z0-9]|refresh_token|access_token|codeVerifier|Bearer\s)'
)

def parse_since_ms(raw):
    """--since pode ser epoch_ms, epoch_s, ou ISO8601. Retorna ms (int) ou None."""
    if not raw:
        return None
    s = raw.strip()
    # epoch puro
    if re.fullmatch(r'\d+', s):
        n = int(s)
        # heuristica: <1e12 -> segundos; senao ms
        return n * 1000 if n < 1_000_000_000_000 else n
    # ISO8601
    try:
        from datetime import datetime
        iso = s.replace('Z', '+00:00')
        dt = datetime.fromisoformat(iso)
        return int(dt.timestamp() * 1000)
    except Exception:
        return None

SINCE_MS = parse_since_ms(SINCE_RAW)

def open_ro(db_path):
    """Abre store.db read-only. Se locked (WAL), copia pra TMPDIR e abre a copia.
    Retorna (connection, tmpdir_or_None)."""
    uri = f"file:{db_path}?mode=ro&immutable=1"
    try:
        con = sqlite3.connect(uri, uri=True, timeout=2.0)
        con.execute("SELECT 1 FROM sqlite_master LIMIT 1")
        return con, None
    except Exception:
        pass
    # Fallback: copia store.db (+ -wal/-shm) pra tmp e abre a copia.
    tmpd = tempfile.mkdtemp(prefix="cursor-cli-chats.")
    base = os.path.join(tmpd, "store.db")
    shutil.copy2(db_path, base)
    for suf in ("-wal", "-shm"):
        src = db_path + suf
        if os.path.exists(src):
            try:
                shutil.copy2(src, base + suf)
            except Exception:
                pass
    con = sqlite3.connect(f"file:{base}?mode=ro", uri=True, timeout=2.0)
    return con, tmpd

def load_meta(con):
    """Decodifica meta.value (hex -> JSON). Retorna dict (pode ser vazio)."""
    try:
        rows = con.execute("SELECT key, value FROM meta").fetchall()
    except Exception:
        return {}
    for k, v in rows:
        if not v:
            continue
        try:
            return json.loads(bytes.fromhex(v).decode("utf-8", "replace"))
        except Exception:
            continue
    return {}

def content_to_text(content):
    """Normaliza content (str | [ {type:text,text}... ]) -> texto plano."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for it in content:
            if isinstance(it, dict) and isinstance(it.get("text"), str):
                parts.append(it["text"])
        return "\n".join(parts)
    return ""

# Wrappers de boilerplate que NAO sao um prompt real do usuario.
BOILER_PREFIXES = ("<user_info", "<system_reminder", "<rules", "<additional_data")

def is_meaningful_query(q):
    q = q.strip()
    if not q or q == ".":
        return False
    low = q.lstrip().lower()
    for p in BOILER_PREFIXES:
        if low.startswith(p):
            return False
    return True

def extract_user_queries(text):
    """Extrai o conteudo de <user_query>...</user_query>. Se nao houver tag,
    usa o proprio texto (quando nao for boilerplate)."""
    qs = re.findall(r'<user_query>\s*(.*?)\s*</user_query>', text, re.S)
    if qs:
        return qs
    return [text]

def clean_oneline(s, limit):
    """Colapsa whitespace, remove linhas com cara de segredo, capa em limit."""
    # remove linhas suspeitas inteiras
    safe_lines = [ln for ln in s.splitlines() if not SECRET_RE.search(ln)]
    s = " ".join(safe_lines)
    s = re.sub(r'\s+', ' ', s).strip()
    if len(s) > limit:
        s = s[:limit - 1].rstrip() + "…"
    return s

def process_db(db_path):
    try:
        mtime_ms = int(os.stat(db_path).st_mtime * 1000)
    except Exception:
        mtime_ms = 0

    # Filtro --since pelo mtime do store.db (barato, evita abrir o DB).
    if SINCE_MS is not None and mtime_ms and mtime_ms < SINCE_MS:
        return None

    con = None
    tmpd = None
    try:
        con, tmpd = open_ro(db_path)
        meta = load_meta(con)

        # Conta blobs e coleta apenas os JSON (prefixo b'{"'), em ordem de
        # tamanho crescente: mensagens de usuario costumam ser as menores.
        try:
            rows = con.execute(
                "SELECT data FROM blobs ORDER BY length(data) ASC"
            ).fetchall()
        except Exception:
            rows = []

        n_blobs = len(rows)
        user_queries = []   # (len_text, query) — menores primeiro
        workspace = ""

        for (data,) in rows:
            if not data or data[:2] != b'{"':
                continue
            try:
                d = json.loads(bytes(data).decode("utf-8", "replace"), strict=False)
            except Exception:
                continue
            if not isinstance(d, dict):
                continue
            role = d.get("role")
            text = content_to_text(d.get("content"))
            if not text:
                continue

            # Workspace path (melhor esforco, do bloco <user_info>).
            if not workspace:
                mw = re.search(r'Workspace Path:\s*([^\n<]+)', text)
                if mw:
                    workspace = mw.group(1).strip()

            if role != "user":
                continue
            for q in extract_user_queries(text):
                if is_meaningful_query(q):
                    user_queries.append((len(q), q))

    finally:
        if con is not None:
            try: con.close()
            except Exception: pass
        if tmpd:
            shutil.rmtree(tmpd, ignore_errors=True)

    # --- title + summary ---
    name = meta.get("name") if isinstance(meta, dict) else None

    if user_queries:
        # Ordena por tamanho (menor = mais provavel a primeira pergunta direta),
        # desempata por conteudo pra ser estavel entre runs.
        user_queries.sort(key=lambda t: (t[0], t[1]))
        first_q = user_queries[0][1]
        title = clean_oneline(first_q, 80)
        if not title:
            title = name or "Cursor CLI chat"
        summary = clean_oneline(first_q, 500)
        # Enriquece summary com contagem de mensagens.
        n_user = len(user_queries)
        tail = f" (chat Cursor CLI; {n_blobs} blobs, {n_user} prompts do usuario)"
        if len(summary) + len(tail) <= 500:
            summary = summary + tail
    else:
        title = name or "Cursor CLI chat"
        title = clean_oneline(title, 80)
        summary = clean_oneline(
            f"Conversa Cursor CLI ({n_blobs} mensagens)", 500
        )

    # --- timestamp: contrato pede mtime do store.db ---
    timestamp = str(mtime_ms) if mtime_ms else ""

    # --- item_id estavel: sha1 do path absoluto do store.db ---
    abs_path = os.path.abspath(db_path)
    item_id = hashlib.sha1(abs_path.encode("utf-8")).hexdigest()

    return {
        "tool": "cursor-cli",
        "item_id": item_id,
        "title": title,
        "summary": summary,
        "timestamp": timestamp,
        "cwd_hint": workspace or "",
        "source_path": abs_path,
        "kind": "conversation",
    }

def main():
    out = sys.stdout
    for line in sys.stdin:
        db_path = line.strip()
        if not db_path:
            continue
        try:
            item = process_db(db_path)
        except Exception as e:
            sys.stderr.write(f"cursor-cli-chats: falha em {db_path}: {e}\n")
            continue
        if item is None:
            continue
        out.write(json.dumps(item, ensure_ascii=False, separators=(",", ":")))
        out.write("\n")

main()
PYEOF

printf '%s\n' "${DBS[@]}" | python3 "$PYTMP"

exit 0
