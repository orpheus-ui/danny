#!/bin/bash
# Bundles yt-dlp, QuickJS-ng, ffmpeg and ffprobe into Resources/bin so they ship inside
# Danny.app. yt-dlp and QuickJS-ng are pinned and checksum-verified; ffmpeg and ffprobe are built from pinned,
# verified source by scripts/build-ffmpeg.sh (LGPL). Either way a release contains
# exactly what was reviewed. Without bundling, Danny finds yt-dlp/ffmpeg from
# Homebrew at runtime (`brew install yt-dlp ffmpeg`).
#
# Bumping: change the version + hashes (here, or in build-ffmpeg.sh) in their own PR.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/Resources/bin"

# yt-dlp — universal2 macOS build, verified against yt-dlp's SHA2-256SUMS.
YTDLP_VERSION="${YTDLP_VERSION:-2026.08.19}"
# QuickJS-ng — the JavaScript runtime yt-dlp solves YouTube's challenges with (ADR-016).
# Its releases publish no checksums, so the hashes are pinned here when bumping.
QJS_VERSION="v0.17.0"
QJS_SHA256_ARM64="8be3ddfe3397d2e692e4e1e8972ee9d032a0a580505d2f8b4ea528cf1b651c11"
QJS_SHA256_X86_64="9e5e101b4fd13cda3204222ca9f8be35412c41dcdef3745829633b7a67245412"

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
# Read at launch to pick the newer of this and the copy Danny keeps current.
echo "$YTDLP_VERSION" > yt-dlp.version

echo "→ QuickJS-ng $QJS_VERSION"
base="https://github.com/quickjs-ng/quickjs/releases/download/$QJS_VERSION"
curl -fsSL -o "$WORK/qjs-arm64" "$base/qjs-darwin-arm64"
curl -fsSL -o "$WORK/qjs-x86_64" "$base/qjs-darwin-x86_64"
verify "$WORK/qjs-arm64" "$QJS_SHA256_ARM64"
verify "$WORK/qjs-x86_64" "$QJS_SHA256_X86_64"
lipo -create "$WORK/qjs-arm64" "$WORK/qjs-x86_64" -output "$WORK/qjs"
install -m 755 "$WORK/qjs" qjs

echo "→ ffmpeg and ffprobe, built from source"
ffmpeg_build=$("$ROOT/scripts/build-ffmpeg.sh" | tail -1)
install -m 755 "$ffmpeg_build/bin/ffmpeg" "$ffmpeg_build/bin/ffprobe" .
# The LGPL travels with the binaries: its text, and where their source is.
rm -rf licenses && mkdir licenses
cp "$ffmpeg_build"/licenses/* licenses/
cp "$ffmpeg_build/BUILD-INFO.txt" licenses/ffmpeg-BUILD-INFO.txt
curl -fsSL -o licenses/quickjs-ng-LICENSE.txt \
  "https://raw.githubusercontent.com/quickjs-ng/quickjs/$QJS_VERSION/LICENSE"

echo "✓ Bundled into Resources/bin:"
for tool in yt-dlp qjs ffmpeg ffprobe; do
  printf '  %-7s %-13s %s\n' "$tool" "$(lipo -archs "$tool")" "$(du -h "$tool" | cut -f1)"
done
