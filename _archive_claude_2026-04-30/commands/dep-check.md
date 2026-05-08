---
name: dep-check
description: Check for outdated, unused, or vulnerable dependencies
user_invocable: true
---

Analyze the project's dependencies. Follow these steps:

1. Detect the package manager (package.json, requirements.txt, go.mod, Cargo.toml, etc.)
2. Check for:
   - Outdated packages (run the appropriate check command)
   - Known vulnerabilities (audit command if available)
   - Unused dependencies (scan imports vs declared deps)
3. Provide a summary:
   - Critical updates needed (security)
   - Major version bumps available
   - Potentially unused dependencies
   - Recommended actions
