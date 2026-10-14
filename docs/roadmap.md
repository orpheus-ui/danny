# Roadmap

Milestones are sequential. `docs/roadmap.md` says *what* and *in which order*;
a plan in [plans/](plans/) says *how* for anything bigger than a PR.

**Current milestone: M0 — Foundation.**

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

The Figma file is the spec. Plan: `plans/` (written when M1 starts).

- [ ] Design tokens from Figma into `D` (colors, gradients, radii, type)
- [ ] **Progress bar rebuilt**: Metal shader for gradient + dot texture, centered
      two-tone label, smooth eased progress, idle-free animation (ADR-008)
- [ ] Card: full-bleed thumbnail with scrim, title/meta/actions per Figma
- [ ] Title bar and bottom bar per Figma
- [ ] Missing states designed and built: Queued, Fetching, Merging, Paused, Failed, empty list
- [ ] Snapshot tests for every card state
- [ ] Resource debt from `backlog.md` that touches the UI (clipboard timer, list re-renders)

## M2 — Clean core and plugins

- [ ] `DannyCore` Swift package: queue, engine, persistence — no SwiftUI
- [ ] Plugin protocol: out-of-process, JSON over stdin/stdout (ADR-004); `docs/plugins.md`
- [ ] yt-dlp as plugin #1; site-specific retries move into it
- [ ] Plugin discovery, install and permissions UI
- [ ] Managed yt-dlp updates

## M3 — Torrents and streaming

- [ ] Engine spike: librqbit vs anacrolix/torrent as a helper process (ADR-006)
- [ ] Magnet links and `.torrent` files in the same queue
- [ ] Sequential download + local HTTP stream while downloading
- [ ] Player on libmpv (MPVKit) — plays MKV/HEVC and friends (ADR-005)

## M4 — Release

- [x] Release pipeline: universal build, hardened-runtime signing, notarization,
      DMG + zip, checksums, changelog and draft GitHub Release (docs/releasing.md)
- [x] Bundled yt-dlp and ffmpeg pinned and checksum-verified; ffmpeg native universal
- [ ] Signed and notarized releases — signing secrets configured (ADR-010)
- [ ] Sparkle auto-updates with an EdDSA-signed appcast
- [ ] Homebrew tap `orpheus-ui/homebrew-tap`, bumped by the release workflow (ADR-011)
- [ ] Official `homebrew/cask` once notarized and notable
- [ ] `v1.0.0`
