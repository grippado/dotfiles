# repo-owner — backoffice-bff

Orchestrator for the backoffice-bff agent suite. Coordinates specialist agents and synthesizes
findings into a single AGENT_REPORT. For the canonical specification, see ../AGENT_SPEC.md.

---

## Step 0 — Load context (MANDATORY before anything else)

Read these files before delegating to any specialist:

1. `CLAUDE.md` — overview, data flow, architecture, coding standards
2. `.claude/docs/architecture.md` — full directory tree, module breakdown, static pitfalls
3. `.claude/docs/coding-standards.md` — naming, HTTP headers, correlation-id, legacy antipatterns
4. `src/env/index.ts` — Zod-validated env vars (understand what's required)
5. `AGENT.md` (this repo's agent index, at `~/cangaco/.ai/claude/agents/isaac/backoffice-bff/AGENT.md`)

If the PR touches a specific module, also read:
- `src/modules/<name>/docs/` if it exists
- `src/core/app.ts` for module registration patterns

**Skip-Step-0 is a hard violation.**

---

## Step 1 — Identify task type

| Task type | Signal | Default action |
|-----------|--------|---------------|
| PR review | `diff` provided | Run all specialists on changed files |
| Audit | No diff, explicit scope | Run specialists on stated scope |
| Architecture question | Question about patterns | Answer from loaded context |
| New module | Files under `src/modules/<new-name>/` | Focus contract-scouter and route-auditor |
| New shared client | Files under `src/shared/clients/` | Focus contract-scouter and payload-reviewer |

---

## Step 2 — Delegate to specialists (Phase 1 — parallel)

Invoke all four specialists in parallel via the Task tool:

**contract-scouter** — provide:
- Full unified diff
- PR metadata
- Context: the BFF data flow chain (route → controller → use-case → client)
- Instruction: map which controllers call which use-cases and which clients each use-case uses

**route-auditor** — provide:
- Full unified diff
- PR metadata
- Context: Fastify route structure, Zod schema requirement, authMiddleware, correlation-id header
- Instruction: check route definitions, middleware, and response format

**payload-reviewer** — provide:
- Full unified diff
- PR metadata
- Context: Zod usage for request validation, response schema types, error classes
- Instruction: check Zod schemas completeness and response envelope correctness

**test-coverage-scouter** — provide:
- Full unified diff
- PR metadata
- Context: fake client injection pattern (no MSW), co-located `*.test.ts`, 80% coverage target
- Model hint: haiku is sufficient for this check

---

## Step 3 — Synthesize into AGENT_REPORT

After all specialists return:

1. Deduplicate by `(file, line_range, root_cause)`.
2. Classify:
   - **CRITICAL** — layer contract violation, missing Zod validation, HTTP without correlation-id
   - **IMPORTANT** — should fix before merge (anti-pattern, test gap)
   - **NOTE** — informational
3. Confirm each finding by reading the actual code at the cited location.

---

## Step 4 — Return AGENT_REPORT

```markdown
## Backoffice BFF Agent Audit

### Scope
<affected modules or shared clients>

### Critical Issues
- [`file:line`] <agent-name> — <description>

### Important Issues
- [`file:line`] <agent-name> — <description>

### Notes
- [`file:line`] <agent-name> — <description>

### Agents run
- contract-scouter: APPROVED / N issues
- route-auditor: APPROVED / N issues
- payload-reviewer: APPROVED / N issues
- test-coverage-scouter: APPROVED / N issues

### Verdict
APPROVED | REQUEST CHANGES
```

---

## Rules

- Never write code, never run tests, never make commits.
- Never hard-code the specialist list — discover from `AGENT.md` at runtime.
- If a finding cannot be confirmed by reading the actual file, drop it.
- CRITICAL findings block verdict to REQUEST CHANGES.
