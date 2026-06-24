import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { create, insert, remove, search, type AnyOrama } from "@orama/orama";
import { EMBED_DIM, embed, warmup } from "./embeddings.js";
import {
  walkVault,
  parseNote,
  noteKey,
  assertInsideVault,
  type ParsedNote,
} from "./vault.js";

const log = (...a: unknown[]) => process.stderr.write(`[notes-mcp] ${a.join(" ")}\n`);

export type SearchMode = "hybrid" | "fulltext" | "semantic";

interface CacheEntry {
  mtime: number;
  vector: number[];
}
type EmbeddingCache = Record<string, CacheEntry>; // relPath -> entry

interface SearchHit {
  relPath: string;
  title: string;
  folder: string;
  score: number;
  snippet: string;
}

const ORAMA_SCHEMA = {
  relPath: "string",
  title: "string",
  folder: "string",
  content: "string",
  mtime: "number",
  embedding: `vector[${EMBED_DIM}]`,
} as const;

export class Store {
  private vaultRoot: string;
  private cacheFile: string;
  private db: AnyOrama | null = null;
  private notes = new Map<string, ParsedNote>(); // relPath -> note
  private nameMap = new Map<string, string[]>(); // noteKey -> relPath[]
  private backlinks = new Map<string, Set<string>>(); // relPath -> set(relPath que apontam pra ele)
  private oramaIds = new Map<string, string>(); // relPath -> orama doc id
  private cache: EmbeddingCache = {};
  private initPromise: Promise<void> | null = null;

  constructor(vaultRoot: string) {
    this.vaultRoot = vaultRoot;
    // Cache FORA do vault (o vault é repo git) — XDG cache ou override por env.
    const cacheDir =
      process.env.NOTES_MCP_CACHE_DIR ?? path.join(os.homedir(), ".cache", "notes-mcp");
    try {
      fs.mkdirSync(cacheDir, { recursive: true });
    } catch {
      /* ignore */
    }
    this.cacheFile = path.join(cacheDir, "embeddings.json");
  }

  /** Inicializa (ou reusa) o índice. Idempotente. */
  init(opts: { force?: boolean } = {}): Promise<void> {
    if (!this.initPromise) {
      this.initPromise = this.build(opts.force ?? false);
    }
    return this.initPromise;
  }

  size(): number {
    return this.notes.size;
  }

  private loadCache(force: boolean): void {
    if (force) {
      this.cache = {};
      return;
    }
    try {
      this.cache = JSON.parse(fs.readFileSync(this.cacheFile, "utf8")) as EmbeddingCache;
    } catch {
      this.cache = {};
    }
  }

  private saveCache(): void {
    try {
      fs.writeFileSync(this.cacheFile, JSON.stringify(this.cache));
    } catch (e) {
      log("aviso: não consegui salvar cache de embeddings:", String(e));
    }
  }

  private async build(force: boolean): Promise<void> {
    const t0 = Date.now();
    this.loadCache(force);
    await warmup();

    const files = walkVault(this.vaultRoot);
    log(`indexando ${files.length} notas (vault: ${this.vaultRoot})...`);

    const db = await create({ schema: ORAMA_SCHEMA });
    this.notes.clear();
    this.nameMap.clear();
    this.backlinks.clear();
    this.oramaIds.clear();

    const freshCache: EmbeddingCache = {};
    let recomputed = 0;

    for (const abs of files) {
      let note: ParsedNote;
      try {
        note = parseNote(this.vaultRoot, abs);
      } catch (e) {
        log(`pulando ${abs}: ${String(e)}`);
        continue;
      }
      this.notes.set(note.relPath, note);

      // index de nomes para resolução de wikilink
      const key = noteKey(note.relPath);
      const arr = this.nameMap.get(key) ?? [];
      arr.push(note.relPath);
      this.nameMap.set(key, arr);

      // embedding com cache por mtime
      const cached = this.cache[note.relPath];
      let vector: number[];
      if (cached && cached.mtime === note.mtime && cached.vector.length === EMBED_DIM) {
        vector = cached.vector;
      } else {
        vector = await embed(`${note.title}\n\n${note.content}`);
        recomputed++;
        if (recomputed % 50 === 0) log(`  embeddings recalculados: ${recomputed}`);
      }
      freshCache[note.relPath] = { mtime: note.mtime, vector };

      const id = await insert(db, {
        relPath: note.relPath,
        title: note.title,
        folder: note.folder,
        content: note.content,
        mtime: note.mtime,
        embedding: vector,
      });
      this.oramaIds.set(note.relPath, id as string);
    }

    this.cache = freshCache;
    this.saveCache();
    this.db = db;
    this.computeBacklinks();

    log(
      `índice pronto: ${this.notes.size} notas, ${recomputed} embeddings (re)calculados em ${(
        (Date.now() - t0) /
        1000
      ).toFixed(1)}s`
    );
  }

  private computeBacklinks(): void {
    this.backlinks.clear();
    for (const note of this.notes.values()) {
      for (const target of note.linkTargets) {
        const targets = this.resolveLink(target);
        for (const t of targets) {
          const set = this.backlinks.get(t) ?? new Set<string>();
          set.add(note.relPath);
          this.backlinks.set(t, set);
        }
      }
    }
  }

  /** Resolve um alvo de wikilink (nome ou caminho) para relPath(s) existentes. */
  private resolveLink(target: string): string[] {
    // tenta match exato por relPath (com ou sem .md)
    const withMd = target.toLowerCase().endsWith(".md") ? target : `${target}.md`;
    for (const relPath of this.notes.keys()) {
      if (relPath === target || relPath === withMd) return [relPath];
    }
    // fallback: por nome (basename)
    return this.nameMap.get(noteKey(target)) ?? [];
  }

  /** Resolve um path/nome informado pelo usuário para uma nota indexada. */
  resolveNote(pathOrName: string): ParsedNote | null {
    if (this.notes.has(pathOrName)) return this.notes.get(pathOrName)!;
    const withMd = pathOrName.toLowerCase().endsWith(".md") ? pathOrName : `${pathOrName}.md`;
    if (this.notes.has(withMd)) return this.notes.get(withMd)!;
    const byName = this.nameMap.get(noteKey(pathOrName));
    if (byName && byName.length > 0) return this.notes.get(byName[0])!;
    return null;
  }

  private snippet(content: string, query: string, len = 240): string {
    const flat = content.replace(/\s+/g, " ").trim();
    const idx = flat.toLowerCase().indexOf(query.toLowerCase().split(/\s+/)[0] ?? "");
    if (idx < 0) return flat.slice(0, len);
    const start = Math.max(0, idx - 60);
    return (start > 0 ? "…" : "") + flat.slice(start, start + len) + (flat.length > start + len ? "…" : "");
  }

  async query(q: string, mode: SearchMode, limit: number): Promise<SearchHit[]> {
    if (!this.db) throw new Error("índice não inicializado");
    const params: Record<string, unknown> = {
      term: q,
      limit,
      properties: ["title", "content", "folder"],
    };

    if (mode === "fulltext") {
      params.mode = "fulltext";
    } else {
      // 'hybrid' (BM25 + vetor) ou 'semantic' (só vetor)
      const vector = await embed(q);
      params.vector = { value: vector, property: "embedding" };
      params.similarity = 0.25;
      params.mode = mode === "semantic" ? "vector" : "hybrid";
    }

    const res = await search(this.db, params as never);
    return (res.hits as Array<{ score: number; document: Record<string, unknown> }>).map((h) => ({
      relPath: h.document.relPath as string,
      title: h.document.title as string,
      folder: h.document.folder as string,
      score: Number(h.score?.toFixed?.(4) ?? h.score),
      snippet: this.snippet(h.document.content as string, q),
    }));
  }

  getNoteDetail(pathOrName: string): {
    note: ParsedNote;
    outgoing: { target: string; resolved: string | null }[];
    backlinks: string[];
  } | null {
    const note = this.resolveNote(pathOrName);
    if (!note) return null;
    const outgoing = note.linkTargets.map((target) => {
      const r = this.resolveLink(target);
      return { target, resolved: r.length > 0 ? r[0] : null };
    });
    const backlinks = [...(this.backlinks.get(note.relPath) ?? [])];
    return { note, outgoing, backlinks };
  }

  list(opts: { folder?: string; limit: number; recent: boolean }): ParsedNote[] {
    let arr = [...this.notes.values()];
    if (opts.folder) arr = arr.filter((n) => n.folder === opts.folder || n.relPath.startsWith(opts.folder!));
    if (opts.recent) arr.sort((a, b) => b.mtime - a.mtime);
    else arr.sort((a, b) => a.relPath.localeCompare(b.relPath));
    return arr.slice(0, opts.limit);
  }

  listFolders(): string[] {
    return [...new Set([...this.notes.values()].map((n) => n.folder))].sort();
  }

  /** Adiciona/atualiza uma nota no índice ao vivo (após create/append). */
  private async upsert(absPath: string): Promise<void> {
    if (!this.db) return;
    const note = parseNote(this.vaultRoot, absPath);
    const oldId = this.oramaIds.get(note.relPath);
    if (oldId) {
      try {
        await remove(this.db, oldId);
      } catch {
        /* ignore */
      }
    }
    const vector = await embed(`${note.title}\n\n${note.content}`);
    this.cache[note.relPath] = { mtime: note.mtime, vector };
    const id = await insert(this.db, {
      relPath: note.relPath,
      title: note.title,
      folder: note.folder,
      content: note.content,
      mtime: note.mtime,
      embedding: vector,
    });
    this.oramaIds.set(note.relPath, id as string);
    this.notes.set(note.relPath, note);
    this.nameMap.set(noteKey(note.relPath), [
      ...new Set([...(this.nameMap.get(noteKey(note.relPath)) ?? []), note.relPath]),
    ]);
    this.computeBacklinks();
    this.saveCache();
  }

  /** Gera slug kebab-case ASCII a partir de um título. */
  private slugify(title: string): string {
    return title
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")  // remove diacríticos
      .replace(/[^a-z0-9\s-]/g, "")
      .trim()
      .replace(/[\s_]+/g, "-")
      .replace(/-{2,}/g, "-")
      .slice(0, 80)
      .replace(/^-+|-+$/g, "") || "nota";
  }

  /**
   * Monta o frontmatter "organize-ready" que a Frente 1.0 do /organize consome.
   * Segue o ADR-013: type canônico + provenance block para docs gerados por máquina.
   * pending_organize é booleano (sem aspas) de propósito — é o gatilho exato do grep.
   */
  private buildInboxFrontmatter(opts: {
    type?: string;
    tags?: string[];
    suggestedContext?: string;
    suggestedSubtype?: string;
    capturedAt: string;
    dateStr: string;
  }): string {
    const type = opts.type ?? "note";
    const tags = [...(opts.tags ?? [])];
    if (!tags.includes("pending-organize")) tags.push("pending-organize");
    const lines = [
      "---",
      `date: "${opts.dateStr}"`,
      `type: ${type}`,
      "tags:",
      ...tags.map((t) => `  - ${t}`),
      "pending_organize: true",
    ];
    if (opts.suggestedContext) lines.push(`suggested_context: ${opts.suggestedContext}`);
    lines.push(`suggested_subtype: ${opts.suggestedSubtype ?? "exploration"}`);
    lines.push("provenance:");
    lines.push("  generator: notes-mcp");
    lines.push(`  captured_at: "${opts.capturedAt}"`);
    lines.push("---");
    return lines.join("\n") + "\n";
  }

  async createNote(opts: {
    title: string;
    content: string;
    type?: string;
    filename?: string;
    suggestedContext?: string;
    suggestedSubtype?: string;
    tags?: string[];
  }): Promise<string> {
    const folder = "0-inbox";
    const d = new Date();
    const dateStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    const capturedAt = d.toISOString();

    // Filename: YYYY-MM-DD-<slug>.md (timestamp prefix obrigatório per CLAUDE.md)
    const slug = opts.filename
      ? opts.filename.replace(/\.md$/i, "").replace(/[/\\:*?"<>|]/g, "-").trim().slice(0, 100)
      : this.slugify(opts.title);
    const fileName = `${dateStr}-${slug}.md`;

    const absPath = path.join(this.vaultRoot, folder, fileName);
    assertInsideVault(this.vaultRoot, absPath);
    if (fs.existsSync(absPath)) {
      throw new Error(`Já existe uma nota em ${path.relative(this.vaultRoot, absPath)}`);
    }
    fs.mkdirSync(path.dirname(absPath), { recursive: true });

    const hasOwnFrontmatter = opts.content.trimStart().startsWith("---");

    let body: string;
    if (hasOwnFrontmatter) {
      body = opts.content;
    } else {
      const heading = opts.content.trimStart().startsWith("#")
        ? opts.content
        : `# ${opts.title}\n\n${opts.content}\n`;
      body = this.buildInboxFrontmatter({ ...opts, dateStr, capturedAt }) + "\n" + heading;
    }

    fs.writeFileSync(absPath, body, "utf8");
    await this.upsert(absPath);
    return path.relative(this.vaultRoot, absPath);
  }

  async appendNote(pathOrName: string, content: string): Promise<string> {
    const note = this.resolveNote(pathOrName);
    if (!note) throw new Error(`Nota não encontrada: ${pathOrName}`);
    assertInsideVault(this.vaultRoot, note.absPath);
    fs.appendFileSync(note.absPath, `\n${content}\n`, "utf8");
    await this.upsert(note.absPath);
    return note.relPath;
  }

  readRaw(pathOrName: string): string | null {
    const note = this.resolveNote(pathOrName);
    if (!note) return null;
    return fs.readFileSync(note.absPath, "utf8");
  }
}
