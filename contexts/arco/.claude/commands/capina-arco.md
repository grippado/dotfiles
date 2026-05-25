---
description: "Capina vulnerabilidades de dependências em repos Node do workspace Arco/Isaac (Arco Security Scanner / Trivy)"
---

# /capina-arco

> Como capinar erva daninha: enxada na mão, planta por planta, sem passar trator.

Workflow controlado de upgrade de dependências vulneráveis para repos Node da org (React no front, Node+Fastify no back, monorepos pnpm). **Sempre rodar 1 repo por vez** — esse comando é cirúrgico, não em massa. Não é `pnpm audit --fix` jogando veneno em tudo: é capina seletiva, planejada antes de aplicar.

## Invocação

```
/capina-arco <repo> [--severity=high,critical|medium|low|all] [--sla=blocking|near|backlog|all] [--dry-run] [--no-pr]
```

- `<repo>`: nome do diretório sob `~/www/isaac/` (ex: `rf-monorepo`, `backoffice`, `backoffice-bff`, `communication-api`, `joy`, `gravity-design-system`). Aceita múltiplos separados por espaço, mas processa **sequencialmente** com confirmação humana entre eles.
- `--severity` (default: `high,critical`): filtra advisories por severidade.
- `--sla` (default: `blocking`): `blocking` = passou do SLA; `near` = ≤7 dias pra SLA; `backlog` = vulns antigas que não bloqueiam; `all` = tudo.
- `--dry-run`: só lista o que faria, não modifica nada.
- `--no-pr`: aplica commits localmente mas não abre PR.

## Pré-condições

Antes de qualquer ação:

1. `cd ~/www/isaac/<repo>` e confirmar que `pnpm-lock.yaml` existe na raiz.
2. `git status` limpo. Se houver mudanças pendentes, **abortar** e avisar o usuário.
3. Ler o `CLAUDE.md` do repo (cada um tem convenções próprias — rf-monorepo, backoffice, communication-api e gravity-design-system têm regras específicas).
4. Determinar branch base correta (`main` ou `master` — checar via `git symbolic-ref refs/remotes/origin/HEAD`).
5. Criar branch nova: `chore/sec-deps-$(date +%Y%m%d)` a partir da branch base atualizada.

## Fluxo

### 1. Delegar coleta + planejamento ao `capina-executor`

Spawn agent `capina-executor` (Sonnet) com:
- `repo`, flags `severity`/`sla`/`dry_run`
- Branch base correta (calculada acima)
- Caminho do worktree/branch criada

Ele devolve:
- Tabela do plano (pkg, severity, current → target, tipo, workspace, estratégia, major?)
- Lista de vulns deferred + motivo
- Lista de `awaiting upstream fix`
- Lista de **major bumps detectados** (flag `is_major: true`)

### 2. Apresentar plano + tratar major bumps

**Sempre** apresentar o plano ao usuário antes de aplicar (mesmo sem `--dry-run`):
- Tabela completa do que o `capina-executor` retornou
- Destaque visual pros major bumps

Para cada major bump detectado, **antes** de aplicar:

1. Spawn agent `node-deps-doctor` (Sonnet) em paralelo (1 invocação por major bump, ou batch se múltiplos no mesmo pacote)
2. Doctor devolve veredito: 🟢 APPLY / 🟡 PATCH / 🔴 DEFER + comandos sugeridos
3. Consolidar vereditos no plano e re-apresentar ao usuário com a recomendação do especialista
4. Pedir confirmação humana explícita pra cada major bump

Se `--dry-run`: parar aqui.

### 3. Aplicar mudanças (delegado ao `capina-executor`)

Após confirmação humana, re-invocar `capina-executor` em modo apply:
- Aplica updates diretas (`pnpm update`)
- Edita `pnpm.overrides` no `package.json` raiz preservando existentes
- Roda `pnpm install`
- Roda verificações best-effort (typecheck, lint quando rápido — tests só em gravity-design-system por default)

Se `pnpm install` falhar ou typecheck quebrar: invocar `node-deps-doctor` com `case=install_failure` ou `case=typecheck_failure` pra diagnóstico. Apresentar veredito ao usuário antes de continuar.

### 4. Commit + PR (delegação obrigatória)

Spawnar em **paralelo** após o `pnpm install` ter sucesso:

1. **`doc-writer`** — gerar PR description com:
   - Tabela de advisories corrigidos (severity, package, current → new, CVE/GHSA refs se possível)
   - Tabela de advisories deferred (com motivo)
   - Nota sobre overrides aplicados (se houver)
   - Resultado das verificações locais (typecheck/lint/test)
   - Checklist pro reviewer: rodar app, smoke test, conferir behavior de major bumps

2. **`git-assistant`** — preparar commit message Conventional Commits:
   - Formato sugerido: `chore(deps): bump vulnerable packages to meet security SLA`
   - Body listando packages atualizados e overrides adicionados
   - **OBRIGATÓRIO** trailer `Co-Authored-By: Claude <noreply@anthropic.com>` (regra inegociável global)

3. **`memory-extractor`** — salvar decisões não-óbvias (ex: "axios mantido em 0.21.x porque app X tem código incompatível com 1.x", ou "override de protobufjs evitado por quebrar runtime gRPC do joy").

Após subagents completarem:
- Commit via HEREDOC com o trailer Claude.
- Se `--no-pr` não passada: `gh pr create` com title curto (`chore(deps): security bump (SLA)`) e body do doc-writer.

### 5. Pós-PR

- Imprimir URL do PR.
- Lembrar que o **Arco Security Scanner é check informativo** (não bloqueia merge), mas HIGH/CRITICAL fora do SLA fazem o pipeline falhar — então re-rodar o scanner no PR pra confirmar redução de vulns antes de pedir review.

## Regras / guard-rails

- **Não fazer major bumps silenciosamente.** Se a safe-version é major bump (ex: axios 0.21 → 1.x, multer 1.x → 2.x), destacar no plano e exigir confirmação explícita. Major bump em prod-critical (joy, payment-api, communication-api) merece thread separado com o usuário antes de prosseguir.
- **Nunca skipar hooks** (`--no-verify`, `--no-gpg-sign`) — regra global.
- **Não usar `pnpm audit --fix`** — controle manual, comando faz seu próprio planning.
- **Não editar `pnpm-lock.yaml` à mão** — sempre via `pnpm install` após mudar `package.json`.
- **Respeitar PT-BR sem em-dash em PR title/body** (regra global de textos externos) — usar vírgula, parênteses ou quebra de frase.
- Se um pacote não tem fix disponível ainda (ex: `quill` no report do usuário com fix vazio), pular e registrar como `awaiting upstream fix`.
- Se o repo tem `.npmrc` com `engine-strict=true` ou `node-version` fixo, respeitar — falhar cedo se safe-version exigir runtime maior.

## Saída final

Após processar o(s) repo(s), apresentar resumo:
- Repo(s) processado(s) e branch criada.
- # de vulns corrigidas / deferidas / aguardando upstream.
- URL(s) do(s) PR(s).
- Próximos passos sugeridos (ex: "rf-monorepo ainda tem 12 vulns MEDIUM no backlog — rodar `/capina-arco rf-monorepo --severity=medium --sla=backlog` quando tiver janela").

## Agents que esse comando orquestra

- **`capina-executor`** (Sonnet): coleta, classifica, planeja e aplica. Trabalho mecânico.
- **`node-deps-doctor`** (Sonnet): diagnóstica major bumps e quebras de install/typecheck/build. Não modifica arquivos.
- **`doc-writer`** (Sonnet, genérico global): gera PR body.
- **`git-assistant`** (Haiku, genérico global): prepara commit message com trailer Claude.
- **`memory-extractor`** (Haiku, genérico global): persiste decisões não-óbvias.

O main agent (Opus) só orquestra, apresenta planos ao usuário e toma decisões com humano in-the-loop pros casos cinza.
