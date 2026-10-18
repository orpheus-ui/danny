# Backlog

What's missing, known-broken or worth cleaning. **Nothing here outranks
[roadmap.md](roadmap.md)** — this is a menu, not a plan. Pick an item, make it
its own PR, delete it from here when it merges.

## Gaps — security

- **yt-dlp updates aren't signature-checked.** `YTDLPUpdater` verifies the binary
  against the release's `SHA2-256SUMS`, which comes from the same release. Check
  `SHA2-256SUMS.sig` against yt-dlp's public key, bundled with Danny, before
  running or installing the download (ADR-015). Needs an OpenPGP verifier that
  doesn't require GnuPG on the user's Mac.

## Debt — resource use

- **Every progress line re-renders the list.** Each yt-dlp progress event mutates
  `DownloadManager.items`, so every card observes every change. Throttle updates
  and observe per item. (`DownloadManager.downloadPhase`)
- **`visibleItems` filters and sorts on every read** from the view body. Cache it
  and recompute when items, query or sort order change. (`DownloadManager.visibleItems`)
- **Idle wakeups.** An empty, hidden window still wakes ~4 times a second (~15 before the clipboard timer went)
  (budget: under 1), and ~30 with six cards — no animation runs then, so it's
  timers or observation. Profile with `/perf-check` §4.

## Debt — structure

- **`DownloadManager` does too much**: queue, process orchestration, persistence,
  Finder reveal and a YouTube-specific retry (`player_client=ios`). Split in M2:
  queue and engine into `DannyCore`, site-specific retries into the extractor plugin.
- **`YTDLPClient.runDownload` blocks a cooperative thread** with
  `process.waitUntilExit()`, and has a complexity waiver. Use a termination
  continuation; split parsing from process handling. (M2)
- **Small dead code:** `_ = existing` in `DownloadManager.add`; unused `url`
  parameter in `DownloadManager.hinted`.
- **The signed-out-then-signed-in retry has no manager test.** `DownloadEngine` now
  lets tests fake yt-dlp; a test still needs a stand-in for `SiteSessions` to check
  that a probe asking for a sign-in is retried with cookies.
- **User-facing strings are hardcoded.** Move to a String Catalog before any localization.

## Missing

- **YouTube tokens (PO tokens).** When YouTube serves an account only its newer
  streaming format (SABR), yt-dlp is left with the 360p file. A token from YouTube's
  BotGuard restores the normal streams. The common provider (bgutil) needs Node or
  Deno; minting the token in a hidden `WKWebView` needs neither and uses WebKit
  Danny already has.
- **Say when quality falls short.** If the best format is below the chosen quality,
  the card should say so instead of quietly downloading 360p.
- **Clear the web cache.** Browser Capture and sign-in fill
  `~/Library/Caches/app.danny.desktop/WebKit` (tens of MB) and nothing bounds or
  clears it. Add a "Clear Cache" button in Settings that removes cached web data
  but keeps sign-ins (`WKWebsiteDataStore.removeData` with cache types only).
- **UI snapshot tests** for every card state (M1).
- **Resume after a settings change.** A resumed card recomputes its folder, filename
  and format from the current settings, so after a change while it was paused yt-dlp
  starts over instead of continuing the `.part` files, which stay behind. Keep the
  started run's destination and format on the item and reuse them on Resume.
- **App size.** The bundled tools are most of the app: yt-dlp's PyInstaller binary
  (37 MB, universal), and ffmpeg and ffprobe at 17 MB each now that they're built
  for Danny (ADR-013; the old static ffmpeg alone was 161 MB). Options: download
  yt-dlp on first run instead of bundling it (it's updated separately anyway,
  roadmap M2), or one copy of the ffmpeg libraries shared by both tools instead of
  two static ones.

## Settings and features

Settings stay small: General (with "Send to Danny"), Downloads, Quality, Network,
Sources, Engine & Updates. A choice most people can't answer gets a good default,
not a switch.

- **Keep the Mac awake while downloading.** A power assertion held only while a
  download runs, released when the queue is idle.
- **Embed thumbnail, chapters and metadata** in the file by default, instead of
  sidecar JSON or JPEG files.
- **Clear history after** a day / week / month / never; a card whose file was
  deleted from disk shows it as missing.
- **Hide the Dock icon**, only while the menu-bar item is on.
- **Audio track language** (M4): pick dubbed tracks by the Mac's preferred
  languages, with a per-download override.
- **Proxy auto-config (PAC) and bypass list:** the system proxy is passed to yt-dlp only
  when it is a fixed HTTPS, HTTP or SOCKS proxy; a PAC script, auto-discovery and the
  "bypass these hosts" list are not followed.
- **Proxies that need a password:** with "Proxy server requires password" on, Danny
  passes the proxy without credentials, so it answers 407. Read the password from the
  Keychain (internet password for the proxy host and port, which asks permission once)
  and hand it to yt-dlp through the environment rather than the command line, where
  `ps` would show it.
- **Pause the queue on low disk space** and say why on the cards.
- **Record live streams** (M4) with `--live-from-start`.
- **Back off when a site rate-limits** (HTTP 429, bot checks): wait and retry the
  queue instead of failing every card, with no delay setting.
- **Concurrent fragments stepper:** the default of 8 (`--concurrent-fragments`)
  ships; still to do is a 1–16 stepper under Network → Advanced. It only speeds up streams that come in
  fragments (DASH, HLS); single-file downloads use one connection either way. More
  than about 8 adds little and invites rate limits.
- **Global speed limit on the main screen:** a pill in the bottom bar shows total
  speed; clicking it sets a limit (off / presets / custom). yt-dlp's `-r` is per
  process and fixed for a run, so the limit is split across active downloads and
  they restart (resuming from `.part`) when it or their number changes. Needs a
  Figma state.
- **Danny's own sounds:** short original "done" and "failed" sounds played with
  the notification; setting Danny / System / None. Needs the sound design.
- **Sources pane** (M2+): every way media is fetched is a source plugin — yt-dlp,
  torrents (M3), AI extraction (M4), third-party plugins — each with on/off,
  version, "Update now" and permissions. A "Does this site work?" box takes a URL
  and names the source that handles it. Per source: yt-dlp has site sign-ins,
  Clear Cache and the supported-site list; AI has the provider, ask-before-sending
  and saved site recipes (deletable, exportable); torrents have port, upload limit,
  seed ratio and stream-while-downloading. Ways links arrive (clipboard, Share
  menu, Services, `danny://`, extensions) live in General → Send to Danny.
- **Search:** text instead of a URL searches. Built-in yt-dlp searches (YouTube,
  SoundCloud) to switch on; custom search sites as a name plus URL template
  (`https://site.com/search?q=%s`) opened in Browser Capture; plugins (M2) can add
  searches with result cards.
- **Custom ffmpeg:** Engine row "Bundled · Use another… · Reset"; the chosen binary
  is checked with `-version` before use, with a fallback to the bundled one.
- **App updates** (M5): Sparkle with EdDSA-signed updates; "Check automatically"
  and "Install automatically" on by default, plus "Check now". Installs on quit or
  when idle, never during a download.
- **Browser extensions** (last): Safari, Chrome-family and Firefox extensions that
  send the page's link, and optionally its cookies, to Danny.
