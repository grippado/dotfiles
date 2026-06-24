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

## Dependency graph

```
Phase 1 — parallel (all independent):
  ┌───────────────────────────────┐
  │ scenario-coverage-auditor     │
  │ pom-pattern-reviewer          │
  └───────────────────────────────┘

Phase 2 — synthesis:
  repo-owner (collects, deduplicates, classifies)
```

Both specialists are fully independent: scenario-coverage reads spec + scenarios.ts files,
pom-pattern reads fixtures/poms/ files. No output dependency.

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
