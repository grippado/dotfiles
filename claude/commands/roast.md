---
description: Roast a developer's public GitHub profile in the voice of a tech celebrity. Pure satire, public data only.
argument-hint: <github-username> [--persona=linus|steve-jobs|bill-gates|trump|maddog|dhh|carmack|terry-davis] [--spice=mild|spicy|nuclear] [--format=reddit|twitter|linkedin|terminal]
---

Use the `roaster` skill to generate a developer roast.

**Target:** $ARGUMENTS

**Defaults if flags are missing:**
- persona: `linus`
- spice: `spicy`
- format: `reddit`

**Workflow:**
1. Parse the target username and flags from the arguments above.
2. If the target is missing, ask for it and stop.
3. Follow the roaster skill's workflow (collect GitHub data → pick tells → load persona → write roast).
4. Output the roast wrapped in a code fence ready for copy-paste.
5. Below the roast, suggest one Twitter-ready variant and one Reddit title.

**Reminders:**
- Public GitHub data only. No LinkedIn scraping, no email harvesting.
- If the target has < 3 public repos, auto-soften to the `mild` spice level and add an encouraging closer.
- Never invent stats. Every number in the footer must trace back to an actual API response.
- If the user is roasting a third party (not themselves), ask once if the target is in on the joke before proceeding at full spice.
