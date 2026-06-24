# AGENT.md — backoffice

Agent index for the backoffice repo. For the canonical specification this system follows,
see ../AGENT_SPEC.md.

## Repo identity

- **Slug:** `backoffice` (output of `gh repo view --json name -q .name`)
- **Stack:** React 19 + Vite + Turborepo + TypeScript strict + TanStack Query + React Hook Form/Zod
- **Architecture:** Feature-Slice Monorepo. Phase 2 migration: legacy in `apps/main/src/`, new code
  in `modules/<module>/src/`. Communication via Backoffice BFF at `REACT_APP_BFF_API_URL`.

## Agents

| Agent | File | Domain |
|-------|------|--------|
| repo-owner | `repo-owner.md` | Orchestrator — mandatory, always first |
| component-auditor | `component-auditor.md` | React component patterns, Gravity DS usage, module isolation |
| hook-service-reviewer | `hook-service-reviewer.md` | Hook structure, service layer, React Query patterns |

## Dependency graph

```
Phase 1 — parallel (all independent):
  ┌──────────────────────┐
  │ component-auditor    │
  │ hook-service-reviewer│
  └──────────────────────┘

Phase 2 — synthesis:
  repo-owner (collects, deduplicates, classifies)
```

Both specialists are independent — neither needs the other's output to make correct decisions.
The repo-owner runs synthesis after both return.

## Commands

| Command | Purpose |
|---------|---------|
| `pnpm test` | All unit tests via Vitest + Turborepo |
| `pnpm lint` | ESLint on all packages |
| `pnpm type-check` | TypeScript strict check |
| `pnpm build` | Production build |
| `pnpm create:module` | Scaffold a new feature module |

## Key context files

Read these in Step 0 (repo-owner loads all before delegating):

- `CLAUDE.md` — overview, data flow, tech stack, coding standards summary
- `.claude/docs/architecture.md` — full directory tree, module breakdown, pitfalls
- `.claude/docs/coding-standards.md` — ESLint rules, naming, forbidden patterns
- `.claude/rules/hooks-and-services.md` — hook structure, service conventions
- `.claude/rules/react-patterns.md` — useEffect restrictions, dialog patterns, perf
- `.claude/rules/testing.md` — Vitest + RTL standards
- `.claude/rules/gravity-components.md` — @gravity/* registration pitfall

## Known pitfalls (real bugs caught in code)

1. `@gravity/*` added to module but not to `apps/main/package.json` → broken Tailwind CSS in
   production (classes not scanned). Every `@gravity/*` dep must appear in BOTH locations.
2. Services called directly from components (forbidden — only from hooks).
3. `useEffect` used for data fetching instead of `useQuery`.
4. Missing `forwardRef` pattern (but note: React 19 — pass `ref` as prop directly, no `forwardRef`).
5. `interface` instead of `type` — ESLint warning; project uses `type`.
6. `React.FC` — forbidden.
7. Non-null assertions (`!`) — forbidden in this codebase.
8. `any` without comment — forbidden.
