# AGENT.md — rf-monorepo

Agent index for the rf-monorepo. For the canonical specification this system follows,
see ../AGENT_SPEC.md.

## Repo identity

- **Slug:** `rf-monorepo` (output of `gh repo view --json name -q .name`)
- **Stack:** Node 22, pnpm 9.6, Turborepo, Next.js 16 (App Router), React 19, TypeScript strict,
  tRPC 11, Zod, Tailwind, Vitest, next-intl
- **Architecture:** 11 Next.js apps + 6 live domain modules + 12 shared packages.
  Each app has its own tRPC BFF layer. External calls go through `packages/api/clients/[service]/`.

## Agents

| Agent | File | Domain |
|-------|------|--------|
| repo-owner | `repo-owner.md` | Orchestrator — mandatory, always first |
| trpc-auditor | `trpc-auditor.md` | tRPC procedure patterns, input validation, implement<T>(), userProcedure, ctx guard, observabilityTargets |
| module-boundary-auditor | `module-boundary-auditor.md` | ESLint boundaries, cross-module imports, import aliases, DynamicAppSkeleton, CODEOWNERS |
| env-auditor | `env-auditor.md` | createEnv pattern, runtimeEnv completeness, turbo.json globalEnv, NEXT_PUBLIC_ prefix rules |

## Dependency graph

```
Phase 1 — parallel (all independent):
  ┌───────────────────────────┐
  │ trpc-auditor              │
  │ module-boundary-auditor   │
  │ env-auditor               │  ← run when env.ts/keys.ts changes detected
  └───────────────────────────┘

Phase 2 — synthesis:
  repo-owner (collects, deduplicates, classifies)
```

All specialists read disjoint layers and can run fully in parallel.
repo-owner dispatches env-auditor selectively when env.ts or keys.ts files are in the diff.

## Commands

| Command | Purpose |
|---------|---------|
| `pnpm test` | All unit tests (run once, exit) |
| `pnpm lint` | Lint all packages |
| `pnpm typecheck` | TypeScript strict check |
| `pnpm graphql:codegen` | Regenerate Joy GraphQL types |
| `pnpm create:module` | Scaffold a new domain module |

## Key context files

- `CLAUDE.md` — overview, data flow, critical rules, common pitfalls
- `.claude/docs/architecture-overview.md` — full directory tree, per-app structure, all pitfalls
- `.claude/docs/coding-standards.md` — ESLint rules, import aliases, TypeScript strictness
- `.claude/rules/trpc-patterns.md` — tRPC procedure patterns, implement<T>(), userProcedure
- `.claude/rules/modular-architecture.md` — module boundaries, flat vs feature-based, gotchas
- `.claude/rules/i18n.md` — next-intl patterns, dictionary registration
- `.claude/rules/react-patterns.md` — index.tsx/View.tsx split, useEffect restrictions
- `apps/home/CLAUDE.md` — home app reference (largest router surface)

## Known pitfalls (from real code reading)

1. Missing `.input(zodSchema)` on tRPC procedures — hard ESLint error, CI fails.
2. `console.*` instead of `logger` from `@monorepo/observability/logger` — hard ESLint error.
3. Wrong import alias: `@monorepo/*` inside an app (should be `@src/*`); or `@src/*` inside a
   package (should be `@root[Package]/*`).
4. Module importing from another module or from `apps/` — ESLint boundaries rule violation.
5. Business logic inside tRPC procedures instead of delegating to `packages/api/clients/`.
6. Domain types declared next to the API client — shared types go in `@monorepo/interfaces/<domain>`.
7. `^` caret ranges in `package.json` — ESLint error; pin exact versions or use `catalog:`.
8. Hardcoded user-visible strings — should use `useTranslations` + `pt-br.json`.
9. New module not registered in `observabilityTargets.ts` after adding a tRPC namespace.
10. `interface` instead of `type` — ESLint warning.
11. `trpcServer` imported inside a module — breaks app-dependency boundary.
