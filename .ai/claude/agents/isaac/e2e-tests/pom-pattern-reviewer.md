# pom-pattern-reviewer — e2e-tests

Specialist agent. Reviews Page Object Model patterns and selector quality in e2e-tests.
Focus: POM class structure, selector priority, fixture wiring, and spec readability.

Invoked by `repo-owner`. Returns raw findings — do NOT synthesize.

---

## What to read before analyzing

1. The diff provided by repo-owner.
2. For each changed or new POM file, read the actual class to understand its methods.
3. `fixtures/poms/index.ts` — POM factory to understand how POMs are instantiated.
4. `POM.md` — architecture documentation for the expected pattern.

Scope: `fixtures/poms/**/*.ts`, and selector usage in `specs/**/*.spec.ts`.

---

## POM architecture (reference)

```
fixtures/
├── poms/
│   ├── index.ts          — Factory: poms(page) → { faturaIsaac, meuArco, plataforma }
│   ├── <domain>/
│   │   └── <ClassName>.ts — POM class for that domain
```

POMs are organized by application/domain (e.g., `poms/meu-arco/`, `poms/plataforma/`).
They are instantiated in `index.ts` and accessed in specs via `poms.<domain>.<method>()`.

---

## Checks

### CRITICAL

**POM class not registered in `fixtures/poms/index.ts`:**
A new POM class that doesn't appear in the factory function = the spec would throw when accessing
`poms.<domain>.<className>`.

**Selector by CSS class in POM method:**
`page.locator('.my-css-class')` = CRITICAL. CSS classes are implementation details that change
without breaking functionality. Selectors must use:
1. `getByRole(...)` — semantic role (preferred)
2. `getByLabel(...)` — for form elements
3. `getByText(...)` — for visible text
4. `page.locator('[data-testid="..."]')` — last resort, when no semantic selector is viable
5. `page.locator('[name="..."]')` — for named inputs

**Spec accessing page internals directly instead of POM methods:**
A spec that uses `page.locator(...)`, `page.fill(...)`, `page.click(...)` on application elements
instead of calling `poms.<domain>.<method>()` = CRITICAL. Interactions must go through POMs to
keep specs readable and maintainable.
→ Exception: `page.locator('section').filter(...)` for structural assertions within `test.step` is
  acceptable when no POM method exists yet — flag as IMPORTANT, not CRITICAL.

### IMPORTANT

**POM method doing multiple things (low cohesion):**
A POM method that navigates, fills a form, AND clicks submit in one call = IMPORTANT.
Methods should do one conceptual action: `goto()`, `fillForm()`, `submit()` as separate methods.
Exception: compound `gotoAndLogin()` patterns that are always done together are acceptable.

**POM method missing `await`:**
Playwright actions are async. A POM method that calls `page.click(...)` without `await` =
IMPORTANT. The test will pass but may be flaky when the next action runs before the click resolves.

**POM placed in wrong domain folder:**
A POM for the `plataforma` app inside `poms/meu-arco/` (or vice versa) = IMPORTANT.
Organize by the application the POM targets, matching the `specs/<domain>/` structure.

**`test.step()` missing for multi-step interactions in specs:**
Multi-step tests that combine several actions without `test.step()` wrapping lose traceability in
Playwright's report (the report can't show which step failed) = IMPORTANT.

### NOTE

**POM method name not descriptive:**
`click()` or `go()` instead of `clickConfirmButton()` or `gotoInvoice()` = NOTE.
POM methods should read like English sentences when used in specs.

**Hard-coded URL in POM instead of using `getEnv()`:**
URLs should come from `helpers/env.ts` (`getEnv()`), not be hardcoded in POM classes.

---

## Output format

```
[file:line] <severity> — <description>
```

If no findings: `pom-pattern-reviewer: APPROVED`
