# AGENT.md — e2e-tests

Agent index for the e2e-tests repo. For the canonical specification this system follows,
see ../AGENT_SPEC.md.

## Repo identity

- **Slug:** `e2e-tests` (output of `gh repo view --json name -q .name`)
- **Stack:** Playwright, TypeScript, Biome (lint/format), pnpm
- **Architecture:** Scenario-driven Gateway Architecture.
  Each test declares a `ScenarioPayload` → `base-fixture.ts` calls gateways (setup/teardown via
  `/e2e/` endpoints on real backends). No mocks. POMs in `fixtures/poms/`.

## Agents

| Agent | File | Domain |
|-------|------|--------|
| repo-owner | `repo-owner.md` | Orchestrator — mandatory, always first |
| scenario-coverage-auditor | `scenario-coverage-auditor.md` | Scenario completeness, happy+error paths, flakiness patterns |
| pom-pattern-reviewer | `pom-pattern-reviewer.md` | Page Object Model usage, selector quality, fixture patterns |
| e2e-pma-planejador | `e2e-pma-planejador.md` | Explore PMA flow via Playwright MCP; produce PLANEJAMENTO.md ready for implementation |
| e2e-pma-implementador | `e2e-pma-implementador.md` | Implement scenarios.ts + .spec.ts from a PLANEJAMENTO.md |
| e2e-pma-validador | `e2e-pma-validador.md` | Run, diagnose, and iteratively fix a PMA spec until it passes |

## Dependency graph

```
PR review flow — parallel:
  ┌───────────────────────────────┐
  │ scenario-coverage-auditor     │
  │ pom-pattern-reviewer          │
  └───────────────────────────────┘

PMA test creation flow — sequential (user-initiated):
  e2e-pma-planejador → e2e-pma-implementador → e2e-pma-validador
```

PR review: both auditors run in parallel (disjoint file sets).
PMA creation: the three agents run in strict sequence — each receives prior agent's output.

## Commands

| Command | Purpose |
|---------|---------|
| `pnpm test` | Run all E2E tests (against real backends) |
| `pnpm lint` / `pnpm lint:fix` | Biome lint |
| `pnpm format` / `pnpm format:fix` | Biome format |
| `pnpm manual-teardown -- --school-id <uuid>` | ⚠️ destroys live data |

## Key context files

- `CLAUDE.md` — architecture, standards, file conventions, CI
- `POM.md` — Page Object Model documentation
- `fixtures/base-fixture.ts` — fixture entry point
- `fixtures/gateways/types/index.ts` — `ScenarioPayload`, `GatewayNames`, `GatewayPayloads`
- `fixtures/poms/index.ts` — POM factory

## Known pitfalls (from real code reading)

1. Importing `test` from `@playwright/test` instead of `@fixtures/base-fixture` — critical,
   breaks the scenario setup lifecycle.
2. Missing `test.use({ scenario: ... })` at the top of a spec file.
3. School slug not starting with `e2e-` — causes data races with `fullyParallel: true`.
4. Adding `test.describe.serial()` manually — serial mode is auto-configured in base fixture.
5. Asserting response body instead of page state (`waitForResponse` only for timing; assert via
   `expect(...).toBeVisible()`, never JSON-parse the response).
6. Locating elements by CSS class instead of role/label/`data-testid`.
7. Using `Date` native instead of `dayjs`.
8. Domain-specific helpers in global `helpers/` instead of `specs/<domain>/helpers.ts`.
9. Gateways missing JSDoc docstrings.
10. Tests sharing the same school slug across suites (data races).
