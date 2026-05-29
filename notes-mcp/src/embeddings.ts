import { pipeline, env, type FeatureExtractionPipeline } from "@xenova/transformers";

// Modelo local pequeno e bom para busca semântica de texto curto/médio.
const MODEL = "Xenova/all-MiniLM-L6-v2";
export const EMBED_DIM = 384;

// Permite baixar o modelo na primeira execução; depois fica em cache no disco.
env.allowRemoteModels = true;

let extractorPromise: Promise<FeatureExtractionPipeline> | null = null;

async function getExtractor(): Promise<FeatureExtractionPipeline> {
  if (!extractorPromise) {
    process.stderr.write(`[notes-mcp] carregando modelo de embeddings (${MODEL})...\n`);
    extractorPromise = pipeline("feature-extraction", MODEL) as Promise<FeatureExtractionPipeline>;
  }
  return extractorPromise;
}

/** O modelo trunca em ~256 tokens; cortamos o texto para não explodir memória/tempo. */
function clip(text: string, maxChars = 1600): string {
  const t = text.replace(/\s+/g, " ").trim();
  return t.length > maxChars ? t.slice(0, maxChars) : t;
}

/** Gera um embedding normalizado (length-384) para um texto. */
export async function embed(text: string): Promise<number[]> {
  const extractor = await getExtractor();
  const out = await extractor(clip(text), { pooling: "mean", normalize: true });
  return Array.from(out.data as Float32Array);
}

/** Pré-aquece o modelo (usado no boot em background). */
export async function warmup(): Promise<void> {
  await getExtractor();
}
