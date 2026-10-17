# Architecture

How the pieces fit today, and where they are heading. Why they're shaped this
way: [decisions.md](decisions.md).

## Today (M0)

One SwiftUI app target, generated from `project.yml` by XcodeGen.

```
Sources/
  DannyApp.swift        app entry, windows (main, Browser Capture, Settings), menu commands
  Models/               DownloadItem, its Status and SortOrder
  Services/
    DownloadManager     the queue: add/pause/resume/cancel/retry/remove, concurrency, runs downloads
    YTDLPClient         runs yt-dlp as a child process, parses its progress output
    DownloadEngine      what the manager asks of yt-dlp; tests pass a fake
    ExistingFiles       finds an earlier download of the same video in the folder
    SystemProxy         the macOS proxy as `--proxy`, read when a yt-dlp run starts
    YTDLPUpdater        at launch, installs the latest verified yt-dlp in Application Support
    PersistenceStore    history.json in ~/Library/Application Support/Danny
    AppSettings         UserDefaults-backed settings
    ClipboardWatcher    offers a copied link when Danny becomes active
    LinkIntake          finds the link in pasted or dropped text, URLs and .webloc files
    SystemStatus        Dock progress (≤1 update/s) and a notification per finished download
  Sniffer/              Browser Capture — a WKWebView that reports media URLs it sees
  Views/                main window, card, progress bar, title/bottom bars, settings
  UI/                   design tokens (`D`), glass effects, pill buttons, formatters
Tests/DannyTests/       Swift Testing unit tests
```

### A download, end to end

1. A URL arrives — `+` menu, ⌘⇧V, the clipboard watcher, or Browser Capture.
2. `DownloadManager.add` queues a `DownloadItem` and `pump()` starts it when a slot is free.
3. `YTDLPClient.probe` runs `yt-dlp -J` for title, size, resolution and thumbnail.
4. Before downloading, `ExistingFiles` looks for a file of the same video and kind
   (video or audio) by its `[id]`. Depending on the card's answer or the setting, the
   old file goes to the Trash, the new one is named `… [id] (2).ext`, or the card
   ends on the file already there. yt-dlp's "has already been downloaded" line
   leads to the same question when the check misses a file.
5. `YTDLPClient.downloadStream` runs yt-dlp with a progress template and streams
   `DownloadEvent`s (progress, output file) back to the manager, which updates the item.
6. Pausing stops yt-dlp and keeps the partial files; Resume queues the card and
   yt-dlp continues them. Cancelling or removing an unfinished card deletes its
   partial files (`.part`, merge parts) once yt-dlp has stopped; finished files are
   never touched.
7. The item becomes `.finished` or `.failed`; history is saved (debounced) to `history.json`.
   At launch, paused cards stay paused and cards that were running are queued again.

Browser Capture injects a script into the page that reports every media URL it
sees (`<video>` sources, network requests matching media patterns) through a
`WKScriptMessageHandler`; `SnifferStore` classifies them as HLS, DASH or file.

### State

`DownloadManager` is `@Observable` and `@MainActor`; views read it through the
environment. yt-dlp runs off the main actor (`@concurrent`) and reports back
through an `AsyncThrowingStream`.

Every yt-dlp run is pinned to the bundled QuickJS-ng (`Binaries.runtimeArguments`,
ADR-016), which yt-dlp needs to read YouTube's player. When the first try is refused,
the retry asks for other YouTube clients: iOS when signed out, `tv` and `mweb` when
signed in, because yt-dlp drops clients that can't send cookies.

YouTube links go signed out first (`SignInSite.signsInOnlyWhenAsked`): YouTube serves
some signed-in accounts only SABR streams, which yt-dlp can't read, so those
accounts would get 360p. The session's cookies are used when the probe says the
link needs a sign-in (age-restricted, members-only, private).

## Where it's heading

| Milestone | Change |
|---|---|
| M1 | A shader-drawn progress bar and a card that match the Figma design; UI state tests |
| M2 | `DannyCore` Swift package (queue, engine, persistence — no SwiftUI) and an out-of-process **plugin protocol**; yt-dlp becomes the first plugin |
| M3 | Torrents through a helper process, streamed while downloading, played with libmpv |

Target shape after M2:

```
Danny (app)       SwiftUI views only — reads DannyCore, never runs processes itself
DannyCore         queue, download engine, persistence, plugin host
Plugins           separate executables speaking JSON over stdin/stdout (docs/plugins.md, M2)
```

Rule for the split: **views don't start processes or touch the file system; the
core doesn't import SwiftUI.**
