# Contributing

Thanks for helping. If a step here is unclear, that's a bug in this file.

## The short version

```
feat/your-change  →  development  →  main
     (your work)      (next release)   (released)
```

**Nobody commits directly to `main` or `development`.** Everything goes through
a branch and a pull request against `development`. `main` only receives releases.

## First time

```bash
git clone https://github.com/orpheus-ui/danny.git && cd danny
make bootstrap   # tools (Homebrew), git hooks, asset catalog, Xcode project
make run         # build and launch
```

You need macOS 26 and Xcode 26. `make help` lists every command.

## Making a change

1. **Branch from an up-to-date `development`:**
   ```bash
   git switch development && git pull
   git switch -c fix/progress-label-overlap
   ```
   | Prefix | For |
   |---|---|
   | `feat/` | new functionality |
   | `fix/` | a bug fix |
   | `refactor/` | restructuring, no behavior change |
   | `perf/` | resource use, speed |
   | `chore/` | dependencies, config, tooling |
   | `docs/` | documentation only |
   | `test/`, `ci/` | what they say |

2. **Work, then check:** `make check` runs the format check, lint and tests —
   exactly what CI runs. `make format` fixes formatting.
3. **Commit** with a [Conventional Commit](https://www.conventionalcommits.org)
   and a body that says *why*:
   ```
   fix(ui): keep the progress label readable at low percentages

   The label followed the fill's edge, so at 5% it sat half on the fill and
   half on the track. It is now centered and changes color where the fill ends.
   ```
4. **Open a PR against `development`.** The PR **title** must be a Conventional
   Commit too — PRs are squash-merged, so the title becomes the commit and the
   changelog line. Fill in the template's checklist.
5. **CI and review.** Merge when CI is green and every review comment is resolved
   — fixed, or answered with why not.

## What we look for

Read [docs/engineering.md](docs/engineering.md) first; two rules there decide most reviews:

- **Danny is light.** No idle timers, polling or animation; measure anything
  that adds background work.
- **Clean as you go.** Leave touched code cleaner; record bigger debt in
  [docs/backlog.md](docs/backlog.md) instead of leaving it silently.

UI changes follow the Figma design and include before/after screenshots.
Architecture and past decisions: [docs/architecture.md](docs/architecture.md),
[docs/decisions.md](docs/decisions.md). What's planned: [docs/roadmap.md](docs/roadmap.md).

## Plugins

Extractor and engine plugins arrive in M2 with a guide in `docs/plugins.md`.
Until then, extractor fixes for sites yt-dlp supports belong upstream in
[yt-dlp](https://github.com/yt-dlp/yt-dlp).

## Rules

- One concern per branch — a fix *and* a rename is two PRs.
- Never commit secrets, build output or generated projects (`*.xcodeproj` is generated).
- Never force-push a shared branch, and never use `--no-verify`.
- `development` and `main` are protected by rulesets: changes land only through PRs
  (squash into `development`, merge commits into `main`), with the CI checks green and
  every review thread resolved.

## If something goes wrong

**Committed to `development` or `main` by accident, not pushed:**
```bash
git branch fix/my-change && git reset --hard origin/development && git switch fix/my-change
```

**Already pushed to a shared branch:** stop and tell a maintainer. Rewriting
shared history causes worse problems than the original mistake.
