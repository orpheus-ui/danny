#!/bin/bash
# Bundles yt-dlp and ffmpeg into Resources/bin so they ship inside Danny.app.
# Versions are pinned and every download is checksum-verified, so a release
# always contains exactly what was reviewed. Without bundling, Danny finds
# yt-dlp/ffmpeg from Homebrew at runtime (`brew install yt-dlp ffmpeg`).
#
# Bumping: change the version + hashes below in their own PR.
set -euo pipefail
cd "$(dirname "$0")/../Resources/bin"

# yt-dlp — universal2 macOS build, verified against yt-dlp's SHA2-256SUMS.
YTDLP_VERSION="${YTDLP_VERSION:-2026.08.19}"

# ffmpeg — native static builds per architecture (ffmpeg.martin-riedl.de),
# combined into one universal binary. The source publishes no checksums, so
# the hashes are pinned here.
FFMPEG_VERSION="9.0.2"
FFMPEG_ARM64_URL="https://ffmpeg.martin-riedl.de/download/macos/arm64/1789931890_9.0.2/ffmpeg.zip"
FFMPEG_ARM64_SHA256="c8ed4c4e6978a03c485edbfe4e0a5dc2380f8a30bba5150531b31b094492d924"
FFMPEG_X86_URL="https://ffmpeg.martin-riedl.de/download/macos/amd64/1789931006_9.0.2/ffmpeg.zip"
FFMPEG_X86_SHA256="7c6b4125b191cbf773832dc51f424cf2b6bb7da43007d1e066f95909e47cacd4"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

verify() { # verify <file> <sha256>
  echo "$2  $1" | shasum -a 256 -c - >/dev/null || {
    echo "✗ Checksum mismatch for $1 — refusing to bundle it." >&2
    exit 1
  }
}

echo "→ yt-dlp $YTDLP_VERSION"
base="https://github.com/yt-dlp/yt-dlp/releases/download/$YTDLP_VERSION"
curl -fsSL -o "$WORK/yt-dlp_macos" "$base/yt-dlp_macos"
curl -fsSL -o "$WORK/SHA2-256SUMS" "$base/SHA2-256SUMS"
verify "$WORK/yt-dlp_macos" "$(awk '$2 == "yt-dlp_macos" { print $1 }' "$WORK/SHA2-256SUMS")"
install -m 755 "$WORK/yt-dlp_macos" yt-dlp

echo "→ ffmpeg $FFMPEG_VERSION (arm64 + x86_64)"
curl -fsSL -o "$WORK/ffmpeg-arm64.zip" "$FFMPEG_ARM64_URL"
verify "$WORK/ffmpeg-arm64.zip" "$FFMPEG_ARM64_SHA256"
curl -fsSL -o "$WORK/ffmpeg-x86_64.zip" "$FFMPEG_X86_URL"
verify "$WORK/ffmpeg-x86_64.zip" "$FFMPEG_X86_SHA256"
unzip -oq "$WORK/ffmpeg-arm64.zip" -d "$WORK/arm64"
unzip -oq "$WORK/ffmpeg-x86_64.zip" -d "$WORK/x86_64"
lipo -create "$WORK/arm64/ffmpeg" "$WORK/x86_64/ffmpeg" -output ffmpeg
chmod 755 ffmpeg

echo "✓ Bundled into Resources/bin:"
for tool in yt-dlp ffmpeg; do
  printf '  %-7s %s\n' "$tool" "$(lipo -archs "$tool")"
done
echo
echo "ffmpeg's license applies to redistributed builds: https://www.ffmpeg.org/legal.html"
