# M1.5 — Everyday use

| Task | Status | PR |
|---|---|---|
| add-anywhere — ⌘V in the window, drag and drop | done | orpheus-ui/danny#31 |
| clipboard-toast — ask before adding a copied link | done | orpheus-ui/danny#36 |
| finished-items — Quick Look, hover actions, open on double-click | done | orpheus-ui/danny#43 |
| keyboard — select, remove and retry from the keyboard | not started | — |
| system — Dock progress, notification when a download finishes | done | orpheus-ui/danny#41 |
| failures — plain-language errors with one suggested fix | done | orpheus-ui/danny#39 |
| grouping — active first, then Today and Earlier | not started | — |
| menu-bar — progress and paste-to-download in the menu bar | not started | — |
| organizing — folder per site, filename templates | done | orpheus-ui/danny#40 |
| network — Wi-Fi only, speed limit | not started | — |
| settings-layout — Settings in tabs | not started | — |

M1 makes Danny look right; this milestone makes the common paths shorter. Each
task is one PR, built in the M1 visual language and checked against the
resource budget (ADR-008): nothing here polls, and every animation is one-shot.

## Order and why

1. **add-anywhere** — adding a link is the most frequent action, so it gets
   faster first. ⌘V with no text field focused adds the clipboard's link (⌘⇧V
   already does this from the menu). Dropping a link, a `.webloc` or text with a
   link onto the window adds it; while something is dragged over, the list shows
   one glass drop highlight.
2. **clipboard-toast** — with clipboard watching on, a copied link no longer
   starts downloading silently. A small glass toast above the bottom bar offers
   it ("Download youtube.com/…?" with Return to accept), and fades after a few
   seconds. Settings choose ask (default), add at once, or off. This also replaces
   the watcher's 0.6 s timer with a check when Danny becomes active, closing that
   backlog item.
3. **finished-items** — Space opens Quick Look on the selected finished video;
   double-click opens it; hovering a card shows Reveal in Finder, Copy Link and
   Play. Hover actions are drawn only on hover, never for every card at rest.
4. **keyboard** — arrow keys move a selection through the list, ⌫ removes,
   ⌘R retries a failed item, Return opens a finished one. Selection is shown by
   the card's stroke, not a new surface.
5. **system** — the Dock icon shows overall progress while anything downloads
   (updated at most once a second), and a notification says when a download
   finishes, with Show in Finder. Notification permission is asked the first
   time a download finishes, not at launch.
6. **failures** — yt-dlp's error output is mapped to a short reason and one
   action: sign-in required → Browser Capture; unavailable or private → no
   retry offered; network → Retry; unsupported site → Browser Capture. The raw
   output stays one click away for bug reports. The mapping is a pure function
   with tests, built from real error lines.
7. **grouping** — active items first, then Today and Earlier, with small section
   headers. Sorting still applies inside each group.
8. **menu-bar** — an optional menu-bar item: a ring that fills with overall
   progress, the active items, and Paste to Download. Off by default.
9. **organizing** — Settings keep the download folder; a new option saves into
   a subfolder per site (`Downloads/youtube.com/…`), off by default. Filename
   templates offer a few presets (title; title and site; date and title) mapped
   to yt-dlp output templates, with a preview of the name.
10. **network** — "Download only on Wi-Fi" waits on cellular or tethered links
    (path changes are observed, not polled), and a speed limit passes
    `--limit-rate` to yt-dlp.
11. **settings-layout** — last, once the tasks above have added their settings,
    so nothing moves twice. Settings become tabs: General (with "Send to
    Danny"), Downloads, Quality, Network, Sources, Engine & Updates (the layout
    in `docs/backlog.md`). Rows move; no setting is added or removed.

## Done when

- Each task is merged with tests for its logic (filter, mapping, templates,
  drop parsing) and before/after screenshots for its UI.
- Idle Danny still uses 0% CPU and has under one wakeup per second.

## Open

- Whether the menu-bar item and the Dock progress should both exist by default.
  Both are built; Settings decide.
