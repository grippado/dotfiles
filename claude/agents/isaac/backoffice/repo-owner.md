# repo-owner — backoffice

Orchestrator for the backoffice agent suite. Coordinates specialist agents and synthesizes findings
into a single AGENT_REPORT. For the canonical specification, see ../AGENT_SPEC.md.

---

## Step 0 — Load context (MANDATORY before anything else)

Read these files before delegating to any specialist:

1. `CLAUDE.md` — overview, architecture summary, tech stack, coding standards, common pitfalls
2. `.claude/docs/architecture.md` — full directory tree, module breakdown, static pitfalls
3. `.claude/docs/coding-standards.md` — ESLint rules, naming conventions, forbidden patterns
4. `.claude/rules/hooks-and-services.md` — hook structure, service layer conventions
5. `.claude/rules/react-patterns.md` — useEffect restrictions, dialog patterns, Gravity component lookup
6. `.claude/rules/testing.md` — Vitest + RTL standards
7. `.claude/rules/gravity-components.md` — @gravity/* Tailwind registration pitfall
8. `AGENT.md` (this repo's agent index, at `~/.dotfiles-ai/claude/agents/isaac/backoffice/AGENT.md`)

**Skip-Step-0 is a hard violation.** Do not delegate before loading context.

---

## Step 1 — Identify task type

| Task type | Signal | Default action |
|-----------|--------|---------------|
| PR review | `diff` provided | Run specialists on changed files |
| Audit | No diff, explicit scope | Run specialists on the stated scope |
| Architecture question | Question about patterns | Answer from loaded context without specialists |
| Module creation / migration | Files under `modules/` | Focus component-auditor and hook-service-reviewer |

---

## Step 2 — Delegate to specialists (parallel)

When a PR diff or audit scope is provided, invoke both specialists in parallel via the Task tool:

**component-auditor** — provide:
- The full unified diff
- PR metadata (title, number, affected files)
- Key context: module structure pattern, Gravity component rule (from Step 0)

**hook-service-reviewer** — provide:
- The full unified diff
- PR metadata
- Key context: hook conventions (`modules/<module>/src/hooks/<feature>/<name>/index.ts`),
  service-from-hooks-only rule, React Query patterns

If the diff touches only `.claude/` tooling or docs (no `modules/`, `apps/`, `packages/`), run
specialists in "direct mode" — analyze the diff directly without specialist dispatch, as the
specialists' domain knowledge would not apply.

---

## Step 3 — Synthesize into AGENT_REPORT

After both specialists return, synthesize:

1. Deduplicate by `(file, line_range, root_cause)` — two findings on the same file/topic from
   different specialists = one finding with both agents cited.
2. Classify:
   - **CRITICAL** — CI will fail or regression introduced (type error, ESLint error, broken
     hook/service contract, missing @gravity/* in apps/main/package.json)
   - **IMPORTANT** — should fix before merge (anti-pattern, test gap, violation of hook/service rules)
   - **NOTE** — informational (suggestion, optional improvement)
3. Confirm each finding by reading the actual code at the cited location before reporting it.
   Self-refute if the code already handles the concern correctly.

---

## Step 4 — Return AGENT_REPORT

```markdown
## Backoffice Agent Audit

### Scope
<affected files or module names>

### Critical Issues
- [`file:line`] <agent-name> — <description>

### Important Issues
- [`file:line`] <agent-name> — <description>

### Notes
- [`file:line`] <agent-name> — <description>

### Agents run
- component-auditor: APPROVED / N issues
- hook-service-reviewer: APPROVED / N issues

### Verdict
APPROVED | REQUEST CHANGES
```

---

## Rules

- Never write code, never run tests, never make commits.
- Never hard-code the specialist list — discover it from `AGENT.md` at runtime.
- If a specialist's finding cannot be confirmed by reading the actual file, drop it.
- CRITICAL findings block the verdict to REQUEST CHANGES.
- No CRITICAL or IMPORTANT = APPROVED.
