# AGENT.md — technical-refining

Agent index for the technical-refining repo. For the canonical specification this system follows,
see ../AGENT_SPEC.md.

## Repo identity

- **Slug:** `technical-refining` (output of `gh repo view --json name -q .name`)
- **Stack:** Documentation only. No code. Uses Obsidian-compatible markdown with YAML frontmatter.
- **Architecture:** Spec Driven Development (SDD) hub. Contains PRDs, DRTs, plans, issues, and
  cross-repo documentation organized under `domains/` by business domain.

## Agents

| Agent | File | Domain |
|-------|------|--------|
| repo-owner | `repo-owner.md` | Orchestrator — mandatory, always first |
| sdd-quality-auditor | `sdd-quality-auditor.md` | SDD artifact quality: self-containedness, frontmatter, issue completeness |

## Dependency graph

```
Phase 1 — single specialist:
  sdd-quality-auditor

Phase 2 — synthesis:
  repo-owner (summarizes, flags violations)
```

Only one specialist is warranted here: the entire domain is document quality. The repo-owner
synthesizes and classifies.

## Commands

None (docs-only repo). Linting via `shared/INDEX.md` consistency checks (manual).

## Key context files

- `CLAUDE.md` — SDD pipeline, taxonomy, frontmatter schema, rules (always/never)
- `RULES.md` — Universal agent behavior rules
- `shared/INDEX.md` — Discovery index (by repo, area, type)
- `shared/guides/sdd-workflow.md` — Canonical SDD pipeline documentation
- `.claude/skills/sdd-issues/reference/archetypes.md` — Issue archetype catalog (backend)
- `.claude/skills/sdd-plan-backend/reference/archetypes.md` — Backend plan archetype reference

## What this repo validates (vs other repos)

`technical-refining` is a docs repo. PRs here add or update SDD artifacts (prd.md, drt.md,
DESIGN.md, plan.md, issues.md, issue-tree.md). The agent's job is to validate that:

- Issues are self-contained (no dep on external docs)
- Frontmatter is complete and uses valid taxonomy values
- Contracts are inline, not by reference only
- No standalone security issues exist (mitigations land in functional issues)
- No issues touch more than 1 repo
- Every issue declares `Agent autonomy` (AFK/HITL) and `Archetype`

## Known pitfalls (from CLAUDE.md reading)

1. Issues missing `Contrato (inline)` — `> Fonte: drt.md → ...` alone is a hard violation.
2. UI issues without direct Figma URL in section 2 (`Frames de design`).
3. Issues with macro not declared (must be `Foundational`, `US<n>`, or `Cleanup`).
4. Standalone `Security:` issues — all mitigations land as AC/DoD/TC in functional issues.
5. Issues touching more than 1 repo — must be split into N issues with `Blocked by` deps.
6. `Agent autonomy` field missing — every issue must declare AFK or HITL.
7. Editing `prd.md`/`drt.md` with status `done` via Write/Edit directly — requires rerun of slash command.
8. Frontmatter `repos` field with invalid slug — must match the 6 valid Linear Application slugs.
