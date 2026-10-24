# Engineering

How we work. Short on purpose — if a rule here isn't pulling its weight, delete it.
Branches and PRs: [CONTRIBUTING.md](../CONTRIBUTING.md).

## Toolchain

- **Xcode 26+**, Swift 6 language mode, macOS 26 SDK.
- **XcodeGen** — `project.yml` is the source of truth; `Danny.xcodeproj` is generated and not committed.
- **SwiftFormat** formats, **SwiftLint** catches the rest. Both run in CI.
- **SwiftFormat is pinned to 0.63.1**, in the Makefile (`SWIFTFORMAT_VERSION`, checked by `make lint`) and in CI (the GitHub release zip, checksum-verified). Newer releases reformat this code, so they fail the lint. Homebrew installs the latest, so use the pinned release: `brew switch swiftformat 0.63.1` if Homebrew still has it, or the release zip from the [SwiftFormat releases](https://github.com/nicklockwood/SwiftFormat/releases/tag/0.63.1) on your `PATH`. Move the pin in both places, in one PR, after checking `make format` on the new version.
- Tools install with `make bootstrap` (Homebrew, `Brewfile`).

| Command | Does |
|---|---|
| `make bootstrap` | first time: tools, git hooks, asset catalog, Xcode project |
| `make run` | build and launch the app |
| `make format` | format all Swift code |
| `make lint` | format check + lint, strict — what CI runs |
| `make test` | unit tests |
| `make check` | lint + test — run before you push |

## Two rules that outrank convenience

### 1. Danny is light

A downloader lives in the background for hours. It must cost ~nothing while idle
and very little while downloading.

- **Nothing runs while idle.** No repeating timers, polling or animations when
  nothing is happening. Prefer notifications/observation over polling; when
  polling is unavoidable, stop it when the feature is off and set a timer tolerance.
- **Animate only what is changing**, cap custom animation at 30 fps, and stop it
  when the window is hidden or occluded.
- **GPU over CPU for effects** — draw effects like the progress bar's texture
  with a Metal shader (`.colorEffect`/`.layerEffect`), not stacks of views.
- **Throttle updates from child processes** to what the eye can see (a few per second).
- **Measure it.** A change that adds animation, timers, polling or background
  work states its idle CPU in the PR (Activity Monitor or Instruments). Target:
  0.0% idle, low single digits while downloading.

### 2. Clean as you go

Structure, architecture and code stay clean — improved **gradually**, not by
big-bang rewrites.

- Leave every file you touch a little cleaner than you found it (in a separate
  commit when the cleanup is more than trivial).
- Debt you find but don't fix goes into [backlog.md](backlog.md) §Debt with a
  file reference, so it is visible and can be picked up as its own PR.
- A lint waiver (`swiftlint:disable`) says why and when it goes away.
- Dependencies point one way: views → core → system. See [architecture.md](architecture.md).

## Code

- **Match the file you're in.** One type per file where practical; files under ~400 lines.
- **Concurrency:** UI state is `@MainActor`; process and file work runs off it
  (`@concurrent`). Never block a cooperative thread (`waitUntilExit`, semaphores).
- **Don't swallow errors.** Handle them, or let them reach a boundary that
  reports them to the user. `try?` needs a reason.
- **Validate at boundaries** — anything from a child process, a web page or the
  clipboard is untrusted input.
- **Design values come from `D`** (`Sources/UI/DesignSystem.swift`), which mirrors
  the Figma file. No new hardcoded colors in views.
- **New dependency?** Say why in the PR; prefer what the platform gives us.

## Tests

- Swift Testing (`import Testing`) in `Tests/DannyTests/`, one file per type under test.
- New behavior ships with tests. A bug fix starts with a test that fails on the old code.
- Tests leave nothing on the machine: temporary folders and settings come from
  `TestScratch`, which removes them, and nothing opens Finder or uses the Trash.
- Pure logic (parsers, formatters, the queue) gets unit tests; UI states get
  snapshot tests from M1.
- The bundled ffmpeg has its own check: `scripts/check-ffmpeg.sh` runs the commands
  yt-dlp gives ffmpeg on the synthetic files in `Tests/Fixtures/media`, and every
  build must pass it (ADR-013). Something new asked of ffmpeg gets a case there.

## Keep the machine cool

`xcodebuild` uses every core. Run one heavy thing at a time, prefer `make test`
over repeated clean builds, and never delete DerivedData to "fix" something
before you know what's wrong.

## Definition of done

1. `make check` passes locally; CI is green.
2. New behavior has tests.
3. UI changes match the Figma design and show before/after screenshots in the PR.
4. The two rules above hold — resource use measured when relevant; touched code cleaner.
5. Docs that describe changed behavior are updated in the same PR.
