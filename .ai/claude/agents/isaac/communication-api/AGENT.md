# AGENT.md — communication-api

Agent index for `communication-api` (Fastify + Node.js messaging platform).
For the canonical specification this system follows, see [`../AGENT_SPEC.md`](../AGENT_SPEC.md).

---

## Agents

| Agent | Model | Role |
|-------|-------|------|
| `repo-owner` | sonnet | Orchestrator — always invoked first. Loads context, routes tasks, gates on blockers. |
| `contract-scouter` | sonnet | Scans contracts between layers: validates that controllers only call services, services only call repositories, and no layer skips the chain. |
| `route-auditor` | sonnet | Audits route definitions: middleware chain order, Zod validation presence, auth coverage, and response contract (success/error shape). |
| `test-coverage-scouter` | haiku | Scans changed/targeted files and reports missing test coverage: services without unit tests, controllers without inject-based tests, integration test gaps. |
| `repository-layer-auditor` | sonnet | Audits repository files: business logic leakage, missing soft-delete filters, missing inArray guards, transaction misuse, and readDb vs db violations. Receives contract-scouter output as input. |
| `payload-reviewer` | sonnet | Reviews request/response payload shape: Zod schema completeness, type safety on deserialization, missing fields, over-fetching, and drift between schema and controller usage. |

---

## Commands

| Command | Description |
|---------|-------------|
| `/workflow [ticket] [--no-review\|-no-r]` | End-to-end ticket implementation: plan, implement (TDD), test, review, local test, draft PR. |
| `/review-pr [--agents-on\|-aon]` | Review a PR against coding standards. Without flag: current behavior. With `--agents-on`: activates specialist agents + benchmark comparison. |
| `/test-local` | Run local endpoint tests against a running server instance. |
| `/workflow-cloud` | Cloud variant of /workflow (different infra assumptions). |

---

## Dependency graph

```
/workflow
  repo-owner (context load + plan)
  ‖
  pattern-finder ‖ worktree-creation   (parallel)
  |
  implementation                        (sequential)
  |
  test-runner                           (sequential)
  |
  reviewer                              (sequential — parallel internally)
    ‖ structural ‖ patterns ‖ test-coverage ‖ docs-freshness ‖ performance
  |
  local-test                            (sequential)
  |
  PR creation

/review-pr --agents-on
  repo-owner (context load)
  ‖ (parallel baseline + agent runs)
  baseline: existing review-pr logic
  agents:
    contract-scouter
    |
    route-auditor ‖ test-coverage-scouter ‖ repository-layer-auditor ‖ payload-reviewer
  benchmark report
```

Sequential dependency: `contract-scouter` MUST complete before `repository-layer-auditor` starts.
`contract-scouter` output is passed directly to `repository-layer-auditor` as context.

---

## Adoption status

Current adoption level: **pilot**

Flag support: `--agents-on` supported on `/review-pr` (to be implemented).
`/workflow` uses the existing review agents (`reviewer`, `self-reviewer`) — agents below
integrate as an optional layer via `--agents-on`, not as a replacement.
