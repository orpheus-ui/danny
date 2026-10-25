# Roadmap

`docs/roadmap.md` says *what* and *in which order*; a plan in [plans/](plans/) says *how*
for anything bigger than a PR.

## Releases

Milestones keep their numbers; releases group them. Within a release, milestones run
in the order listed.

| Release | Milestones | Headline |
|---|---|---|
| `v0.1.0` preview | released 2026-10-25 | First public build, ad-hoc signed |
| `v1.0.0` | rest of M1 → M4 (v1.0 part) → M5 | The video downloader, finished |
| `v1.1.0` | M3 | Torrents you watch while they download |
| `v2.0.0` | M2 → rest of M4 | Plugins: any site, any file type, AI extraction |

### What leads v1.0

The release notes and README open with these. New in v1.0:

1. **Follow a channel.** Channels and playlists you follow fetch their new episodes
   when Danny opens.
2. **Audio mode.** Podcasts and music as MP3 or M4A, with cover art and chapters.
3. **Skip the sponsor.** SponsorBlock segments skipped or marked as chapters;
   subtitles saved next to the video.
4. **Send to Danny from anywhere.** Share menu, Services, Shortcuts and `danny://` links.

Already true, and said every time:

- **Downloads from almost anywhere:** yt-dlp's 1000+ sites, and Browser Capture
  (with an ad blocker and sign-in) for the rest.
- **Light:** nothing runs while idle; the progress bar is a Metal shader.
- **At home on macOS:** Liquid Glass, menu-bar item, Quick Look, Dock progress, keyboard.
- **Private:** no accounts, no telemetry.

**Current release: `v1.0.0`. Current milestone: M1 — Match the design.**

---

## M0 — Foundation

- [x] First version imported; `development` → `main` branch model
- [x] SwiftFormat + SwiftLint, codebase clean on both
- [x] Unit-test target (Swift Testing) with first tests
- [x] `make` targets, Brewfile, pre-push hook, PR template
- [x] CI: lint + tests on macOS runners, Conventional Commit PR titles
- [x] Docs: product, roadmap, decisions, architecture, engineering, backlog, contributing
- [x] macOS 26 baseline — deployment target raised, `#available` fallbacks removed (ADR-002)
- [x] GitHub: rulesets on `main` and `development` (PRs only, required checks, resolved threads), `development` as default branch

## M1 — Match the design

The Figma file is the spec. Plan: [plans/2026-10-14-m1-match-the-design.md](plans/2026-10-14-m1-match-the-design.md).

- [x] Design tokens from Figma into `D` (colors, gradients, radii, type)
- [x] **Progress bar rebuilt**: Metal shader for gradient + dot texture, centered
      two-tone label, smooth eased progress, idle-free animation (ADR-008)
- [x] Card: full-bleed thumbnail with scrim, title/meta/actions per Figma
- [x] Title bar and bottom bar per Figma
- [x] Missing states designed and built: Queued, Fetching, Merging, Paused, Failed, empty list
- [ ] Snapshot tests for every card state
- [ ] Resource debt from `backlog.md` that touches the UI (clipboard timer, list re-renders)
- [x] Search that finds and adds: one glass field, scope chips, paste a link to download

## M1.5 — Everyday use (done)

Shorter paths for the things done every day. Plan: [plans/2026-10-16-m1-5-everyday-use.md](plans/2026-10-16-m1-5-everyday-use.md).

- [x] ⌘V in the window and drag and drop add links
- [x] Clipboard toast asks before adding a copied link; no clipboard timer
- [x] Finished items: Quick Look (Space), double-click to open, hover actions
- [x] Keyboard: arrows select, ⌫ removes, ⌘R retries, Return opens
- [x] Dock progress and a notification when a download finishes
- [x] Plain-language failures with one suggested fix
- [x] List grouped: active first, then Today and Earlier
- [x] Optional menu-bar item with progress and Paste to Download
- [x] Optional folder per site inside the download folder; filename templates
- [x] Download only on Wi-Fi; speed limit
- [x] Settings in tabs: General, Downloads, Quality, Network, Sources, Engine & Updates
- [x] Pause and resume a download, Pause All (⌥⌘P); paused cards survive a quit
- [x] yt-dlp kept current: checked each time Danny opens, verified against yt-dlp's
      published checksums, used from the next download on (ADR-015)

## M4 — Smarter downloads (v1.0, then v2.0)

### For v1.0

- [ ] Audio-only downloads (podcasts, music): MP3, M4A or the original audio, with
      cover art and chapters
- [ ] Format and quality presets in Settings (max resolution, codec, container,
      audio bitrate), with a per-download override
- [ ] Playlists and channels: pick what to download; follow a channel and fetch new
      episodes when Danny opens
- [ ] Subtitles, chapters and SponsorBlock segments (skip or mark)
- [ ] Download a section: start/end time, without fetching the whole video
- [ ] Send to Danny from anywhere: Share menu, Services, Shortcuts and a
      `danny://` URL scheme

### For v2.0 (needs the plugin protocol from M2)

- [ ] AI-assisted extraction plugin for sites yt-dlp doesn't support:
  - providers the user chooses: local models (Ollama, LM Studio), OpenRouter,
    CheaperInference — local first, nothing sent anywhere without the user's say
  - asks before each new site: shows what will be sent and to which provider; no
    automatic switch to a cloud provider, ever
  - the model only proposes; Danny validates a candidate (media type, origin)
    before downloading, and saves a working approach so the site needs no AI next time
  - DRM-protected streams are detected and declined, not attempted

## M5 — Release (v1.0)

- [x] Release pipeline: universal build, hardened-runtime signing, notarization,
      DMG + zip, checksums, changelog and draft GitHub Release (docs/releasing.md)
- [x] Bundled yt-dlp and ffmpeg pinned and checksum-verified; ffmpeg native universal
- [x] Bundled ffmpeg built from source: LGPL only, checked against yt-dlp's commands on every build (ADR-013)
- [x] `v0.1.0` preview from `development`, ad-hoc signed (docs/releasing.md)
- [ ] Signed and notarized releases — signing secrets configured (ADR-010)
- [ ] Sparkle auto-updates with an EdDSA-signed appcast
- [ ] Homebrew tap `orpheus-ui/homebrew-tap`, bumped by the release workflow (ADR-011)
- [ ] `v1.0.0`
- [ ] Official `homebrew/cask` once notarized and notable (after v1.0; not a gate)

## M3 — Torrents and streaming (v1.1)

- [ ] Engine spike: librqbit vs anacrolix/torrent as a helper process (ADR-006)
- [ ] Magnet links and `.torrent` files in the same queue
- [ ] Sequential download + local HTTP stream while downloading
- [ ] Player on libmpv (MPVKit) — plays MKV/HEVC and friends (ADR-005)

## M2 — Clean core and plugins (v2.0)

- [ ] `DannyCore` Swift package: queue, engine, persistence — no SwiftUI
- [ ] Plugin protocol: out-of-process, JSON over stdin/stdout (ADR-004); `docs/plugins.md`.
      Media-agnostic from the start: a plugin returns files with a type (video, audio,
      image, document…), not "a video with formats", so non-video plugins need no
      protocol change later. The item model and card follow the same shape.
- [ ] yt-dlp as plugin #1; site-specific workarounds leave the app and live in plugins
- [ ] Plugin discovery, install and permissions UI
- [ ] Native HTTP engine (engine plugin #2): plain files (PDF, ZIP, DMG, images,
      direct MP4) download without yt-dlp, split into byte ranges over several
      connections. Each range resumes and retries on its own. The connection count is
      automatic: it starts at 4, grows while throughput rises, and backs off on
      throttling or HTTP 429. yt-dlp keeps site extraction and can hand resolved URLs
      to this engine. The speed limit is shared across downloads and changes live.
- [ ] Lanes on the progress bar: while a file downloads in ranges, the shader draws
      one thin lane per connection, each filling at its own pace, merging into one
      bar when done. The details line reads "48 MB of 210 · 6 connections · 12 MB/s".
      Figma state first.
