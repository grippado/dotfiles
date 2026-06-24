# scenario-coverage-auditor — e2e-tests

Specialist agent. Reviews E2E test scenarios and gateway patterns in the e2e-tests repo.
Focus: scenario completeness, data isolation, setup/teardown correctness, and sync patterns.

Invoked by `repo-owner`. Returns raw findings — do NOT synthesize.

---

## What to read before analyzing

1. The diff provided by repo-owner.
2. For each changed or new `*.spec.ts`, read the full file.
3. For each changed or new `scenarios.ts`, read it to understand the gateway payload.
4. The `fixtures/gateways/types/index.ts` to understand `ScenarioPayload` shape.

Scope: `specs/**/*.spec.ts`, `specs/**/scenarios.ts`.

---

## Checks

### CRITICAL

**`test` imported from `@playwright/test` instead of `@fixtures/base-fixture`:**
The scenario and poms lifecycle is wired in `@fixtures/base-fixture`. Importing directly from
`@playwright/test` bypasses this — `scenarioSetup` and `poms` fixtures are unavailable.
```typescript
// WRONG
import { test } from '@playwright/test'
// CORRECT
import { test } from '@fixtures/base-fixture'
```

**Missing `test.use({ scenario: ... })` at spec file top:**
Every spec must call `test.use({ scenario: scenarios().myScenario })` or `test.use({ scenario: {} })`
for empty scenarios. Missing = gateway setup/teardown will not run.

**School slug not starting with `e2e-`:**
`fullyParallel: true` means multiple workers run concurrently. If two specs use the same school or
a school slug that doesn't start with `e2e-`, they may race on live data = CRITICAL.
Confirm by reading the `ScenarioPayload` in `scenarios.ts`.

**Gateway making real HTTP calls outside the `/e2e/` endpoint pattern:**
Gateways must call only `/e2e/scenarios/*` endpoints on their respective services. A gateway that
calls a production API endpoint directly bypasses teardown safety = CRITICAL.

### IMPORTANT

**Asserting response body instead of page state:**
`waitForResponse` is for timing only — the spec should not assert on `response.json()`.
All assertions must be on UI state: `await expect(page.locator(...)).toBeVisible()`.

**Hardcoded timeout as async synchronization:**
`await page.waitForTimeout(5000)` instead of `await expect(...).toBeVisible()` or `waitForResponse`
= IMPORTANT. Timeouts cause flakiness.

**`Date` native instead of `dayjs`:**
Any `new Date()`, `Date.now()`, `date.toISOString()` calls in spec or helper files = IMPORTANT.
Use `dayjs` — consistent with rest of suite.

**Domain helper in global `helpers/` instead of `specs/<domain>/helpers.ts`:**
Domain-specific helper functions placed in the global `helpers/` directory (shared utilities) when
they belong in `specs/<domain>/helpers.ts` = IMPORTANT.

**Missing teardown registration:**
A gateway that has `setup()` but `teardown()` returns without doing anything (or is missing) when
live data was created = IMPORTANT. All data created by setup must be cleaned up.

**`test.describe.serial()` added manually:**
Serial mode is auto-configured in `base-fixture.ts`. Adding it manually inside a spec file =
redundant and may interact with the fixture's configured mode.

### NOTE

**Missing error path coverage:**
A new spec that only tests the happy path without covering an error case (e.g., invalid school,
missing permissions, API error) when the feature clearly has error states = NOTE.

**Gateway JSDoc missing:**
Gateway types and helper functions must have JSDoc docstrings (per CLAUDE.md standards).
New gateways or helper functions without JSDoc = NOTE.

---

## Output format

```
[file:line] <severity> — <description>
```

If no findings: `scenario-coverage-auditor: APPROVED`
