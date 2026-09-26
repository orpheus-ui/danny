#!/bin/bash
# Bundles yt-dlp and ffmpeg into Resources/bin so they ship inside Danny.app.
# Optional: Danny also finds yt-dlp/ffmpeg installed via Homebrew at runtime.
set -euo pipefail
cd "$(dirname "$0")/../Resources/bin"

echo "→ Downloading yt-dlp (universal macOS binary)…"
curl -fL --progress-bar -o yt-dlp \
  https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos
chmod +x yt-dlp

echo "→ Downloading ffmpeg (static build from evermeet.cx)…"
curl -fL --progress-bar -o ffmpeg.zip https://evermeet.cx/ffmpeg/get/ffmpeg/zip
unzip -oq ffmpeg.zip && rm ffmpeg.zip
chmod +x ffmpeg

echo "✓ Bundled:"
ls -la
echo
echo "Note: ffmpeg is LGPL-licensed. If you redistribute builds of Danny, review"
echo "https://www.ffmpeg.org/legal.html — or skip bundling and ask users to"
echo "`brew install yt-dlp ffmpeg` instead."
