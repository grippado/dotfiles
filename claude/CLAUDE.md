# Grippado — Global Claude Code Config

## Preferences

- Language: Brazilian Portuguese for communication when context is clear, English for code and technical terms
- PT-BR writing: SEMPRE usar acentuação e diacríticos corretos em português (é, ã, ç, ê, ó, etc.). Nunca omitir acentos — "aplicação" e não "aplicacao", "código" e não "codigo", "não" e não "nao". Isso vale para código (strings i18n, conteúdo em pt.json), comentários, e comunicação com o usuário.
- **NO em-dashes em textos para publicação externa.** Qualquer texto que eu preparar para o usuário postar/enviar (LinkedIn posts, Slack messages, PR titles, PR bodies, commit messages externos, comentários em issues públicas) NÃO deve conter travessão (—) nem en-dash (–). Usar vírgula, dois-pontos, parênteses, ponto-e-vírgula ou quebra de frase. Esta regra NÃO se aplica à comunicação interna comigo no chat, nem a comentários inline de código, nem a docs internas (CLAUDE.md, ADRs, notes pessoais).
- Commit style: Conventional Commits with emoji prefixes
- Package managers: pnpm (preferred), yarn, npm
- Use direnv for environment management

---

# Multi-Model Subagent Orchestration

## Delegation Rules
You are configured with specialized subagents. Use them proactively:

## CRITICAL: Delegation is mandatory, not optional
You MUST spawn subagents for the tasks below. NEVER do these inline:
- Documentation → doc-writer
- Commit messages → git-assistant
- Decision extraction → memory-extractor
- **ALWAYS delegate** context persistence, session summaries, and decision records to `context-keeper`
- **Delegate code review** to `code-reviewer` before finalizing PRs
- **Delegate refactoring analysis** to `refactor-scout` on request or before large refactors

## Routing Strategy
- Main session (Opus): Architecture, complex implementation, planning, debugging
- Sonnet subagents: Documentation, code review, testing, refactoring analysis, context saving
- Haiku subagents: Memory extraction, commit messages, quick metadata tasks

## Parallel Execution
When implementing a feature, spawn these in parallel after the main implementation:
1. `doc-writer` → PR description + docs
2. `test-writer` → test coverage
3. `memory-extractor` → save decisions
4. `git-assistant` → prepare commit messages

## Important
- Background subagents when possible to preserve main context
- Each subagent has its own context window — use them to keep the main session clean
- Prefer spawning subagents over doing mechanical tasks in the main session
