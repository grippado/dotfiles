---
description: Smoke test dos scripts e do /cantar — sintaxe bash, shellcheck, e instrução pra testar o folheto em dry-run.
argument-hint: "[arquivos bash...] [--date YYYY-MM-DD]"
---

# /smoke

> Absorvido do plugin cordel (antes em `personal/cordel`). Diagnóstico rápido, reutilizável no dotfiles-ai. Aponte aos scripts bash que quiser checar; sem args, faz best-effort nos scripts presentes.

Roda em sequência e reporta ✅/❌ por etapa, em PT-BR:

### 1. Sintaxe bash
Pra cada arquivo bash alvo (passado em `$ARGUMENTS` ou descoberto):
```bash
bash -n <arquivo>
```

### 2. Shellcheck (se instalado)
```bash
command -v shellcheck >/dev/null && shellcheck -x <arquivos bash alvo>
```
Se shellcheck não estiver instalado, avise e siga (não falha). Para achados, considere delegar ao agent `shellcheck-guardian`.

### 3. (Opcional) Dry-run do /cantar
**Não execute automaticamente** — gasta tokens. Mas relate ao usuário o comando exato pra testar manualmente:
```
claude -p "/cantar --dry-run --date YYYY-MM-DD"
```

Não tente "consertar" automaticamente — só diagnostica. Se algo falhar, mostre 1-2 linhas do erro.
