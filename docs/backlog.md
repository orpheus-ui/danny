# Backlog

What's missing, known-broken or worth cleaning. **Nothing here outranks
[roadmap.md](roadmap.md)** — this is a menu, not a plan. Pick an item, make it
its own PR, delete it from here when it merges.

## Debt — resource use

- **Clipboard timer runs forever.** `ClipboardWatcher.start()` is called on launch
  and polls every 0.6 s even when clipboard watching is off; `poll()` checks the
  setting only after waking. Start/stop the timer with the setting, add a tolerance.
  (`Sources/Services/ClipboardWatcher.swift`, `MainWindow.task`)
- **Every progress line re-renders the list.** Each yt-dlp progress event mutates
  `DownloadManager.items`, so every card observes every change. Throttle updates
  and observe per item. (`DownloadManager.downloadPhase`)
- **`visibleItems` filters and sorts on every read** from the view body. Cache it
  and recompute when items, query or sort order change. (`DownloadManager.visibleItems`)
- **Processing animation** uses a 20 fps `TimelineView` with no pause when the
  window is hidden. Replaced by the M1 progress bar. (`ProgressBarView.ProcessingCapsule`)

## Debt — structure

- **`DownloadManager` does too much**: queue, process orchestration, persistence,
  Finder reveal and a YouTube-specific retry (`player_client=ios`). Split in M2:
  queue and engine into `DannyCore`, site-specific retries into the extractor plugin.
- **`YTDLPClient.runDownload` blocks a cooperative thread** with
  `process.waitUntilExit()`, and has a complexity waiver. Use a termination
  continuation; split parsing from process handling. (M2)
- **Swift 6 isolation warnings** in `MediaSnifferWebView`: the popup handler reads
  main-actor properties from a `nonisolated` method; `decidePolicyFor` never
  matches WebKit's signature and only allows everything — delete it.
- **Small dead code:** `_ = existing` in `DownloadManager.add`; unused `url`
  parameter in `DownloadManager.hinted`; `if manager.add(url:) {}` in `ClipboardWatcher.poll`.
- **User-facing strings are hardcoded.** Move to a String Catalog before any localization.

## Missing

- **yt-dlp updates.** Sites change weekly; Danny should keep its yt-dlp current
  (bundled copy + update check) instead of asking users to run `brew upgrade`.
- **Pause/resume** of a download (needs the M1 Paused state and engine support).
- **UI snapshot tests** for every card state (M1).
- **App size.** The bundled tools are most of the app: yt-dlp's PyInstaller binary
  (37 MB, universal), and ffmpeg and ffprobe at 17 MB each now that they're built
  for Danny (ADR-013; the old static ffmpeg alone was 161 MB). Options: download
  yt-dlp on first run instead of bundling it (it needs updating weekly anyway, see
  above), or one copy of the ffmpeg libraries shared by both tools instead of two
  static ones.
