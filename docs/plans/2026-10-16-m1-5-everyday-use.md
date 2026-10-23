# M1.5 — Everyday use

| Task | Status | PR |
|---|---|---|
| add-anywhere — ⌘V in the window, drag and drop | done | orpheus-ui/danny#31 |
| clipboard-toast — ask before adding a copied link | done | orpheus-ui/danny#36 |
| finished-items — Quick Look, hover actions, open on double-click | done | orpheus-ui/danny#43 |
| keyboard — select, remove and retry from the keyboard | not started | — |
| system — Dock progress, notification when a download finishes | done | orpheus-ui/danny#41 |
| failures — plain-language errors with one suggested fix | done | orpheus-ui/danny#39 |
| grouping — active first, then Today and Earlier | done | orpheus-ui/danny#52 |
| menu-bar — progress and paste-to-download in the menu bar | done | orpheus-ui/danny#47 |
| organizing — folder per site, filename templates | done | orpheus-ui/danny#40 |
| network — Wi-Fi only, speed limit | done | orpheus-ui/danny#44 |
| settings-layout — Settings in tabs | done | — |
| pause-resume — pause and resume a download, Pause All, survives quit | in progress | — |

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
8. **menu-bar** — an optional menu-bar item, off by default: the Danny mark that
   fills from the bottom with overall progress, with the percentage beside it. Its
   popover (system glass) shows a headline and speed, an add row for the clipboard's
   link or a typed one, up to four active downloads (click shows the card in the
   window), the last three finished files (click opens, draggable), and quick
   toggles for the speed limit and Wi-Fi only. It exists only while open.
9. **organizing** — Settings keep the download folder; a new option saves into
   a subfolder per site (`Downloads/youtube.com/…`), off by default. Filename
   templates offer a few presets (title; title and site; date and title) mapped
   to yt-dlp output templates, with a preview of the name.
10. **network** — "Download only on Wi-Fi" waits on cellular or tethered links
    (path changes are observed, not polled). Speed modes (Full Speed,
    Balanced at 5 MB/s, Background at 1 MB/s, the two limits editable in
    Settings → Network) pass `--limit-rate` to yt-dlp for downloads that start
    after the change.
11. **settings-layout** — last, once the tasks above have added their settings,
    so nothing moves twice. Settings become tabs: General (with "Send to
    Danny"), Downloads, Quality, Network, Sources, Engine & Updates (the layout
    in `docs/backlog.md`). Rows move; no setting is added or removed.
12. **pause-resume** — a Pause chip on a running card's bar (drawn on hover)
    stops its yt-dlp but keeps the `.part` files, which yt-dlp continues on the
    next run; the paused bar is dimmed with "Paused · 59%" and a Resume chip.
    While anything runs, an activity pill beside Sort shows the count and total
    speed (`↓ 2 · 4 MB/s`) and opens Pause All / Resume All, the speed mode
    and Download only on Wi-Fi; with everything paused it reads `Paused · 3`
    with a Resume button. At idle there's no pill. ⌥⌘P in the Download menu
    pauses or resumes all.
    Paused cards stay paused across a quit; cards that were running when Danny
    quit start again on launch. Cancel now stops a card for good and deletes its
    partial files, as Remove does.

## Done when

- Each task is merged with tests for its logic (filter, mapping, templates,
  drop parsing) and before/after screenshots for its UI.
- Idle Danny still uses 0% CPU and has under one wakeup per second.

## Open

- Whether the menu-bar item and the Dock progress should both exist by default.
  Both are built; Settings decide. The menu-bar item ships off by default; the
  Dock progress is always on.
