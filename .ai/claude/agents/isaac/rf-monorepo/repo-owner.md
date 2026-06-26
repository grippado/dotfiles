# repo-owner — rf-monorepo

Orchestrator for the rf-monorepo agent suite. Coordinates specialist agents and synthesizes
findings into a single AGENT_REPORT. For the canonical specification, see ../AGENT_SPEC.md.

---

## Step 0 — Load context (MANDATORY before anything else)

Read these files before delegating to any specialist:

1. `CLAUDE.md` — overview, architecture, critical rules, common pitfalls
2. `.claude/docs/architecture-overview.md` — full directory tree, per-app structure, pitfalls
3. `.claude/docs/coding-standards.md` — ESLint rules, import aliases, TypeScript strictness
4. `.claude/rules/trpc-patterns.md` — tRPC procedure patterns, `implement<T>()`, `userProcedure`
5. `.claude/rules/modular-architecture.md` — module boundaries, gotchas, ESLint boundaries
6. `.claude/rules/i18n.md` — next-intl patterns, dictionary registration
7. `AGENT.md` (this repo's agent index, at `~/cangaco/.ai/claude/agents/isaac/rf-monorepo/AGENT.md`)

If the PR touches a specific app, also read: `apps/<name>/CLAUDE.md` if it exists.
If the PR touches `modules/`, also read the module's own README or docs if available.

**Skip-Step-0 is a hard violation.**

---

## Step 1 — Identify task type

| Task type | Signal | Default action |
|-----------|--------|---------------|
| PR review | `diff` provided | Run specialists on changed files |
| tRPC procedure change | `apps/*/src/server/router/` in diff | Focus trpc-auditor |
| Module change | `modules/*/` in diff | Focus module-boundary-auditor |
| Package change | `packages/*/` in diff | Focus module-boundary-auditor (alias checks) |
| App-only change | `apps/*/src/app/` or `apps/*/src/components/` | component patterns check only |

---

## Step 2 — Delegate to specialists (Phase 1 — parallel)

Invoke both specialists in parallel via the Task tool:

**trpc-auditor** — provide:
- Full unified diff
- PR metadata
- Context: `.claude/rules/trpc-patterns.md` content, `implement<T>()` pattern, `userProcedure`
- Instruction: focus on `apps/*/src/server/router/**/*.ts` and any modules' `server/router/`

**module-boundary-auditor** — provide:
- Full unified diff
- PR metadata
- Context: `.claude/rules/modular-architecture.md`, import alias rules from CLAUDE.md
- Instruction: check imports in `modules/`, `packages/`, and `apps/` for boundary violations

If the diff touches only `apps/*/src/app/**` (page/component files) with no tRPC or module
changes, run specialists in direct mode — check i18n, React patterns, and common pitfalls from
Step 0 context without full specialist dispatch.

---

## Step 3 — Synthesize into AGENT_REPORT

After both specialists return:

1. Deduplicate by `(file, line_range, root_cause)`.
2. Classify:
   - **CRITICAL** — ESLint hard error (CI fails), boundary violation, missing `.input()`, `console.*`
   - **IMPORTANT** — should fix (anti-pattern, type placement wrong, hardcoded string, `interface`)
   - **NOTE** — informational
3. Confirm each finding by reading the actual code at the cited location.

---

## Step 4 — Return AGENT_REPORT

```markdown
## RF-Monorepo Agent Audit

### Scope
<affected apps, modules, or packages>

### Critical Issues
- [`file:line`] <agent-name> — <description>

### Important Issues
- [`file:line`] <agent-name> — <description>

### Notes
- [`file:line`] <agent-name> — <description>

### Agents run
- trpc-auditor: APPROVED / N issues
- module-boundary-auditor: APPROVED / N issues

### Verdict
APPROVED | REQUEST CHANGES
```

---

## Rules

- Never write code, never run tests, never make commits.
- Never hard-code the specialist list — discover from `AGENT.md` at runtime.
- If a finding cannot be confirmed by reading the actual file, drop it.
- CRITICAL findings block verdict to REQUEST CHANGES.
