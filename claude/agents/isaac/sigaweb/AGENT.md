# AGENT.md — sigaweb

Agent index for the sigaweb repo. For the canonical specification this system follows,
see ../AGENT_SPEC.md.

## Repo identity

- **Slug:** `sigaweb` (output of `gh repo view --json name -q .name`)
- **Owner:** `activesoft-consultoria/sigaweb`
- **Stack:** Django 4 + DRF + SQL Server (backend) + React 16.14 + TypeScript 4.4 + Webpack 5 (frontend)
- **Frontend architecture:** Multi-module monolith. Feature pages under `assets/frontend/<module>/`.
  Shared code in `assets/core/` (hooks, helpers, contexts) and `assets/components/` (reusable UI).
  State management: Recoil (primary, new code) + Redux (legacy). Forms: Formik + Yup.
  HTTP: Axios. React Query v4 for data fetching in new code. UI: Gravity DS + styled-components +
  Bootstrap (legacy CSS coexists).

## Agents

| Agent | File | Domain |
|-------|------|--------|
| repo-owner | `repo-owner.md` | Orchestrator — mandatory, always first |
| styling-auditor | `styling-auditor.md` | Gravity DS token usage, styled-components patterns, CSS token vs hardcoded color, missing `/css` imports |
| component-auditor | `component-auditor.md` | React component structure, module isolation, prop drilling, Gravity primitive usage |
| react-query-auditor | `react-query-auditor.md` | @tanstack/react-query v4 patterns: query key factories, cache invalidation, stale state |

## Dependency graph

```
Phase 1 — parallel (all independent):
  ┌──────────────────────┐
  │ styling-auditor      │  ← run when styled-components, CSS, or @gravity/* files changed
  │ component-auditor    │  ← run when .tsx component files changed
  │ react-query-auditor  │  ← run when hooks with useQuery/useMutation changed
  └──────────────────────┘

Phase 2 — synthesis:
  repo-owner (collects, deduplicates, classifies)
```

All three specialists are independent — none needs the other's output to make correct decisions.
repo-owner dispatches selectively based on what changed in the diff.

## Commands

| Command | Purpose |
|---------|---------|
| `npm run build` | Production build (Webpack) |
| `npm run build:dev` | Development build |
| `npm run watch` | Watch mode |
| `npm run lint` | Lint all TS/JS files |
| `npm run lint:changed` | Lint only modified files |
| `npm run lint:fix` | Auto-fix lint issues |
| `npm run type-check` | TypeScript type check (strict) |
| `npm run type-check:changed` | Type check modified files only |
| `npm run storybook` | Storybook component explorer |

## Key context files

Read these in Step 0 (repo-owner loads all before delegating):

- `CLAUDE.md` — project overview, architecture summary, Django patterns, frontend stack, commit conventions
- `eslint.config.mjs` — ESLint flat config (typescript-eslint strict, import-x, prettier, jsdoc, standard-react)
- `tsconfig.json` — TypeScript strict mode, path aliases (`@assets`, `@frontend`, `@core`, `@api`, `@ui`, etc.)
- `AGENT.md` (this file, at `~/.dotfiles-ai/claude/agents/isaac/sigaweb/AGENT.md`)

## Known pitfalls (real patterns observed in code)

1. `@gravity/<pkg>` imported in a `.tsx` file without the corresponding `import '@gravity/<pkg>/css'`.
   The package builds CSS separately — each usage site must import the CSS explicitly. Missing
   `@gravity/icons/css` is common (icons have no CSS themselves, but the import is needed when the
   icon package uses CSS custom properties).
2. Hardcoded hex colors (`#fff`, `#000`, `#666666`, `#b42318`) in styled-components where Gravity
   CSS tokens (`hsl(var(--colors-*))`) are available. `BoletimPreviewCard` has real examples.
3. `React.FC` is used throughout (not banned by ESLint in this repo — do not flag it as CRITICAL;
   flag only as NOTE if inconsistent with function return-type style in the same file).
4. `interface` vs `type`: the codebase uses both freely (no ESLint rule banning `interface` here,
   unlike backoffice). Do not flag `interface` as a violation.
5. Module isolation: `@frontend/<module>` imports between modules are allowed (e.g.,
   `@frontend/boletins/components/RadioComConteudo`). The shared boundary is `@assets/core/` and
   `@assets/components/` — do flag any module importing from another module's `atoms/` or `hooks/`.
6. Query key factories: the canonical pattern is a named object (`centralBoletimQueries`) at
   `@assets/api/<domain>/queries.ts`. New code that uses inline arrays instead of the factory = NOTE.
7. Recoil atoms: atom keys must be namespaced (e.g., `'central_boletim/periodo_selecionado'`).
   Unnamespaced keys cause silent collisions at runtime.
