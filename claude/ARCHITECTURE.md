# Claude Atlas — Arquitetura do meu setup

> Referência viva. Lê isso aqui antes de mexer em `~/.claude/`. Se mexeu e mudou um princípio, atualiza esse arquivo. Se não atualizou, daqui a 3 meses não vai entender o que tava pensando.

**Última atualização:** 2026-04-30 (Fase 0)
**Estado:** infraestrutura criada, nada de symlink ainda. Fase 1 começa depois da revisão.

---

## 1. Por que isso existe

Antes da refatoração (snapshot 2026-04-30):

- **192 artefatos** espalhados em **17 roots** (`~/.claude/` + 13 repos com `.claude/` próprio).
- **174 issues** detectados pelo `claude-atlas check`: **22 high, 30 medium, 122 low**.
- **`~/.dotfiles/claude/`** era um mirror parcial e desatualizado de `~/.claude/`. Source-of-truth ambíguo: ninguém sabia qual era o canônico, então cada vez que eu queria atualizar um agent eu olhava os dois e escolhia o que parecia mais novo.
- **`qa.md`** existia idêntico em `~/.claude/commands/` e `flagbridge/.claude/commands/`. Dois arquivos, mesmo SHA.
- **3 repos isaac** (backoffice, rf-monorepo, communication-api) carregavam cópias byte-a-byte iguais de 6 agents (`code-reviewer`, `debugger`, `test-writer`, `self-reviewer`, `implementation`, `pattern-finder`) e 2 skills (`create-pr`, `linear-ticket-reviewer`). Quando eu atualizava um, os outros 2 ficavam stale silenciosamente.
- **Comandos repo-específicos** (`/sync` do flagbridge, `/organize` do notes, `/gravity-make` do gds) só rodavam dentro do repo certo. Cada repo novo que eu clonava partia do zero.
- **Nenhum índice humano**: pra saber o que existia eu precisava `find ~ -name '*.md' -path '*.claude*'`.

A refatoração é pra resolver esses 5 problemas. Não é "deixar bonito" — é tirar a ambiguidade de source-of-truth e fazer comandos repo-locais alcançáveis de qualquer cwd.

---

## 2. Princípios

Regras que guiam decisões aqui — não só dessa refatoração, mas de qualquer mudança futura:

1. **REGISTRY é a única fonte de verdade pra `scope → path`.** Mover um repo? Edita uma linha no `REGISTRY.json`, roda `atlas-sync`. Nada mais precisa saber onde os repos moram.
2. **Verbo puro só para genérico real.** `ship`, `qa`, `quick-commit`, `dep-check`, `explain`, `scaffold`, `review-changes` continuam globais sem scope porque funcionam em qualquer codebase. Se um comando depende de um repo específico, **vai ter `:scope` no nome**, ponto.
3. **Aliases são sempre explícitos.** Frontmatter `alias_global: true` no comando do repo. Sem inferência por filesystem ("ah, só notes tem organize, vira alias automático") — isso quebra silenciosamente quando um segundo repo registrar o mesmo verbo. **Erro alto, sempre.**
4. **Source-of-truth fica perto do dono.** Comando do flagbridge mora em `flagbridge/.claude/commands/sync.md`, versionado no repo. `~/.claude/commands/sync:flagbridge.md` é symlink — não tem conteúdo próprio.
5. **Symlinks até doer, plugins depois.** Symlinks são triviais e suficientes. Migração pra Claude Code Plugins é a resposta correta a longo prazo, mas só quando os symlinks incomodarem de verdade. Não fazer plugin-ification prematura.
6. **Override de agent global precisa justificativa documentada.** Frontmatter `extends: <global-agent>` ou pelo menos um comentário explicando o porquê. Override silencioso = bug em câmera lenta.
7. **Drift é detectado, não previsto.** `atlas-snapshot` roda diário, registra issues em `atlas-history/CHANGES.log`. Se o número subir do nada, sei.
8. **Toda mudança automática é reversível.** `atlas-sync` rastreia tudo que gera em `.atlas-managed`. Reversão é um comando (`cat ~/.claude/.atlas-managed | xargs rm`). Pre-existing files hand-written nunca são tocados — script só remove o que ele mesmo criou.
9. **Scope pessoal vs scope compartilhado.** Cada scope tem `shared: true|false` no REGISTRY. `false` = repo pessoal, Atlas escreve à vontade (promove, mescla, injeta `extends:`, deleta duplicatas). `true` = repo de time, Atlas é **read-only** — pode indexar (symlinks pra exposição global), nunca modifica os arquivos do repo. Mudança em repo shared = PR no repo + discussão de time, nunca operação automática local.
10. **Dependências externas têm limites conhecidos.** Onde o Atlas depende de ferramentas que ele não controla (claude-atlas, parser do Claude Code, filesystem, cron), as limitações são documentadas em ADR e contornadas com workarounds explícitos. Quando upstream resolver, simplificar e remover o workaround. `--no-global` (ADR-007), slug `labor-city` em vez de `labor.city` (ADR-002), e symlinks em vez de plugins (ADR-001) são todos workarounds — não estado final.

---

## 3. Convenções

### Naming

| Tipo | Padrão | Exemplo |
|---|---|---|
| Comando global genérico | `<verbo>.md` | `ship.md`, `qa.md`, `quick-commit.md` |
| Comando repo-específico (canônico) | `<verbo>.md` dentro do repo | `flagbridge/.claude/commands/sync.md` |
| Comando repo-específico (visível globalmente) | `<verbo>:<scope>.md` em `~/.claude/commands/` | `sync:flagbridge.md` |
| Alias global de comando repo-específico | `<verbo>.md` em `~/.claude/commands/` (symlink) | `organize.md → organize:notes.md` |
| Sub-namespace dentro de repo | `<verbo>:<sub>.md` | `brain:github.md` (vira `brain:github:flagbridge.md`) |

> **Convenção do separador `:`** — o **último** `:` é sempre o separador de scope. Tudo antes dele é o verbo (que pode ele mesmo conter `:` pra sub-namespacing).
> `brain:github:flagbridge` = verbo `brain:github`, scope `flagbridge`.
> `sync:flagbridge` = verbo `sync`, scope `flagbridge`.
> O `atlas-sync` aplica essa regra mecanicamente: pega o nome do arquivo no repo (`basename foo.md` = `foo`) e concatena `:${scope}.md`. Não há parser ambíguo.

### Frontmatter

Frontmatter YAML no topo do `.md`. Campos relevantes:

```yaml
---
description: O que o comando faz, em uma linha.
alias_global: true        # opcional: cria ~/.claude/commands/<verbo>.md como alias
extends: code-reviewer    # opcional (agents): documenta override intencional do agent global
---
```

`alias_global: true` em **dois** comandos com o mesmo verbo = `atlas-sync` falha com erro alto. Sem resolução automática.

### Quando criar global vs scoped

- **Global** se o comando não depende de paths/configs/dialetos de um único repo. Se eu rodar `/ship` em qualquer projeto, faz sentido.
- **Scoped** se o comando assume estrutura, dependências ou conhecimento de um repo. `/sync` do flagbridge sabe o monorepo, os pacotes, as convenções específicas. Não vira global.
- **Dúvida?** Começa scoped. Promove pra global depois se virar genérico — o caminho contrário (rebaixar de global pra scoped) é mais doloroso.

### Slugs

Nomes completos dos repos. **Sem abreviação.** `gravity-design-system`, não `gds`. Autocomplete resolve.

Exceção: `labor-city` (hífen) em vez de `labor.city` (ponto), porque `.` em filename de slash command é incerto. ADR-002.

---

## 4. Arquitetura

```
~/.claude/
├── REGISTRY.json              # ← fonte de verdade: scope → path
├── ARCHITECTURE.md            # ← este arquivo
├── CLAUDE.md                  # config global pessoal
├── settings.json              # config Claude Code (hooks, permissions)
├── .atlas-managed             # ← gerado: lista de symlinks que atlas-sync gerencia
│
├── bin/
│   ├── atlas-sync             # regenera symlinks/aliases a partir do REGISTRY
│   └── atlas-snapshot         # snapshot diário do claude-atlas check
│
├── atlas-history/
│   ├── 2026-04-30.txt         # snapshot inicial (baseline)
│   └── CHANGES.log            # uma linha por dia: data + counts
│
├── commands/
│   ├── ship.md                # global genérico (hand-written)
│   ├── qa.md                  # global genérico (hand-written)
│   ├── sync:flagbridge.md     # symlink → ~/www/personal/flagbridge/.claude/commands/sync.md
│   ├── organize:notes.md      # symlink → ~/.notes/.claude/commands/organize.md
│   ├── organize.md            # symlink → organize:notes.md  (alias_global: true)
│   └── ...
│
└── agents/
    ├── code-reviewer.md       # global
    ├── debugger.md            # global (após Fase 2 promover de isaac/*)
    └── ...
```

### Fluxo de `atlas-sync`

```
1. Lê REGISTRY.json
2. Apaga symlinks listados em .atlas-managed (cleanup idempotente)
3. Para cada scope com claude_dir != null:
     Para cada <repo>/<claude_dir>/commands/*.md:
         Cria ~/.claude/commands/<verb>:<scope>.md → symlink
         Se frontmatter tem alias_global: true:
             Registra claim
             Se outro scope já claimou esse verb → ERRO, exit 2
4. Para cada alias claimado:
     Se ~/.claude/commands/<verb>.md existe e NÃO é symlink → ERRO, exit 3
     Cria ~/.claude/commands/<verb>.md → symlink → <verb>:<scope>.md
5. Persiste lista nova em .atlas-managed
```

Modos:
- `atlas-sync` — aplica
- `atlas-sync --dry-run` — só mostra o que faria
- `atlas-sync --check` — exit non-zero se o filesystem divergiu do REGISTRY (útil em CI/cron)

### Como adicionar um novo scope

1. Editar `REGISTRY.json`: adicionar entrada em `scopes`.
2. Rodar `atlas-sync`.
3. Atualizar a seção "Catálogo" (manualmente por enquanto, auto-gerada futuramente).

### Como mover um repo

1. Editar uma linha no `REGISTRY.json` (path).
2. `atlas-sync`.
3. Pronto. Symlinks regenerados apontam pro novo lugar.

### Como tornar um comando alias global

1. No comando do repo (ex: `notes/.claude/commands/organize.md`), adicionar `alias_global: true` no frontmatter.
2. Rodar `atlas-sync`.
3. Se outro repo já tem alias com mesmo verbo, o script falha — resolver removendo um.

---

## 5. Catálogo

> Atualizado manualmente. Auto-geração planejada (ADR-005).

### Scopes ativos

| Slug | Path | Shared | Status |
|---|---|---|---|
| `flagbridge` | `~/www/personal/flagbridge` | não | ativo |
| `notes` | `~/.notes` | não | ativo |
| `labor-city` | `~/www/personal/labor.city` | não | ativo (slug ≠ dirname) |
| `declare-ui` | `~/www/personal/declare-ui` | não | ativo |
| `gravity-design-system` | `~/www/isaac/gravity-design-system` | **sim** | ativo, read-only |
| `isaac` | `~/www/isaac` | **sim** | deferido + read-only |

### Comandos globais (hand-written, agnósticos)

`ship`, `qa`, `quick-commit`, `review-changes`, `dep-check`, `explain`, `scaffold`.

### Comandos scoped (após Fase 3 rodar `atlas-sync`)

A planejar — todos virão automaticamente do scan dos repos. Lista hoje no dry-run:

- `flagbridge`: 17 commands (sync, brain, brain:github, brain:slack, bug, clickup, cmo, cpo, cto, design, docs, frontend, qa, sdk, security, sre, backend)
- `notes`: 1 command (organize)
- `gravity-design-system`: 2 commands (gravity-make, gravity-rfc)
- `labor-city`: 6 commands (api, component, page, pixel, prd, task)
- `declare-ui`: 1 command (declare-ui)

### Aliases globais ativos

| Alias | Resolve para | Source |
|---|---|---|
| `/organize` | `/organize:notes` | `notes/.claude/commands/organize.md` (frontmatter `alias_global: true`) |

### Variáveis de ambiente ativas (multi-máquina, ADR-009)

| Var | Recurso | Onde é usada | Default seguro? |
|---|---|---|---|
| `$NOTES_VAULT` | Path do vault Obsidian | `notes/.claude/commands/organize.md`, `notes/.claude/agents/vault-organizer.md` | Não — guard explícito; falha alto se ausente |

Ao adicionar var nova: documentar aqui, atualizar §11 checklist, conferir colisão de nome (`echo $VAR` + `grep` em rc files) antes de adotar.

---

## 6. ADRs (Architecture Decision Records)

Decisões importantes ficam aqui. Formato leve: contexto → decisão → consequências.

### ADR-001 — Symlinks antes de Plugins

**Contexto.** Claude Code suporta plugins (uma forma "oficial" de empacotar commands/agents/skills e expor globalmente via `~/.claude/settings.json`). Symlinks são a alternativa unix nativa: 1 hora pra montar tudo, zero infra adicional.

**Decisão.** Symlinks por enquanto. Plugins depois.

**Consequências.**
- Pró: implementação trivial. Source-of-truth fica nos repos. Atualizar um command no repo aparece imediatamente nos outros lugares.
- Contra: symlinks quebram se o repo for renomeado/movido **sem** atualizar o REGISTRY. `atlas-sync` regenera, mas é uma etapa manual.
- Migração futura: quando os symlinks incomodarem (provavelmente por problema de portabilidade entre máquinas, ou se eu quiser distribuir esse setup), vira plugin.

### ADR-002 — Slug `labor-city` em vez de `labor.city`

**Contexto.** Princípio é "slugs = nomes completos dos repos, sem abreviação". Mas `labor.city` tem `.`, e não consegui validar (sem invocar interativamente) se o parser de slash command do Claude Code trata `.` como separador de extensão.

**Decisão.** Slug `labor-city` (hífen). Path no REGISTRY aponta pro diretório real `~/www/personal/labor.city`.

**Consequências.**
- Pró: funciona com certeza, não tem ambiguidade no parser.
- Contra: pequena fricção mental — tenho que lembrar que slug ≠ dirname **só nesse caso**. Documentado no `_note` do scope.
- Reversão: se eu testar `/pixel:labor.city` interativamente e funcionar, troco a chave do JSON e rodo `atlas-sync`. 1 minuto de trabalho.

### ADR-003 — Frontmatter como source-of-truth de aliases

**Contexto.** Tinha duas opções pra declarar aliases globais: (a) frontmatter `alias_global: true` no comando do repo, descentralizado; (b) seção `global_aliases` no REGISTRY.json, centralizado. Inicialmente o REGISTRY ia ter ambos.

**Decisão.** Frontmatter é fonte de verdade. REGISTRY tem só `scopes`.

**Consequências.**
- Pró: alias mora junto com o comando. Se eu mover o comando entre repos, o alias vai junto. Não precisa lembrar de editar REGISTRY toda vez.
- Pró: descobrir quais aliases existem é `grep -r 'alias_global: true' ~/www`.
- Contra: pra ver a lista compacta de aliases, depende do "Catálogo" desse arquivo (manual hoje, auto futuramente).
- Reversão: trivial — `atlas-sync` pode ler ambos no futuro se eu quiser.

### ADR-004 — Scope `isaac` é cluster, não repo

**Contexto.** `~/www/isaac/` não é um repo — é um diretório com 7 sub-repos da empresa (backoffice, rf-monorepo, communication-api, payment-api, sorting-hat, backoffice-bff, gravity-design-system). 6 deles compartilham agents/skills idênticos.

**Exceção:** `gravity-design-system` mora dentro de `~/www/isaac/` mas **é um scope independente** no REGISTRY. Tem `.claude/` próprio com agents (`gds-*`) e commands (`gravity-make`, `gravity-rfc`) que são exclusivos do design system, não do cluster isaac. Ambos são `shared: true` (ADR-006), mas `gravity-design-system` é indexado normalmente; `isaac` fica deferido por ser cluster sem `.claude/` próprio.

**Decisão.** Registrar `isaac` no REGISTRY com `claude_dir: null` e `shared: true`. `atlas-sync` skipa scopes com claude_dir nulo. As duplicações entre os sub-repos isaac (6 agents + 2 skills idênticos em 3 repos) **não são resolvidas** pela Fase 2 — viraram dívida de time, registrada em §10 (SHARED-DEBT). Caso o time queira deduplicar, é PR de time no monorepo isaac, não operação do Atlas pessoal.

**Consequências.**
- Pró: REGISTRY já documenta a existência do cluster pra futuro mapping.
- Contra: nada acontece automático ainda. Comandos como `workflow:isaac` não existem hoje.
- Decisão futura (pós-Fase 2): ou (a) `isaac` deixa de ser scope (artefatos viram globais), ou (b) cria-se `~/www/isaac/.claude/` shared dir e o scope passa a apontar pra lá.

### ADR-006 — Scopes compartilhados são read-only

**Contexto.** `gravity-design-system` é repo do time Arco/Isaac, e `~/www/isaac/` agrega 6 outros repos do time. Originalmente Phase 1 ia injetar `extends:` no frontmatter dos 6 overrides isaac (3 code-reviewer + 3 test-writer). Comecei a editar `backoffice/.claude/agents/code-reviewer.md` e `rf-monorepo/.claude/agents/code-reviewer.md` antes de receber a instrução de tratar isaac como compartilhado.

**Decisão.** Scopes ganham campo `shared: bool` no REGISTRY. `shared: true` = Atlas é read-only no repo. Pode indexar (criar symlinks `verbo:scope.md` em `~/.claude/commands/`), nunca modifica arquivos. Reverti as 2 edições. Os 6 overrides isaac ficam como estão — observados, não atuados.

**Detalhe importante.** Read-only **não significa ignorar** o repo. Symlinks `verbo:scope.md` continuam sendo criados em `~/.claude/commands/` apontando pros arquivos do repo shared — eles passam a ser invocáveis globalmente. Os 2 commands de `gravity-design-system` (`gravity-make`, `gravity-rfc`) viram `gravity-make:gravity-design-system` e `gravity-rfc:gravity-design-system`. A política de "read-only" se aplica a operações de **escrita no repo**: injeção de frontmatter, deleção de arquivos, mesclagem de conteúdo, promoção pra global. Essas ficam fora — qualquer mudança nesses arquivos passa por PR no repo do time.

**Consequências.**
- Pró: zero risco de Atlas pessoal interferir em decisões/conventions de time. Decisões de override (manter ou apagar `code-reviewer` isaac) ficam onde devem ficar — discussão de time, no repo, não no meu setup.
- Pró: shared scopes ainda são úteis localmente (commands acessíveis globalmente, agents/skills indexados pelo claude-atlas).
- Contra: as duplicações entre os 3 isaac repos (mesmo `code-reviewer.md`/`debugger.md`/etc copiado byte-a-byte) continuam existindo, e o `claude-atlas check` vai continuar reportando como HIGH. **Aceitável** — registrado em §10 (SHARED-DEBT) como dívida de time, não problema do meu setup.
- Contra: regra opera por confiança (atlas-sync não enforcea, só sinaliza). Phase 1/2 humano-dirigidas precisam checar `shared` antes de escrever. Documentado, não automatizado.

### ADR-007 — atlas-snapshot ignora `~/.claude` por causa do symlink farm

**Contexto.** Após Fase 3 rodar, `atlas-snapshot` (que usava `--paths ~/.claude --paths ~/www`) saltou de 14 HIGH (Fase 1) para **45 HIGH**. Investigação: claude-atlas não é symlink-aware. Os 27 symlinks que `atlas-sync` cria em `~/.claude/commands/` apontam pros arquivos `.md` reais nos repos, e como o conteúdo lido é o mesmo (OS resolve o symlink), o checker reporta cada par symlink↔target como `duplicate_exact` HIGH. 31 dos 45 HIGH eram falsos positivos auto-causados.

**Decisão.** `atlas-snapshot` passa a rodar com `--no-global --auto-discover ~/www`. Isso scaneia todos os repos sob `~/www` (descobrindo `.claude/` aninhados) e ignora completamente `~/.claude`. O symlink farm fica fora do scan.

**Consequências.**
- Pró: contagem volta a refletir mudança real, não ruído estrutural. Pós-Fase 3 = 14 HIGH = mesmo da Fase 1, como esperado (Fase 3 só criou symlinks, não mudou conteúdo dos repos).
- Pró: drift detection volta a ser útil — uma subida no contador agora significa algo.
- Contra: perdemos detecção de **override pairs** (`projeto X` override `global X`). Mitigação: os overrides conhecidos (6 isaac) já estão documentados em §8 SHARED-DEBT. Novos overrides de scope pessoal seriam pegos quando `atlas-sync` rodar (dois scopes pessoais com mesmo verbo claimando alias_global = colisão imediata).
- Contra: perdemos detecção de duplicação dentro de `~/.claude/agents/` (improvável, mas possível). Mitigação: seção rara de mexer; se acontecer, manualmente faço `claude-atlas check --paths ~/.claude` ad-hoc.

**Trade-off explícito.** `--no-global` skipa `~/.claude` **inteiro**, não só `commands/`. Isso significa que os 7 commands hand-written globais (`ship`, `qa`, `dep-check`, `explain`, `quick-commit`, `review-changes`, `scaffold`) e os ~30 agents em `~/.claude/agents/` saíram do radar de drift detection. **Regressão consciente do Princípio 7** ("Drift é detectado, não previsto"). Aceito porque (a) os globais raramente mudam, (b) override detection contra eles já estava no SHARED-DEBT, (c) o custo de não detectar > o custo de 31 falsos positivos por scan. Recuperação plena depende do feature request upstream.

**Feature request pra claude-atlas (próxima versão).** Adicionar `--exclude PATH` (repeatable) ou `--ignore-symlinks` flag. Aí `atlas-snapshot` volta a scanear `~/.claude` excluindo `~/.claude/commands/`, recuperando cobertura completa. Issue a abrir no repo claude-atlas — fica registrado em §9 (Evolução prevista), não agendado. É projeto pessoal, vai esbarrar nisso da próxima vez que abrir o repo.

### ADR-008 — Pré-flight check em operações destrutivas de diretório

**Contexto.** Surpresa 2 da Fase 3: ao arquivar `~/.dotfiles/claude/` na Fase 1, quebrei silenciosamente 5 symlinks pré-existentes em `~/.claude/commands/` que apontavam pra lá. Princípio 8 ("toda mudança automática é reversível") não foi violado tecnicamente — atlas-sync não criou nem removeu esses symlinks — mas o efeito prático foi dano invisível por ~30 minutos até o `ls` da Fase 3 expor.

**Decisão.** Antes de qualquer operação que mova/arquive/delete um diretório, executar pré-flight obrigatório:

```bash
# Listar symlinks (de qualquer lugar) que apontam pro path-alvo
find ~ -maxdepth 8 -type l -lname '*<path-prefixo>*' 2>/dev/null | grep -v node_modules
```

Para cada symlink encontrado, decidir explicitamente:
- **Materializar** — `cp` o arquivo real no lugar do symlink (caso de globais que dependiam do dotfiles)
- **Redirecionar** — recriar symlink apontando pro novo destino (caso de archive renomeado mas funcional)
- **Aceitar quebra documentada** — se o symlink já era stale ou desnecessário, registrar e seguir

**Consequências.**
- Pró: transforma "ficar atento" em passo mecânico de checklist. Reduz dano invisível a zero (a regra é fácil de seguir; esquecer dela é o problema).
- Pró: aplicável fora do contexto Atlas — qualquer `mv`/`rm -rf` de diretório vira candidato a check.
- Contra: 30 segundos a mais antes de qualquer operação. Custo trivial.
- Pró indireto: alinha com Princípio 8 fortalecendo-o — reversibilidade real exige saber o que vai quebrar **antes** de quebrar.

### ADR-009 — Portabilidade multi-máquina via env vars com guard explícito

**Contexto.** Atlas usado em 2+ máquinas: MBP pessoal (`/Users/grippado`) + Mac Arco (`/Users/gabriel.gripp`, com layouts de diretório diferentes — vault em `.notes` aqui, em `PROJECTS/central-brain` lá). Levantamento na Fase 3 (após validação do `/organize`) achou **4 arquivos / 7 ocorrências em 3 padrões distintos**:

- (a) Vault externo (notes, 2 refs): genuinamente multi-localizado.
- (b) Memory path derivado do cwd (flagbridge, 1 ref): convenção do próprio Claude Code (`~/.claude/projects/<slug>/`, slug = path absoluto com `/` → `-`); varia por máquina por construção.
- (c) Self-reference ao próprio repo (declare-ui, 2 refs): redundante usar path absoluto.

**Decisão — estratégia por padrão, não solução única.**

| Padrão | Resolução | Exemplo |
|---|---|---|
| (a) Recurso externo multi-localizado | Env var **sem prefixo** (recurso geral) | `$NOTES_VAULT` |
| (b) Convenção derivada do Claude Code | Prosa descritiva da fórmula, sem path | "`~/.claude/projects/<slug>/memory/`, onde `<slug>` é o path do repo com `/` → `-`" |
| (c) Self-reference | Resolver em runtime | `$(git rev-parse --show-toplevel)` ou `.` |

**Convenção de nomes.** Var **sem prefixo** quando o recurso existe independente do Atlas (ex: `$NOTES_VAULT` — outros scripts/tools podem precisar). Prefixo **`$ATLAS_*`** reservado pra recursos que só o Atlas usa (hipotético `$ATLAS_HOME` apontando pra `~/.claude/`). Antes de adotar nome novo, checar `echo $VAR` e `~/.zshrc*` pra evitar colisão silenciosa — se já tomada, escalar pro prefixo.

**Princípio operacional — guard explícito é obrigatório.** Toda var declarada como dependência multi-máquina **falha alto** quando ausente, nunca silenciosamente:

```bash
# Em commands com bash:
: "${NOTES_VAULT:?NOTES_VAULT não está setada. Adicione 'export NOTES_VAULT=...' ao ~/.zshrc antes de rodar este command.}"
```

```markdown
# Em commands que são prosa pro LLM:
Se $NOTES_VAULT não estiver setada, pare e instrua o usuário a exportá-la antes de continuar — não tente inferir o path.
```

Conexão com **Princípio 7** (drift detectado, não previsto): config ausente em máquina nova é forma de drift que precisa ser detectada na primeira invocação, não silenciosamente contornada com fallback que executa contra dir errado.

**Consequências.**
- Pró: cada caso resolvido com a ferramenta certa — env var não é martelo único.
- Pró: máquina nova falha alto na primeira execução de um command que dependa de var não-setada. Diagnóstico imediato, não suspeita silenciosa.
- Contra: 3 padrões distintos = mais regras pra lembrar. Mitigado pelo §11 (Checklist de máquina nova).
- Reversão: trivial por arquivo. Substituir `$NOTES_VAULT` de volta por path absoluto se eu voltar pra single-machine.

**Vars ativas hoje:** `$NOTES_VAULT` (vault Obsidian). Lista mantida no §5 Catálogo.

### ADR-005 — Catálogo manual hoje, auto-gerado depois

**Contexto.** A seção "Catálogo" desse arquivo lista scopes/commands/aliases ativos. Hoje é manual. `atlas-sync` poderia regenerar entre marcadores `<!-- atlas:catalog:start -->` / `<!-- atlas:catalog:end -->`.

**Decisão.** Manual na Fase 0. Auto-geração quando o catálogo começar a stale (provavelmente após Fase 3).

**Consequências.**
- Pró: simplicidade inicial, foco em fundações.
- Contra: catálogo vai ficar desatualizado. Aceitável até Fase 3 — onde, idealmente, eu já implemento o auto-gen junto.

### ADR-010 — Configs Claude versionadas em `dotfiles-ai`; REGISTRY per-machine; settings = base + overlay

**Contexto.** Em 2026-05-08 a infra ganhou uma segunda máquina (Arco/`gabriel.gripp`) via Claude Enterprise. Antes disso, `~/.claude/` era artesanal: arquivos manuais soltos, sem versionamento, e o Atlas vivia inteiramente dentro de `~/.claude/{bin,REGISTRY.json,ARCHITECTURE.md}`. Tentar replicar manualmente na Arco gerou drift imediato (commands faltando, agents stale, settings divergente). Princípio 1 (a verdade vive na fonte, não em cópias) ficou inviável de manter à mão entre 2 máquinas.

**Decisão.** Tirar a fonte de verdade do `~/.claude/` e mover para um repo privado dedicado, `dotfiles-ai`:

```
dotfiles-ai/
├── claude/                       # symlinkado em ~/.claude/ (per-machine install.sh)
│   ├── CLAUDE.md, ARCHITECTURE.md, statusline-command-v2.sh
│   ├── settings.base.json        # config compartilhada (hooks, statusline, theme)
│   ├── commands/                 # globais manuais (ship, qa, /review-arco, etc.)
│   ├── agents/                   # manuais + categorias (engineering, design, …)
│   └── bin/                      # atlas-sync, atlas-snapshot
├── machines/<machine>/
│   ├── REGISTRY.json             # scopes específicos da máquina
│   ├── settings.overlay.json     # plugins + permissions per-machine
│   └── env.sh                    # NOTES_VAULT etc. (ADR-009)
├── scripts/
│   ├── merge-settings.sh         # base + overlay → ~/.claude/settings.json (jq deep-merge)
│   └── doctor.sh                 # sanity check
└── install.sh                    # idempotente; aceita --machine personal|arco
```

`install.sh` cria symlinks **arquivo a arquivo** (não dir-inteiro) em `~/.claude/commands/` e `~/.claude/agents/` — preserva os scoped symlinks que `atlas-sync` cria lado a lado dentro do mesmo diretório. Ao final, chama `atlas-sync` automaticamente.

**Por quê REGISTRY per-machine?** Cada máquina tem repos clonados diferentes (pessoal tem flagbridge/labor-city; Arco tem backoffice/communication-api/etc.). Forçar um único REGISTRY com paths condicionais seria mais frágil que ter dois arquivos honestos em `machines/{personal,arco}/REGISTRY.json`.

**Por quê base + overlay em settings?** A maior parte de `settings.json` é igual entre máquinas (hooks de memory-sync, statusline, theme). A divergência são plugins enabled e `permissions.defaultMode`. Manter dois `settings.json` completos duplica conteúdo e cria drift; usar base + overlay deep-merged via `jq '.[0] * .[1]'` garante que mudanças na base aparecem em ambas as máquinas no próximo `merge-settings.sh`.

**Conexão com Princípios.** Reforça **Princípio 1** (fonte única — agora o repo, não dois `~/.claude/` desconectados). Reforça **Princípio 7** (drift detectado, não previsto): `doctor.sh` aponta divergências entre repo state e máquina local; `git status` no `dotfiles-ai` aponta mudanças locais não pushadas pra outra máquina.

**Conexão com ADRs.** Substitui parcialmente ADR-001 (Symlinks antes de Plugins) — agora os symlinks apontam pra repo versionado, não pra arquivos artesanais soltos. Reforça ADR-009 (paths via env var): `env.sh` per-machine consolida as exports.

**O que NÃO entra no repo.** Runtime files que mudam por uso normal: `plugins/`, `projects/`, `cache/`, `file-history/`, `paste-cache/`, `shell-snapshots/`, `backups/`, `history.jsonl`, `sessions/`, `todos/`, `ide/`, `telemetry/`, `statsig/`, custos diários, `mcp-needs-auth-cache.json`, e o `settings.json` final (regenerado por `merge-settings.sh`). Esses ficam em `~/.claude/` direto, sem symlink, sem git.

**Pegadinha aprendida durante a migração.** `atlas-sync` expande `~`/`$HOME` em runtime para gravar paths absolutos em `~/.claude/.atlas-managed`. Rodar `install.sh` sobre **mount remoto/SMB** (ex.: `/Volumes/gabriel.gripp/...` da Arco vista do laptop pessoal) faz o `$HOME` ser o do laptop — paths gravados ficam inválidos quando a máquina remota é acessada localmente. Solução: rodar `install.sh` **fisicamente na máquina-alvo**. README do `dotfiles-ai` documenta isso explicitamente.

**Consequências.**
- Pró: nova máquina entra com `git clone` + `./install.sh --machine <m>` e em ~30s tem ferramental idêntico (commands, agents, statusline, hooks).
- Pró: edits em qualquer máquina batem direto no repo (symlink) — `git push` distribui.
- Pró: `_index` de scopes (REGISTRY) explicitamente per-machine, sem heurística mágica.
- Pró: `settings.json` final é derivado e nunca commitado — divergências locais (testes, plugins experimentais) não viram conflito de merge.
- Contra: dois lugares pra olhar (`base` + `overlay`) ao tunar settings. Mitigado pelo `merge-settings.sh --dry-run` (jq -s deep-merge produz preview).
- Contra: drift de `~/.claude/.atlas-managed` precisa de `atlas-sync` per-machine — não é resolvido por `git pull` no `dotfiles-ai`. `install.sh` chama `atlas-sync` no fim pra fechar o loop.
- Reversão: `dotfiles-ai/uninstall.sh` (TODO) removeria os symlinks; ou manualmente, `cat ~/.claude/.atlas-managed | xargs rm` + `find ~/.claude -maxdepth 2 -type l -lname '*dotfiles-ai*' -delete`.

**Repos relacionados.**
- `git@github.com:grippado/dotfiles-ai.git` — esta arquitetura
- `git@github.com:grippado/ai-memory-sync.git` — hooks `Stop`/`SessionStart` referenciados pelo `settings.base.json`. Clone obrigatório em cada máquina (em `$HOME/.ai-memory-sync`).
- `git@github.com:grippado/notes.git` — vault Obsidian (`$NOTES_VAULT`).

---

## 7. Plano de execução

| Fase | Status | Resumo |
|---|---|---|
| 0 | ✅ feita | Infra: REGISTRY, atlas-sync, atlas-snapshot, baseline, este doc |
| 1 | ✅ feita | Dotfiles arquivado. `flagbridge/qa.md` apagado. 6 overrides isaac validados como SHARED-DEBT. |
| 2 | ⏭ pulada | Sem trabalho real após escopo reduzido — nenhum artefato pessoal candidato a promoção. |
| 3 | ✅ feita | 26 symlinks `verbo:scope.md` + 1 alias (`organize`). 5 symlinks órfãos da Fase 1 materializados. |

**Fase 4 não existe** — catálogo auto-gerado e cwd-detection viraram itens em §9 (Evolução prevista), implementáveis quando a fricção for real.

---

### ✅ Refatoração + portabilidade concluídas em 2026-04-30

Validação end-to-end via `/organize` em ambiente real, com `$NOTES_VAULT` exportada. Run completa documentada em `notes/6-audits/2026-04-30-{1324,1333}-organize-run{,-pt2}.md`. Vault commitado em 2 fatias correspondentes às runs (pt1 + pt2). Hold 2 fechado: escape `\|` em wikilinks validado como sintaxe Obsidian válida via inspeção visual em `HOME.md` (6 ocorrências renderizando corretamente).

Atlas refatoração: **encerrada**.

### Fase 1 — resultado final

| Ação | Status | Notas |
|---|---|---|
| Arquivar `~/.dotfiles/claude/` | ✅ | renomeado para `~/.dotfiles/_archive_claude_2026-04-30/` |
| Cron `atlas-snapshot` instalado | ✅ | `0 9 * * *` |
| Backup `fase1-overrides-pre.patch` | ✅ | 390 linhas, todos os 7 pares |
| Diff `qa.md` global vs flagbridge | ✅ | idênticos (exit 0) |
| Deletar `flagbridge/qa.md` | ✅ | personal scope, OK escrever |
| Reverter 2 edições isaac feitas antes da política shared | ✅ | backoffice/code-reviewer.md + rf-monorepo/code-reviewer.md voltaram ao original |
| 6 overrides isaac (3× code-reviewer, 3× test-writer) | observados | shared scope (ADR-006), registrados em §8 SHARED-DEBT |

### Cron (não instalado ainda — instalar manualmente)

```bash
(crontab -l 2>/dev/null; echo "0 9 * * * $HOME/.claude/bin/atlas-snapshot") | crontab -
```

Roda 09:00 todo dia. Snapshot em `~/.claude/atlas-history/YYYY-MM-DD.txt`. Resumo em `CHANGES.log`. Mantém só os últimos 90 dias.

---

## 8. SHARED-DEBT — observado, não atuado

Coisas que o `claude-atlas check` reporta como HIGH/MEDIUM mas que **não são problema do Atlas pessoal**. São dívida dos repos compartilhados (ADR-006: scopes shared são read-only). Registro pra: (a) `atlas-snapshot` continuar reportando sem virar surpresa, (b) ter material caso vire fricção real e eu queira propor PR no time.

### Cluster isaac — agents duplicados em 3 repos

Os 3 repos `~/www/isaac/{backoffice, rf-monorepo, communication-api}` carregam cópias byte-a-byte (ou quase) dos mesmos agents:

- `code-reviewer.md` — backoffice ≡ rf-monorepo (idênticos); communication-api diverge mais (treinado em 50+ PRs, model: opus, rule codes)
- `debugger.md` — backoffice ≡ rf-monorepo; communication-api é "duplicate_semantic" (jaccard=0.96)
- `test-writer.md` — backoffice ≡ rf-monorepo ≡ communication-api (todos idênticos)
- `self-reviewer.md` — backoffice ≡ rf-monorepo (jaccard=1.00)
- `implementation.md`, `pattern-finder.md` — padrões similares de duplicação

**Custo da dívida:** quando alguém atualiza um, os outros 2 ficam stale silenciosamente.

**Por que não atuamos:** ADR-006. Repos do time, decisão de dedup é deles.

**Quando virar fricção real:** abrir RFC propondo `~/www/isaac/.claude/` shared dir (ou plugin compartilhado) e migrar os artefatos comuns pra lá.

### Cluster isaac — skills duplicadas

- `create-pr/SKILL.md` — backoffice ≡ communication-api (jaccard=1.00)
- `linear-ticket-reviewer/SKILL.md` — duplicado entre backoffice + communication-api

Mesma análise dos agents acima.

### Overrides isaac vs global

3× `code-reviewer` + 3× `test-writer` (6 arquivos) override agents de mesmo nome em `~/.claude/agents/`. Divergem semanticamente do global (têm protocolos próprios, leem docs do repo, etc). Atlas reporta como HIGH "overrides".

**Decisão:** observado, mantidos. Não posso documentar com `extends:` no frontmatter porque é shared. Se virar problema (alguém invoca o agent global achando que vai pegar o do repo, ou vice-versa), discutir no time.

### O que esperar do `atlas-snapshot`

CHANGES.log vai continuar mostrando ~22 high issues. **Esperado.** Vou me preocupar quando o número **subir** acima do baseline atual ou quando aparecerem categorias novas.

---

## 9. Evolução prevista (não-roadmap)

Coisas que sei que vão mudar, em ordem aproximada de probabilidade. Nenhuma é compromisso.

- **Feature em claude-atlas: `--exclude PATH` ou `--ignore-symlinks`.** Recupera cobertura de `~/.claude/agents` e dos 7 commands hand-written globais no drift detection (hoje fora por causa do `--no-global`, ADR-007). Vou esbarrar nisso da próxima vez que abrir o repo claude-atlas — não vou agendar separado, é projeto pessoal.
- **Auto-geração do Catálogo.** ADR-005 já antecipa. Trivial, só não fiz ainda.
- **Cwd-detection nos commands repo-específicos.** Banner "rodando dentro de `~/www/personal/X` ✓" ou "rode dentro de `X` pra usar este command". Útil quando esquecer cwd começar a doer.
- **Migração pra Plugins (ADR-001).** Quando: (a) usar esse setup numa segunda máquina e symlinks ficarem chatos de portar; (b) Claude Code lançar features ligadas a plugins que symlinks não cobrem; (c) eu quiser publicar partes do setup.
- **Cross-scope orquestradores.** `/sync` global que itera `sync:*` em sequência. Útil quando ≥2 repos tiverem o mesmo verbo. Hoje só flagbridge tem — não justifica.
- **Drift detection mais rico.** Hoje `atlas-snapshot` só registra contagem. Próximo: diff entre snapshots, alertar issue HIGH novo (não existente no anterior).
- **Watcher automático.** `atlas-sync` rodando via fswatch quando `<repo>/.claude/commands/` mudar. Hoje requer rodar manual ou esperar cron.
- **Suporte a skills/agents no atlas-sync.** Hoje só symlinka commands. Skills são diretórios (`<repo>/.claude/skills/<name>/SKILL.md`); requer lógica diferente.
- **Slug `labor.city` voltar a ter ponto** (ADR-002) se eu testar interativamente e o parser de Claude Code aceitar `.` em command name.

---

## 10. Checklist — máquina nova

Sequência reproduzível pra trazer Atlas pra uma máquina nova (ou recriar do zero). ADR-009 garante que quem esquecer um passo descobre na primeira invocação que falhar.

### 1. `~/.claude/`

- Quando `~/.claude/` virar git repo: `git clone <url> ~/.claude`.
- Até lá: copiar manualmente da máquina antiga (`rsync -a --exclude='backups' --exclude='paste-cache' --exclude='history.jsonl' --exclude='atlas-history' --exclude='sessions' --exclude='projects' --exclude='todos' --exclude='session-env' antiga:~/.claude/ ~/.claude/`).
- Garantir que `~/.claude/bin/atlas-sync` e `~/.claude/bin/atlas-snapshot` ficaram com bit de execução: `chmod +x ~/.claude/bin/atlas-*`.

### 2. Repos pessoais

Clonar nos paths que o `REGISTRY.json` espera, ou ajustar o REGISTRY pros paths reais da nova máquina (preferível — REGISTRY existe pra isso).

```bash
git clone git@github.com:grippado/notes.git       ~/.notes
git clone git@github.com:grippado/flagbridge.git  ~/www/personal/flagbridge
git clone git@github.com:grippado/labor.city.git  ~/www/personal/labor.city
git clone git@github.com:grippado/declare-ui.git  ~/www/personal/declare-ui
# shared (se aplicável):
git clone git@github.com:isaac/gravity-design-system.git ~/www/isaac/gravity-design-system
```

Se o layout for diferente (ex: Mac Arco usa `~/www/PROJECTS/central-brain` em vez de `~/.notes`): editar `~/.claude/REGISTRY.json` pra refletir, em vez de recriar a estrutura igual.

### 3. Variáveis de ambiente

No `~/.zshrc` (ou `~/.zshrc_local` machine-specific):

```bash
export NOTES_VAULT="$HOME/.notes"        # MBP
# export NOTES_VAULT="$HOME/www/PROJECTS/central-brain"  # Mac Arco
```

Lista atual de vars necessárias: §5 Catálogo. Se um command falhar com `NOME_DA_VAR not set`, exportar e tentar de novo.

### 4. Cron (drift detection)

```bash
(crontab -l 2>/dev/null; echo "0 9 * * * $HOME/.claude/bin/atlas-snapshot") | crontab -
```

### 5. Aplicar symlinks

```bash
~/.claude/bin/atlas-sync
```

Vai criar `~/.claude/commands/<verbo>:<scope>.md` pra cada command dos repos clonados, mais aliases globais (atual: `organize`).

### 6. Smoke test

Em uma sessão Claude Code interativa:
- `/organize` → deve resolver pra `organize:notes`. Se `$NOTES_VAULT` não estiver setada, vai falhar alto com mensagem clara (comportamento desejado).
- `/sync:flagbridge` (se for máquina onde flagbridge é relevante) → deve dispatchar.

### 7. Baseline

```bash
~/.claude/bin/atlas-snapshot
cat ~/.claude/atlas-history/CHANGES.log
```

Registra o ponto-zero da máquina nova. Se a primeira linha aparecer com contagem **muito** maior que o baseline da máquina antiga, investigar (provavelmente repo extra ou stale).

---

## 11. Quando algo der errado

- **`atlas-sync` falhou com "alias collision":** dois repos marcaram o mesmo verbo como `alias_global`. Mensagem mostra os dois. Remove de um dos dois.
- **`atlas-sync` falhou com "exists as a regular file":** alias quer criar `~/.claude/commands/X.md` mas já tem um arquivo hand-written lá (provavelmente um command global). Decide: rebatiza o command global, ou tira o `alias_global` do scoped.
- **Symlink quebrado em `~/.claude/commands/`:** repo foi movido sem atualizar REGISTRY. `atlas-sync` regenera. `find ~/.claude/commands -type l ! -e {} \;` lista os quebrados.
- **Catálogo divergiu da realidade:** roda `atlas-sync --check`. Se exit 4, regenera com `atlas-sync`.
- **Quero desfazer tudo:** `cat ~/.claude/.atlas-managed | xargs rm`. Pronto, voltou ao estado pré-Fase 0 (preserva commands/agents hand-written em `~/.claude/`, só remove os symlinks gerados).
