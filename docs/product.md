# Product

## What Danny is

A native macOS download manager for video. Paste a link, watch clean live
progress, get a file. Inspired by Downie; open source.

Three things make it Danny:

1. **Downloads from almost anywhere** — yt-dlp's 1000+ extractors today, more
   through plugins, Browser Capture for sites nothing can extract, and an opt-in
   AI plugin that works out new sites with a model the user picks (M4).
2. **Torrents with streaming** — add a magnet or `.torrent` and start watching
   while it downloads (M3).
3. **Pluggable** — anyone can write an extractor or engine plugin in any
   language, without touching the app (M2).

## Who it's for

People on a Mac who save videos to watch offline, archive, edit or share — and
want a tool that looks and feels like it belongs on macOS, not a terminal.

## Principles

- **Native and beautiful.** SwiftUI and Liquid Glass on macOS 26; the Figma
  design is the spec, not a suggestion.
- **Light.** Idle means zero CPU. A downloader that spins fans is broken
  ([engineering.md](engineering.md) §Danny is light).
- **Private.** No accounts, no telemetry. Nothing leaves the Mac except the
  requests needed to fetch what you asked for — and, only after the user agrees,
  page details sent to the AI provider they chose. Local models come first.
- **Honest.** Danny downloads; it doesn't host, index or break DRM. Users are
  responsible for respecting copyright and site terms (README §Legal).

## Not doing

- DRM circumvention.
- A cloud service, accounts or sync.
- Windows or Linux builds.
