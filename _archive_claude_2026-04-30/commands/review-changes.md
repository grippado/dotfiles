---
name: review-changes
description: Review all uncommitted changes in the current repository
user_invocable: true
---

Review all uncommitted changes in this repository. Follow these steps:

1. Run `git diff` to see unstaged changes and `git diff --cached` to see staged changes
2. Run `git status` to understand the full picture
3. For each changed file, analyze:
   - Is the change correct and complete?
   - Are there any bugs or edge cases missed?
   - Is the code clean and following project conventions?
   - Are there any security concerns?
4. Provide a summary with:
   - What looks good
   - What needs attention (with file:line references)
   - Whether these changes are ready to commit
