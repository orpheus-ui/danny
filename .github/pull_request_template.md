## What and why

<!-- One or two sentences. The why is the part nobody can reconstruct later. -->

## Checklist

- [ ] Title is a Conventional Commit (`feat(ui): …`) — it becomes the squash commit and the changelog line
- [ ] `make check` passes (lint + tests); new behavior has tests, a bug fix starts with a failing one
- [ ] UI change? Screenshots before/after, and it matches the Figma design
- [ ] Animation, timer, polling or background work? Idle CPU measured and still ~0% (docs/engineering.md)
- [ ] Left the code I touched cleaner than I found it; bigger debt went into `docs/backlog.md`
- [ ] Docs describing changed behavior are updated
