---
name: quick-commit
description: Stage and commit changes with a conventional commit message
user_invocable: true
---

Help me commit the current changes. Follow these steps:

1. Run `git status` and `git diff` to understand all changes
2. Run `git log --oneline -5` to see the recent commit style
3. Analyze the changes and determine the appropriate conventional commit type:
   - feat, fix, docs, style, refactor, perf, test, build, ci, chore
4. Draft a concise commit message following Conventional Commits format
5. Show me the proposed commit message and wait for confirmation before committing
6. Stage only the relevant files (avoid staging secrets, .env, or unrelated files)
7. Create the commit
