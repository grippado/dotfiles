import fs from "node:fs";
import path from "node:path";
import matter from "gray-matter";

export interface ParsedNote {
  /** caminho absoluto */
  absPath: string;
  /** caminho relativo ao vault (id canônico) */
  relPath: string;
  /** título: frontmatter.title ou basename */
  title: string;
  /** pasta top-level (0-inbox, 1-contexts, ...) */
  folder: string;
  /** mtime em ms */
  mtime: number;
  /** alvos de wikilink de saída (nomes, não resolvidos) */
  linkTargets: string[];
  /** corpo sem frontmatter */
  content: string;
  /** frontmatter parseado */
  frontmatter: Record<string, unknown>;
}

const IGNORE_DIRS = new Set([
  ".git",
  ".obsidian",
  ".claude",
  ".trash",
  "node_modules",
  "attachments",
]);

const WIKILINK_RE = /\[\[([^\]|#]+)(?:[#|][^\]]*)?\]\]/g;

/** Lista todos os .md do vault, ignorando pastas de sistema. */
export function walkVault(vaultRoot: string): string[] {
  const out: string[] = [];
  const walk = (dir: string) => {
    let entries: fs.Dirent[];
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const e of entries) {
      if (e.name.startsWith(".")) continue;
      const full = path.join(dir, e.name);
      if (e.isDirectory()) {
        if (IGNORE_DIRS.has(e.name)) continue;
        walk(full);
      } else if (e.isFile() && e.name.toLowerCase().endsWith(".md")) {
        out.push(full);
      }
    }
  };
  walk(vaultRoot);
  return out;
}

/** Parseia um arquivo .md do vault. */
export function parseNote(vaultRoot: string, absPath: string): ParsedNote {
  const raw = fs.readFileSync(absPath, "utf8");
  let data: Record<string, unknown> = {};
  let content = raw;
  try {
    const parsed = matter(raw);
    data = parsed.data as Record<string, unknown>;
    content = parsed.content;
  } catch {
    // frontmatter malformado: trata tudo como corpo
  }
  const stat = fs.statSync(absPath);
  const relPath = path.relative(vaultRoot, absPath);
  const folder = relPath.split(path.sep)[0] || ".";
  const baseName = path.basename(absPath, path.extname(absPath));
  const title =
    typeof data.title === "string" && data.title.trim()
      ? (data.title as string)
      : baseName;

  const linkTargets = new Set<string>();
  let m: RegExpExecArray | null;
  WIKILINK_RE.lastIndex = 0;
  while ((m = WIKILINK_RE.exec(content)) !== null) {
    const target = m[1].trim();
    if (target) linkTargets.add(target);
  }

  return {
    absPath,
    relPath,
    title,
    folder,
    mtime: stat.mtimeMs,
    linkTargets: [...linkTargets],
    content,
    frontmatter: data,
  };
}

/** Chave normalizada de uma nota para resolução de wikilink (basename minúsculo). */
export function noteKey(relPathOrName: string): string {
  return path.basename(relPathOrName, ".md").toLowerCase().trim();
}

/** Garante que um caminho está dentro do vault (proteção contra path traversal). */
export function assertInsideVault(vaultRoot: string, absPath: string): void {
  const rel = path.relative(vaultRoot, absPath);
  if (rel.startsWith("..") || path.isAbsolute(rel)) {
    throw new Error(`Caminho fora do vault: ${absPath}`);
  }
}
