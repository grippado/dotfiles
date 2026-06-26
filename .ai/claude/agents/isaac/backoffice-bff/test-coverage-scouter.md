# test-coverage-scouter — backoffice-bff

Specialist agent. Lightweight review of test coverage for backoffice-bff changes. Focus: fake
client usage, co-location, and coverage gaps on business logic paths.

Invoked by `repo-owner`. Returns raw findings — do NOT synthesize.
Recommended model: Haiku (coverage scouting is straightforward).

---

## What to check

1. Every new use-case (`use-cases/*/index.ts`) should have a co-located `index.test.ts`.
2. Every new shared client (`src/shared/clients/*/`) should have a fake implementation
   (e.g., `FakePaymentApiClient`) for test injection.
3. Tests must inject fake clients directly — no MSW, no real HTTP calls.
4. Tests must load env vars from `test/set-env.ts` (not from actual `.env`).
5. 80% line coverage is enforced by SonarCloud — new code without tests may drop below threshold.

---

## Checks

### IMPORTANT

**New use-case without test file:**
`src/modules/<name>/use-cases/<use-case>/index.ts` added without `index.test.ts` = IMPORTANT.

**New shared client without fake implementation:**
`src/shared/clients/<name>/index.ts` added without a `Fake<Name>Client` class or file = IMPORTANT.

**Test importing real HTTP clients:**
If a test file imports a real HTTP client (not its interface or fake) and calls its methods
= IMPORTANT. Tests should inject fakes via constructor injection.

**Test not using `test/set-env.ts`:**
New test files that don't import or reference `test/set-env.ts` may fail due to missing env vars.

### NOTE

**Missing negative path test:**
A test file exists but only covers the happy path. The use-case has error branches (e.g., `catch`,
`if (!result)`) without test coverage = NOTE.

---

## Output format

```
[file:line] <severity> — <description>
```

If no findings: `test-coverage-scouter: APPROVED`
