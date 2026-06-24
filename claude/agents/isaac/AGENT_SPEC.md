# AGENT_SPEC — Isaac Repo Agents

Canonical specification for the per-repo agent ecosystem across the Isaac/OlaIsaac/ClassApp
workspace. Every `AGENT.md` in this directory defers to this file for cross-cutting rules.

Last updated: 2026-06-24 | Status: active

---

## 1. Purpose

The Isaac repos (backoffice, backoffice-bff, rf-monorepo, communication-api, and others) share
domain knowledge that generic reviewers miss: layer-contract rules, Zod schema patterns, Fastify
plugin ordering, soft-delete guards, `readDb`/`db` routing. A general `arco-pr-reviewer` catches
structural issues but cannot reason about repo-specific invariants unless they are encoded in
specialist agents.

This ecosystem solves three problems:

1. **Institutional knowledge at review time.** Specialists embody the conventions of a single repo.
   They read the real code before judging — they do not hallucinate patterns.
2. **Baseline comparison.** Running specialists alongside the generic reviewer (benchmark mode)
   makes the value of each approach measurable and falsifiable.
3. **Incremental ownership transfer.** Agents start as personal tooling in `~/.dotfiles-ai` and
   can be migrated into the repo itself when the team is ready (see section 8).

---

## 2. Directory structure

```
~/.dotfiles-ai/claude/agents/isaac/
├── AGENT_SPEC.md              ← this file (canonical spec)
├── communication-api/
│   ├── AGENT.md               ← agent index + dependency graph for this repo
│   ├── repo-owner.md          ← orchestrator (mandatory)
│   ├── contract-scouter.md
│   ├── route-auditor.md
│   ├── test-coverage-scouter.md
│   ├── repository-layer-auditor.md
│   └── payload-reviewer.md
├── backoffice/
│   ├── AGENT.md
│   ├── repo-owner.md
│   └── ...
├── backoffice-bff/
│   └── ...
└── rf-monorepo/
    └── ...
```

**Naming rules:**

- The directory name (`<repo-slug>`) must match the output of `gh repo view --json name -q .name`
  run from inside the repo checkout. This is what `review-arco` and `review-arco-iterate` use to
  locate the agent directory at runtime.
- Every repo directory must have an `AGENT.md` (index) and a `repo-owner.md` (orchestrator).
  Specialist agents are optional and vary by repo type.

---

## 3. Agents: mandatory vs optional

### 3.1 Mandatory for every repo

| Agent | File | Purpose |
|-------|------|---------|
| `repo-owner` | `repo-owner.md` | Orchestrator. Always the first agent invoked. Loads context, routes tasks, dispatches specialists, gates on blockers, synthesizes. Never writes code or runs tests. |

### 3.2 Optional — by repo type

**Fastify / Node.js API repos** (communication-api, backoffice-bff):

| Agent | When to add |
|-------|------------|
| `contract-scouter` | Repo has strict layer contracts (controller → service → repository chain) |
| `route-auditor` | Repo has Fastify route definitions with middleware chains |
| `repository-layer-auditor` | Repo has repository files with known pitfalls (soft-delete, `inArray`, `readDb`/`db`) — depends on `contract-scouter` output |
| `payload-reviewer` | Repo uses Zod for request/response validation |
| `test-coverage-scouter` | Repo has a test suite; haiku model is sufficient |

**React SPA / Next.js repos** (backoffice, rf-monorepo):

| Agent | When to add |
|-------|------------|
| `component-auditor` | Validates component isolation, prop drilling, context misuse |
| `query-reviewer` | Reviews React Query usage patterns and cache invalidation |
| `a11y-scouter` | Accessibility coverage on changed components |

**Go repos** (payment-api, sorting-hat):

| Agent | When to add |
|-------|------------|
| `interface-auditor` | Interface satisfaction, dependency injection patterns |
| `error-chain-scouter` | Sentinel errors, wrapping, context propagation |

Specialist agents that do not exist yet for a repo simply do not appear in its `AGENT.md`.
The `repo-owner` discovers agents at runtime via `AGENT.md` — never hard-codes the list.

---

## 4. Contract of `repo-owner`

### 4.1 What it loads (Step 0 — always, before anything else)

1. `CLAUDE.md` — repo overview, architecture summary, critical patterns, known pitfalls
2. `.claude/docs/architecture.md` — full directory tree and data flow (if present)
3. `.claude/docs/coding-standards.md` — linter, TypeScript, naming, logging rules (if present)
4. `AGENT.md` — this repo's agent index and dependency graph

If a Linear ticket is provided, load its description and acceptance criteria.

**Skip-Step-0 is a hard violation.** The repo-owner must never delegate before loading context.

### 4.2 What it receives (inputs)

When invoked by `review-arco` or `review-arco-iterate` via the `--agents-on` flag:

| Input | Source | Notes |
|-------|--------|-------|
| `diff` | `gh pr diff` output | Full unified diff of the PR |
| `pr_metadata` | `gh pr view --json ...` | title, number, repo, branches, author, state |
| `open_threads` | GraphQL `reviewThreads` | Only passed by `review-arco-iterate` for thread-level enrichment |
| `flag` | `--agents-on` present | Signals benchmark mode — run baseline and agents in parallel |
| `scope` | Derived from diff | File list, or "full repo" if no diff |

When invoked directly for an audit (not via review-arco):

| Input | Source |
|-------|--------|
| `scope` | File list, domain name, or "full repo" |
| `task_type` | Detected from the request (feature, audit, architecture question) |

### 4.3 What it returns (`AGENT_REPORT`)

The repo-owner always returns a single synthesized report — never raw specialist output.

```markdown
## <Repo> Agent Audit

### Scope
<what was scanned — file list, domain, or "full repo">

### Critical Issues
- [`file:line`] <agent-name> — <description>

### Important Issues
- [`file:line`] <agent-name> — <description>

### Notes
- [`file:line`] <agent-name> — <description>

### Agents run
- contract-scouter: APPROVED / N issues
- route-auditor: APPROVED / N issues
- test-coverage-scouter: APPROVED / N issues
- repository-layer-auditor: APPROVED / N issues
- payload-reviewer: APPROVED / N issues

### Verdict
APPROVED | REQUEST CHANGES
```

**Synthesis rules:**

- Deduplicate by `(file, line, root cause)` before reporting.
- Classify: CRITICAL (blocks merge), IMPORTANT (should fix), NOTE (informational).
- If CRITICAL findings exist, surface them prominently and ask before proceeding.
- Never dump raw agent output. Always synthesize.

---

## 5. Pipeline: sequential vs parallel

### 5.1 Communication-api pipeline (reference implementation)

```
Phase 1 — parallel (all independent reads):
  ┌──────────────────┐
  │ contract-scouter │ ─────────────────────────────────┐
  │ route-auditor    │                                   │
  │ test-coverage-*  │                                   ▼
  │ payload-reviewer │             Phase 2 — sequential:
  └──────────────────┘             repository-layer-auditor
                                   (receives contract-scouter output)
```

**Why this ordering:**

`contract-scouter` maps which services each controller calls and which repositories each service
calls. `repository-layer-auditor` needs this map to know whether a repository is being accessed
correctly from the layer above it. Without that context, it would miss cross-layer violations.

The other Phase 1 agents (`route-auditor`, `test-coverage-scouter`, `payload-reviewer`) are
independent of each other and of `contract-scouter` in their read phase — they can run fully
concurrently.

### 5.2 General orchestration rule

**Run in parallel if:** the agents read disjoint parts of the codebase and neither needs output
from the other.

**Run sequentially if:** agent B needs agent A's findings to make correct decisions (not just to
avoid redundancy — to avoid wrong conclusions).

When in doubt, run sequentially. The correctness cost of a wrong sequential dependency assumption
is higher than the latency cost of an unnecessary sequence.

---

## 6. Integration with `/review-arco` and `/review-arco-iterate`

Both commands accept `--agents-on` (alias `-aon`) in any argument position.

### 6.1 How the flag activates the pipeline

**Step: detect repo-owner**

```bash
REPO_SLUG=$(gh repo view --json name -q .name)
REPO_OWNER_PATH="$HOME/.dotfiles-ai/claude/agents/isaac/$REPO_SLUG/repo-owner.md"
```

If `$REPO_OWNER_PATH` does not exist: warn ("nenhum agent especializado encontrado para
`<repo-slug>`") and fall back to normal flow without agents.

If it exists: invoke `repo-owner` via Task tool before delegating to `arco-pr-reviewer`.

### 6.2 In `/review-arco` — benchmark mode

Two Task tool calls run in parallel:

- **Task A (Baseline):** `arco-pr-reviewer` with the base inputs (no `AGENT_REPORT`).
- **Task B (Agents):** (1) `repo-owner` produces `AGENT_REPORT`; then (2) `arco-pr-reviewer` with
  the same base inputs plus `AGENT_REPORT` as additional context.

The benchmark comparison (section 9) is computed from the two results and written to the vault
file before the consolidated review.

### 6.3 In `/review-arco-iterate` — enriched thread verification

`repo-owner` is invoked once at the start (step 2b), producing `AGENT_REPORT`.
For each open thread, the `AGENT_REPORT` is consulted as evidence:

- If the specialist that covers the thread's domain confirms the finding: weight toward **procede**.
- If the specialist contradicts the reviewer: weight toward **improcedente**.
- The source must be cited in the justification: `(corroborado por route-auditor)`.

There is no parallel baseline in this flow — the flag enriches the decision layer, not the
whole review pipeline.

---

## 7. Adding agents for a new repo

### Checklist

- [ ] **Confirm repo-slug.** Run `gh repo view --json name -q .name` from inside the checkout.
      The directory name must match exactly.
- [ ] **Create the directory:** `mkdir -p ~/.dotfiles-ai/claude/agents/isaac/<repo-slug>/`
- [ ] **Write `AGENT.md`** — agent index, command table, and dependency graph. Reference this
      file: `For the canonical specification this system follows, see ../AGENT_SPEC.md`.
- [ ] **Write `repo-owner.md`** — follow the communication-api implementation as reference.
      Adapt Step 0 to the actual docs present in the repo (list only files that exist).
      Adapt Step 1's task-type table to the repo's commands.
      Keep the Step 4 synthesis rules unchanged.
- [ ] **Write each specialist** based on the repo type (section 3.2). Read the actual repo code
      before writing any specialist — do not copy patterns blindly from another repo.
- [ ] **Define the dependency graph** in `AGENT.md`. Be explicit about which agents are sequential
      and which can run in parallel (section 5).
- [ ] **Commit to dotfiles-ai** with conventional commit: `feat(agents): add <repo> agent suite`.
- [ ] **Smoke test:** invoke `/review-arco <PR-number> --agents-on` from inside the repo checkout.
      Confirm repo-owner is found, specialists are dispatched, and AGENT_REPORT is non-empty.

### What NOT to do

- Do not copy `repo-owner.md` verbatim and change only the repo name. The Step 0 reads and the
  specialist list must reflect the target repo's actual structure.
- Do not add a specialist unless it can read real files in the repo. A specialist that reasons
  only from the diff is less useful than the generic reviewer.
- Do not hard-code the specialist list inside `repo-owner.md`. The repo-owner discovers agents
  from `AGENT.md` at runtime.

---

## 8. Team ownership (phase 2)

Phase 1 (current): agents live in `~/.dotfiles-ai/claude/agents/isaac/<repo-slug>/`. They are
personal tooling — maintained by Gabriel, not visible to the team, not versioned in the repo.

Phase 2 (future): agents move into the repo itself at `.claude/agents/`. The team maintains them,
reviews them in PRs, and the `repo-owner` becomes a shared resource.

### Migration path (phase 2 trigger conditions)

Consider migrating when **any two** of the following are true:

- A specialist has caught ≥3 real bugs across ≥3 PRs (not false positives).
- Another team member asks "how do I run the agents on my machine?"
- The personal copy diverges from the repo's conventions (specialist assumptions no longer hold).
- The team adopts a Claude Code plan that includes agent-assisted review as a standard step.

### Migration steps

1. Open a PR in the target repo adding `.claude/agents/<specialist>.md` for each file.
   Include the `AGENT.md` index as `.claude/AGENT.md` (or merge into existing if present).
2. Update `repo-owner.md` to read local context files relative to `pwd` rather than absolute
   paths (the repo checkout replaces the need for the absolute `.dotfiles-ai` path).
3. After the PR merges, delete the corresponding directory from `~/.dotfiles-ai/claude/agents/isaac/`.
4. Update the review-arco detection logic: the `REPO_OWNER_PATH` check should fall back to
   `.claude/agents/repo-owner.md` in the local checkout if the dotfiles-ai path does not exist.

**Policy:** phase 2 migration is a team decision. Do not move files into a shared repo unilaterally.
ADR-006 in `ARCHITECTURE.md` applies: shared repos are read-only from personal tooling.

---

## 9. Benchmark output format

Referenced by `repo-owner.md` step 3 ("See `AGENT_SPEC.md` section 9 for the benchmark output
format") and written to the vault by `review-arco` when `--agents-on` is active.

### 9.1 Markdown section (written before `## Resumo` in the vault file)

```markdown
## Benchmark --agents-on

| Categoria | Findings |
|-----------|----------|
| Encontrado apenas com agents | {list of `file:line — topic`, or "(nenhum)"} |
| Encontrado apenas no baseline | {list, or "(nenhum)"} |
| Encontrado em ambos | {list, or "(nenhum)"} |

Agents run: {comma-separated list of specialist agents invoked by repo-owner}
Benchmark duration: baseline {Xs} / agents {Ys} (wall-clock)
```

### 9.2 Finding identification

Two findings are considered the **same** if they share at least two of:
- Same file (exact path match)
- Same line range (overlap, not exact match required)
- Same root cause label (the topic/theme of the finding, not the wording)

Two findings are **distinct** even if they touch the same file if they describe different root
causes (e.g., "missing soft-delete filter" vs "missing `inArray` guard" on the same repository
file are two distinct findings).

**When unsure:** classify as distinct and let the user collapse. False splits are less damaging
than false merges (merged findings hide coverage gaps).

### 9.3 Metrics to collect (per run)

Record these in the benchmark section or as a comment in the vault file:

| Metric | How to compute |
|--------|---------------|
| `issues_agents_only` | `len(só_agents)` |
| `issues_baseline_only` | `len(só_baseline)` |
| `issues_both` | `len(ambos)` |
| `agent_recall_over_baseline` | `len(ambos) / max(1, len(ambos) + len(só_baseline))` — how much of what the baseline found did the agent pipeline also find? |
| `agent_exclusive_rate` | `len(só_agents) / max(1, total_agent_findings)` — what fraction of agent findings are exclusive? |
| `false_positive_estimate` | Filled in manually after verification. Count agent-exclusive findings that were reviewed and found improcedente. |
| `wall_clock_baseline` | Seconds for Task A to return |
| `wall_clock_agents` | Seconds for repo-owner + Task B to return |

These metrics are informational. They accumulate value across PRs — over time, a consistent
`agent_exclusive_rate > 0.2` with low `false_positive_estimate` is the signal that the specialist
suite is earning its place.

### 9.4 What the repo-owner must return to enable benchmark computation

For the benchmark to be computable by `review-arco`, the `AGENT_REPORT` must structure findings
as a list with explicit `(file, line_range, topic)` keys — not just prose. The output format in
section 4.3 satisfies this: each bullet in Critical/Important/Notes carries `[file:line]` and a
description. `review-arco` extracts these as the agent findings set.

### 9.5 Longitudinal tracking (optional)

If a PR series warrants deeper analysis, findings can be tagged with the PR number and accumulated
in `~/.notes/pr-reviews/agent-benchmark-log.md` (one row per PR, same columns as 9.3). This is
manual and optional — the per-file benchmark section is the primary record.

---

## Adoption status

| Repo | Status | Agents |
|------|--------|--------|
| `communication-api` | pilot | repo-owner, contract-scouter, route-auditor, test-coverage-scouter, repository-layer-auditor, payload-reviewer |
| `backoffice` | not started | — |
| `backoffice-bff` | not started | — |
| `rf-monorepo` | not started | — |
| `payment-api` | not started | — |
| `sorting-hat` | not started | — |
