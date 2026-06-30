# AGENT.md — technical-refining

Agent index for `technical-refining` (documentation-only SDD hub for the Isaac workspace).
For the canonical specification this system follows, see [`../AGENT_SPEC.md`](../AGENT_SPEC.md).

---

## Repo identity

- **Slug:** `technical-refining` (output of `gh repo view --json name -q .name`)
- **Stack:** Markdown only. No application code, no tests, no build. The repo hosts SDD artifacts
  (`prd.md`, `drt.md`, `DESIGN.md`, `<layer>/plan.md`, `<layer>/issues.md`, `issue-tree.md`) under
  `domains/**` and cross-repo docs under `shared/**`.
- **Process:** Spec Driven Development (SDD). Pipeline: Discovery (`/sdd:grill` → `/sdd:prd`) →
  DRT with integrated Threat Model (`/sdd:grill-tech` → `/sdd:drt`) → Planning
  (`/sdd:plan` → DESIGN + plans + issues) → Export (`/sdd:export:linear`). Full guide in
  `shared/guides/sdd-workflow.md`.
- **The product is the spec.** Quality here is not "does it compile" — it is "can an implementing
  agent execute this issue from Linear alone, without ever opening the PRD/DRT/plan." That invariant
  (self-contained issues) is the spine of every audit below.

---

## Agents

| Agent | Model | Role |
|-------|-------|------|
| `repo-owner` | sonnet | Orchestrator — always invoked first. Loads CLAUDE.md + RULES.md + the SDD workflow guide, detects which artifact types the diff touches, dispatches the auditor, gates on blockers, synthesizes. Never writes or edits artifacts. |
| `sdd-quality-auditor` | sonnet | Audits SDD artifacts against the `### Sempre`/`### Nunca` rules in `CLAUDE.md` and `RULES.md`: frontmatter/taxonomy, issue 11-section structure, `Contrato (inline)` with effective shape, UAT `Casos de uso`, direct Figma URLs, macro/archetype/Agent-autonomy/Application labels, 1-repo-per-issue, threat-model mitigation landing (no standalone `Security:` issue), Obsidian cross-links + INDEX, PT-BR accentuation, no secrets, relative paths. Read-only. |

---

## Commands

| Command | Description |
|---------|-------------|
| `/review-arco pr [PR] [--agents-on\|-aon]` | Review a refinement PR. With `-aon`: `repo-owner` runs `sdd-quality-auditor` and the result enriches `arco-pr-reviewer` in benchmark mode. |
| `/sdd:grill` · `/sdd:prd` | Stage 1 — Discovery (interview → prd.md). |
| `/sdd:grill-tech` · `/sdd:drt` · `/sdd:threat-model` | Stage 2 — DRT with integrated Threat Model. |
| `/sdd:plan` | Stage 3 — DESIGN.md + backend/frontend plans + issues + issue-tree. |
| `/sdd:export:linear` | Export merged refinement to Linear (Project + Milestones + Issues + Blockers). |

The SDD commands are the repo's own tooling. The agents in this suite do **not** generate artifacts —
generation belongs to the `sdd-*` skills. This suite only **reviews** what those skills produced.

---

## Dependency graph

```
/review-arco pr --agents-on
  repo-owner (Step 0: load CLAUDE.md + RULES.md + sdd-workflow guide)
  |
  artifact-type detection (which of prd/drt/DESIGN/plan/issues/shared-doc the diff touches)
  |
  sdd-quality-auditor   (single specialist — receives DIFF_FILES + detected artifact types)
  |
  synthesis (AGENT_REPORT)
```

Single specialist: no sequential dependency to enforce. If the suite later grows a second auditor
(e.g. a dedicated `linear-export-validator`), declare its ordering here per `AGENT_SPEC.md` §5.

---

## Adoption status

Current adoption level: **active** (per `AGENT_SPEC.md` adoption table).

Flag support: `--agents-on` / `-aon` on `/review-arco` and `/review-arco-iterate`.
Phase 1 — agents live here in `~/cangaco/.ai`; not yet migrated into the repo's `.claude/agents/`
(see `AGENT_SPEC.md` §8 for phase-2 migration triggers).
