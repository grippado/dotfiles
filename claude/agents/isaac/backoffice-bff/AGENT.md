# AGENT.md — backoffice-bff

Agent index for the backoffice-bff repo. For the canonical specification this system follows,
see ../AGENT_SPEC.md.

## Repo identity

- **Slug:** `backoffice-bff` (output of `gh repo view --json name -q .name`)
- **Stack:** Node.js 22.19.0, Fastify 5, tRPC 11, Zod, Vitest, TSUP, TypeScript strict
- **Architecture:** Modular BFF with layered Clean Architecture per module.
  Pattern: `Route → Controller → Use Case → Client → External Service`
  Shared clients in `src/shared/clients/` (payment-api, classapp, edwiges, matriculas-api, etc.)

## Agents

| Agent | File | Domain |
|-------|------|--------|
| repo-owner | `repo-owner.md` | Orchestrator — mandatory, always first |
| contract-scouter | `contract-scouter.md` | Layer contract enforcement (route→controller→use-case→client) |
| route-auditor | `route-auditor.md` | Fastify routes, Zod validation, middleware chain, correlation-id |
| payload-reviewer | `payload-reviewer.md` | Zod schemas, response shapes, error types |
| test-coverage-scouter | `test-coverage-scouter.md` | Test coverage, fake client usage, Vitest patterns |

## Dependency graph

```
Phase 1 — parallel (all independent reads):
  ┌──────────────────────┐
  │ contract-scouter     │ ─────────────────────────────────────────┐
  │ route-auditor        │                                          │
  │ payload-reviewer     │                                          │
  │ test-coverage-scouter│                                          ▼
  └──────────────────────┘             Phase 2 — sequential (optional):
                                       If contract-scouter finds cross-layer
                                       violations, repo-owner may ask it to
                                       verify which clients are misrouted.
```

## Commands

| Command | Purpose |
|---------|---------|
| `pnpm test:ci` | Coverage mode (80% target, CI) |
| `pnpm typecheck` | TypeScript strict check |
| `pnpm lint` | ESLint (no auto-fix — what CI runs) |
| `pnpm lint:changed` | Auto-fix only changed files vs origin/main |
| `make build` | Production build (TSUP/ESBuild) |

## Key context files

- `CLAUDE.md` — overview, data flow, coding standards summary
- `.claude/docs/architecture.md` — full directory tree, module breakdown, static pitfalls
- `.claude/docs/coding-standards.md` — naming, HTTP headers, legacy antipatterns, correlation-id
- `src/env/index.ts` — Zod-validated env vars

## Known pitfalls (from real code reading)

1. Use cases importing Fastify types directly (forbidden — use cases must be HTTP-agnostic).
2. Controllers doing business logic instead of delegating to use cases.
3. Routes missing Zod input validation schema.
4. Shared clients in `src/shared/clients/` missing `x-correlation-id` header.
5. Feature flags accessed via `fastify.unleash.isEnabled('flag-string')` with hardcoded string
   instead of a constant — makes flag names untrackable.
6. Test files using real HTTP calls instead of fake client implementations (e.g., `FakePaymentApiClient`).
7. `console.log` instead of Pino logger — forbidden.
8. tRPC module (`src/modules/communication/trpc/`) mixing HTTP and tRPC patterns incorrectly.
