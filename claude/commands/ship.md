---
description: "Full feature shipping workflow with mandatory delegation"
---

After implementing the requested feature:

1. Spawn `doc-writer` to generate PR description from the diff
2. Spawn `test-writer` to generate tests for changed files
3. Spawn `git-assistant` to prepare conventional commit messages
4. Spawn `memory-extractor` to save key decisions
5. Spawn `context-keeper` to write a session summary

Execute all subagents. Do not skip any step.
Present the results in order when all complete.