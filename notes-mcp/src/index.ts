#!/usr/bin/env node
import path from "node:path";
import os from "node:os";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { Store, type SearchMode } from "./store.js";

const log = (...a: unknown[]) => process.stderr.write(`[notes-mcp] ${a.join(" ")}\n`);

const VAULT = process.env.NOTES_VAULT_PATH || path.join(os.homedir(), ".notes");
const store = new Store(VAULT);

// Modo CLI: `node dist/index.js --reindex` reconstrói o cache e sai (não sobe o server).
if (process.argv.includes("--reindex")) {
  log("reindex forçado...");
  await store.init({ force: true });
  log(`pronto: ${store.size()} notas indexadas.`);
  process.exit(0);
}

const text = (s: string) => ({ content: [{ type: "text" as const, text: s }] });

const server = new McpServer({ name: "notes", version: "1.0.0" });

// Inicia a indexação em background para o handshake do MCP responder rápido.
const indexReady = store.init().catch((e) => {
  log("falha ao indexar:", String(e));
});
const ensureReady = () => indexReady;

server.registerTool(
  "search_notes",
  {
    title: "Buscar notas",
    description:
      "Busca no vault Obsidian (~/.notes). mode='hybrid' (padrão) combina full-text + semântica; 'fulltext' só keyword (BM25); 'semantic' só significado (embeddings). Retorna trechos rankeados com o caminho relativo da nota.",
    inputSchema: {
      query: z.string().describe("Termo ou pergunta a buscar."),
      mode: z.enum(["hybrid", "fulltext", "semantic"]).optional().describe("Modo de busca (padrão: hybrid)."),
      limit: z.number().int().min(1).max(50).optional().describe("Número de resultados (padrão: 8)."),
    },
  },
  async ({ query, mode, limit }) => {
    await ensureReady();
    const hits = await store.query(query, (mode ?? "hybrid") as SearchMode, limit ?? 8);
    if (hits.length === 0) return text(`Nenhum resultado para "${query}".`);
    const body = hits
      .map(
        (h, i) =>
          `${i + 1}. [${h.folder}] ${h.title}  (score ${h.score})\n   path: ${h.relPath}\n   ${h.snippet}`
      )
      .join("\n\n");
    return text(`${hits.length} resultado(s) para "${query}" (modo ${mode ?? "hybrid"}):\n\n${body}`);
  }
);

server.registerTool(
  "read_note",
  {
    title: "Ler nota",
    description:
      "Lê uma nota pelo caminho relativo (ex.: '2-knowledge/foo.md') ou pelo nome ([[wikilink]]). Retorna o conteúdo completo + frontmatter + links de saída resolvidos + backlinks (notas que apontam para ela).",
    inputSchema: {
      path: z.string().describe("Caminho relativo ou nome da nota."),
    },
  },
  async ({ path: p }) => {
    await ensureReady();
    const detail = store.getNoteDetail(p);
    if (!detail) return text(`Nota não encontrada: ${p}`);
    const raw = store.readRaw(p) ?? "";
    const outgoing = detail.outgoing
      .map((o) => `  - [[${o.target}]]${o.resolved ? ` → ${o.resolved}` : " (não resolvido)"}`)
      .join("\n");
    const backlinks = detail.backlinks.map((b) => `  - ${b}`).join("\n");
    return text(
      `# ${detail.note.title}\n` +
        `path: ${detail.note.relPath}\n` +
        `folder: ${detail.note.folder}\n\n` +
        `--- LINKS DE SAÍDA ---\n${outgoing || "  (nenhum)"}\n\n` +
        `--- BACKLINKS ---\n${backlinks || "  (nenhum)"}\n\n` +
        `--- CONTEÚDO ---\n${raw}`
    );
  }
);

server.registerTool(
  "list_notes",
  {
    title: "Listar notas",
    description:
      "Lista notas do vault. Filtra por pasta top-level (0-inbox, 1-contexts, 2-knowledge, 4-journal, 5-archive, 6-audits, 7-brag-doc) e ordena por mais recente (recent=true) ou alfabético.",
    inputSchema: {
      folder: z.string().optional().describe("Pasta a filtrar (ex.: '1-contexts')."),
      recent: z.boolean().optional().describe("Ordenar por mtime decrescente (padrão: false)."),
      limit: z.number().int().min(1).max(200).optional().describe("Máximo de notas (padrão: 30)."),
    },
  },
  async ({ folder, recent, limit }) => {
    await ensureReady();
    const notes = store.list({ folder, recent: recent ?? false, limit: limit ?? 30 });
    const header = `${notes.length} nota(s)${folder ? ` em ${folder}` : ""}. Pastas: ${store
      .listFolders()
      .join(", ")}\n\n`;
    const body = notes.map((n) => `- [${n.folder}] ${n.title}  →  ${n.relPath}`).join("\n");
    return text(header + body);
  }
);

server.registerTool(
  "create_note",
  {
    title: "Criar nota",
    description:
      "Cria uma nova nota no vault. Por padrão grava em '0-inbox/' (fluxo de captura — o /organize processa depois). Recusa sobrescrever notas existentes.",
    inputSchema: {
      title: z.string().describe("Título da nota."),
      content: z.string().describe("Conteúdo em markdown (sem precisar repetir o título)."),
      folder: z.string().optional().describe("Pasta destino (padrão: '0-inbox')."),
      filename: z.string().optional().describe("Nome do arquivo (padrão: derivado do título)."),
    },
  },
  async ({ title, content, folder, filename }) => {
    await ensureReady();
    try {
      const rel = await store.createNote({ title, content, folder, filename });
      return text(`Nota criada: ${rel}`);
    } catch (e) {
      return text(`Erro ao criar nota: ${String(e)}`);
    }
  }
);

server.registerTool(
  "append_note",
  {
    title: "Anexar a uma nota",
    description: "Acrescenta conteúdo ao final de uma nota existente (pelo caminho relativo ou nome).",
    inputSchema: {
      path: z.string().describe("Caminho relativo ou nome da nota existente."),
      content: z.string().describe("Conteúdo markdown a anexar."),
    },
  },
  async ({ path: p, content }) => {
    await ensureReady();
    try {
      const rel = await store.appendNote(p, content);
      return text(`Conteúdo anexado em: ${rel}`);
    } catch (e) {
      return text(`Erro ao anexar: ${String(e)}`);
    }
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
log(`server conectado (stdio). vault: ${VAULT}`);
