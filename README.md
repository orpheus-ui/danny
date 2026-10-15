# Danny — video downloader for macOS

Danny is an open-source video downloader for macOS, inspired by [Downie](https://software.charliemonroe.net/downie/). Paste a link from YouTube, X, Instagram, or thousands of other sites, watch the live progress, done. For stubborn sites, Danny's built-in **Browser Capture** watches network traffic while you browse and hands you every video file and HLS stream it detects.

![Danny main window](docs/screenshots/main.png)

## Features

- **Downloads from anywhere** — powered by [yt-dlp](https://github.com/yt-dlp/yt-dlp): YouTube, X/Twitter, Instagram, TikTok, Vimeo, and 1000+ extractors
- **Browser Capture** — a built-in browser that sniffs network traffic, `<video>` elements, HLS (`m3u8`) and DASH (`mpd`) manifests while you browse. Every detected stream appears in the sidebar with a one-click **+** to download
- **Live progress** — percentage and real-time speed on a liquid-glass progress bar

![Downloading state](docs/screenshots/states.png)
- **Smart queue** — configurable concurrent downloads, retry, cancel, per-item actions
- **Clipboard-friendly** — paste from the `+` menu, or enable clipboard watching in Settings
- **Persistent history** — the queue survives relaunches
- **Native & private** — SwiftUI + Liquid Glass, no telemetry, no accounts, nothing leaves your machine except the video request itself

## Install

Download the latest DMG from [Releases](https://github.com/orpheus-ui/danny/releases),
open it and drag Danny to Applications. yt-dlp and ffmpeg are included.

Early (0.x) builds aren't notarized yet, so macOS blocks the first launch: open Danny
once, then **System Settings → Privacy & Security → Open Anyway**
([details](docs/releasing.md#installing-an-unsigned-build)).
Homebrew is on the way: `brew install --cask orpheus-ui/tap/danny`.

## Requirements

- macOS 26 Tahoe or newer — Danny is built on Liquid Glass
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) and [ffmpeg](https://ffmpeg.org) for downloading and merging streams
- Xcode 26 to build from source, with its Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`)

## Build

```bash
make bootstrap   # tools (Homebrew), git hooks, asset catalog, Xcode project
make run         # build and launch
```

`make help` lists every command; `open Danny.xcodeproj` works too once it's generated.

### Dependencies

Danny looks for `yt-dlp` and `ffmpeg` in this order:

1. **Bundled** in `Danny.app/Contents/Resources/bin` — run `./scripts/fetch-dependencies.sh` before building to include them (it builds ffmpeg from source the first time, which takes a few minutes)
2. **Homebrew**: `brew install yt-dlp ffmpeg` (`/opt/homebrew/bin`, `/usr/local/bin`)
3. Anything on your `PATH`

> `yt-dlp` is public domain (Unlicense). The bundled `ffmpeg` and `ffprobe` are an LGPL build made from source by `scripts/build-ffmpeg.sh`; their license texts ship in `Danny.app/Contents/Resources/bin/licenses`, and each GitHub Release carries the exact source archives. The title font, Space Grotesk, is bundled under the SIL Open Font License; its license text ships in `Danny.app/Contents/Resources/Fonts`.

## Usage

- **`+`** — paste a link from the clipboard or type a URL
- **⌘⇧V** — paste and download from anywhere
- **Browser Capture** (globe icon or ⌘⇧B) — for sites where extraction fails. Browse, play the video, then pick the stream from the sidebar. The first launch asks for your consent
- **Settings › Accounts** — sign in to YouTube, Instagram, X, Facebook or any site you add, so downloads work as you. Sign-in happens on the site's own page in Danny's browser
- **⌘N** — enter a URL manually · **⌘, ** — settings (save folder, concurrency, clipboard watching)

## Contributing

Bug fixes, design polish and (from M2) plugins are welcome — start with
[CONTRIBUTING.md](CONTRIBUTING.md). What's planned: [docs/roadmap.md](docs/roadmap.md).

## Legal

Danny is a download manager — it doesn't host, index, or bypass DRM for any content. You are responsible for respecting copyright and each site's terms of service. Not affiliated with YouTube, X, Instagram, or Downie.

## License

[MIT](LICENSE) — copyright © 2026 Danny contributors
