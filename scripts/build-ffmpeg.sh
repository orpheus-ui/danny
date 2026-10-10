#!/bin/bash
# Builds the ffmpeg and ffprobe that ship inside Danny.app, from pinned source.
#
# LGPL-2.1 only: no --enable-gpl, no --enable-nonfree, no GPL libraries. The build
# starts from --disable-everything and enables just what Danny and yt-dlp use:
#   - merging separate video/audio streams and changing containers (stream copy)
#   - HLS/DASH fixups (aac_adtstoasc and friends)
#   - audio extraction to MP3 (LAME) and M4A (ffmpeg's AAC encoder, which yt-dlp uses)
#   - thumbnail conversion (PNG needs zlib, from macOS), metadata, subtitles
#   - fetching HLS over HTTP(S) when yt-dlp hands a stream to ffmpeg (live streams,
#     playlists its native downloader can't read). TLS is macOS's Secure Transport,
#     so there is no TLS library to bundle or keep patched.
# Before a build is handed out, scripts/check-ffmpeg.sh runs each of these on
# Tests/Fixtures/media and checks the license.
#
# Output: build/deps/ffmpeg-<key>/{bin/ffmpeg,bin/ffprobe,licenses/,BUILD-INFO.txt}
# where <key> changes whenever this script does, so CI can cache on it.
# Prints the output directory on its last line. Bump versions in their own PR.
set -euo pipefail
cd "$(dirname "$0")/.."

FFMPEG_VERSION="9.0.2"
FFMPEG_URL="https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz"
FFMPEG_SHA256="8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e"
LAME_VERSION="3.100"
LAME_URL="https://downloads.sourceforge.net/project/lame/lame/$LAME_VERSION/lame-$LAME_VERSION.tar.gz"
LAME_SHA256="ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e"
MACOS_MIN="26.0" # project.yml's MACOSX_DEPLOYMENT_TARGET; check-ffmpeg.sh holds them together
ARCHS=(arm64 x86_64)

# Compiler and SDK from the same Xcode, always: a bare `cc` can pick up a newer
# Command Line Tools SDK whose libraries this Xcode's linker can't read.
CLANG="$(xcrun --sdk macosx -f clang)"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
export SDKROOT

KEY="$FFMPEG_VERSION-lame$LAME_VERSION-$(shasum -a 256 "$0" | cut -c1-12)"
OUT="$PWD/build/deps/ffmpeg-$KEY"
if [ -x "$OUT/bin/ffmpeg" ] && [ -x "$OUT/bin/ffprobe" ]; then
  echo "✓ ffmpeg $KEY already built" >&2
  scripts/check-ffmpeg.sh "$OUT/bin"
  echo "$OUT"
  exit 0
fi

# Local builds use half the cores to keep the machine cool; CI uses all of them.
CORES=$(sysctl -n hw.ncpu)
[ -n "${CI:-}" ] || CORES=$((CORES / 2 > 0 ? CORES / 2 : 1))

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fetch() { # fetch <url> <sha256> <file>
  curl -fsSL -o "$WORK/$3" "$1"
  echo "$2  $WORK/$3" | shasum -a 256 -c - > /dev/null || {
    echo "✗ Checksum mismatch for $3 — refusing to build." >&2
    exit 1
  }
}

echo "→ Sources (ffmpeg $FFMPEG_VERSION, LAME $LAME_VERSION)" >&2
fetch "$FFMPEG_URL" "$FFMPEG_SHA256" ffmpeg.tar.xz
fetch "$LAME_URL" "$LAME_SHA256" lame.tar.gz

# What gets enabled. Each list is the minimum yt-dlp's post-processors and its
# ffmpeg downloader need; add to it deliberately, never switch to a full build.
# The video decoders aren't for decoding: ffmpeg decodes one frame to learn what
# MP4 needs to describe a stream — VP9's profile and pixel format (vpcC), and the
# frame size of H.264 and HEVC that arrive through the HLS demuxer.
DEMUXERS="mov,matroska,mpegts,hls,aac,mp3,ogg,flac,wav,flv,avi,ivf,obu,h264,hevc,m4v,ac3,eac3,webvtt,srt,ass,ffmetadata,concat,image2,image_png_pipe,image_jpeg_pipe,image_webp_pipe,mjpeg"
MUXERS="mp4,ipod,mov,matroska,webm,mpegts,mp3,adts,opus,ogg,flac,wav,ffmetadata,image2,mjpeg,webvtt,srt,ass,null"
PARSERS="aac,aac_latm,h264,hevc,vp8,vp9,av1,opus,vorbis,mpegaudio,flac,ac3,mjpeg,png,webp,mpeg4video"
BSFS="aac_adtstoasc,h264_mp4toannexb,hevc_mp4toannexb,vp9_superframe,vp9_superframe_split,av1_frame_merge,av1_frame_split,extract_extradata,dump_extradata,mjpeg2jpeg,setts,null"
DECODERS="h264,hevc,vp9,aac,aac_fixed,aac_latm,opus,vorbis,mp3,mp3float,mp2,flac,alac,ac3,eac3,pcm_s16le,pcm_s24le,pcm_s32le,pcm_f32le,pcm_u8,webp,mjpeg,png,webvtt,subrip,ass,ssa,movtext"
ENCODERS="libmp3lame,aac,mjpeg,png,webvtt,subrip,ass,ssa,movtext"
FILTERS="aresample,aformat,anull,acopy,null,copy,format,scale,crop"
PROTOCOLS="file,pipe,http,https,httpproxy,tcp,tls,crypto"

# Compiler output goes to a log per step; a failing step prints its tail.
build_arch() { # build_arch <arch> — static LAME, then static ffmpeg + ffprobe
  local arch="$1" host prefix src cross=()
  case "$arch" in
    arm64) host="aarch64-apple-darwin" ;;
    x86_64) host="x86_64-apple-darwin" ;;
  esac
  [ "$arch" = "$(uname -m)" ] || cross=(--enable-cross-compile)
  prefix="$WORK/prefix-$arch"
  local flags="-arch $arch -isysroot $SDKROOT -mmacosx-version-min=$MACOS_MIN -O2"

  echo "→ LAME ($arch)" >&2
  src="$WORK/lame-$arch"
  mkdir -p "$src" && tar -xzf "$WORK/lame.tar.gz" -C "$src" --strip-components 1
  # 3.100's export list names a symbol that no longer exists (as Homebrew patches too).
  sed -i '' '/lame_init_old/d' "$src/include/libmp3lame.sym"
  (cd "$src" && CC="$CLANG" CFLAGS="$flags" LDFLAGS="$flags" ./configure --quiet --host="$host" \
    --prefix="$prefix" --disable-shared --enable-static --disable-frontend \
    --disable-dependency-tracking && make -s -j"$CORES" && make -s install) > "$WORK/lame-$arch.log" 2>&1 \
    || { tail -30 "$WORK/lame-$arch.log" >&2; exit 1; }

  echo "→ ffmpeg ($arch)" >&2
  src="$WORK/ffmpeg-$arch"
  mkdir -p "$src" && tar -xJf "$WORK/ffmpeg.tar.xz" -C "$src" --strip-components 1
  (cd "$src" && ./configure --prefix="$prefix" --arch="$arch" --target-os=darwin ${cross[@]+"${cross[@]}"} \
    --cc="$CLANG -arch $arch" \
    --extra-cflags="-isysroot $SDKROOT -mmacosx-version-min=$MACOS_MIN -I$prefix/include" \
    --extra-ldflags="-isysroot $SDKROOT -mmacosx-version-min=$MACOS_MIN -L$prefix/lib" \
    --disable-everything --disable-autodetect --disable-doc --disable-debug \
    --disable-shared --enable-static --disable-x86asm \
    --disable-ffplay --enable-ffmpeg --enable-ffprobe \
    --enable-avformat --enable-avcodec --enable-avfilter --enable-swresample --enable-swscale \
    --enable-zlib --enable-securetransport --enable-libmp3lame \
    --enable-protocol="$PROTOCOLS" \
    --enable-demuxer="$DEMUXERS" --enable-muxer="$MUXERS" --enable-parser="$PARSERS" \
    --enable-bsf="$BSFS" --enable-decoder="$DECODERS" --enable-encoder="$ENCODERS" \
    --enable-filter="$FILTERS") > "$WORK/ffmpeg-configure-$arch.log" 2>&1 \
    || { tail -30 "$src/ffbuild/config.log" >&2; exit 1; }
  # A misspelled component is only a warning to configure; here it fails the build.
  if grep "did not match anything" "$WORK/ffmpeg-configure-$arch.log" >&2; then exit 1; fi
  (cd "$src" && make -s -j"$CORES" && make -s install) > "$WORK/ffmpeg-$arch.log" 2>&1 \
    || { tail -30 "$WORK/ffmpeg-$arch.log" >&2; exit 1; }
}

for arch in "${ARCHS[@]}"; do build_arch "$arch"; done

# Assembled beside OUT and moved into place only once it passes the checks, so
# an interrupted or failing build is never mistaken for a finished one.
echo "→ Universal binaries" >&2
STAGE="$OUT.partial"
rm -rf "$STAGE" && mkdir -p "$STAGE/bin" "$STAGE/licenses"
for tool in ffmpeg ffprobe; do
  lipo -create "$WORK/prefix-arm64/bin/$tool" "$WORK/prefix-x86_64/bin/$tool" -output "$STAGE/bin/$tool"
  strip -x "$STAGE/bin/$tool"
done

cp "$WORK/ffmpeg-arm64/COPYING.LGPLv2.1" "$STAGE/licenses/ffmpeg-LGPL-2.1.txt"
cp "$WORK/ffmpeg-arm64/LICENSE.md" "$STAGE/licenses/ffmpeg-LICENSE.md"
cp "$WORK/lame-arm64/COPYING" "$STAGE/licenses/lame-LGPL.txt"
{
  echo "ffmpeg $FFMPEG_VERSION and ffprobe, built for Danny — LGPL-2.1-or-later"
  echo
  echo "Corresponding source:"
  echo "  $FFMPEG_URL  (sha256 $FFMPEG_SHA256)"
  echo "  $LAME_URL  (sha256 $LAME_SHA256)"
  echo "Build script: scripts/build-ffmpeg.sh in https://github.com/orpheus-ui/danny"
  echo
  echo "Configuration:"
  "$STAGE/bin/ffmpeg" -hide_banner -buildconf
} > "$STAGE/BUILD-INFO.txt"

scripts/check-ffmpeg.sh "$STAGE/bin"
rm -rf "$OUT" && mv "$STAGE" "$OUT"

echo "✓ ffmpeg $KEY: $(lipo -archs "$OUT/bin/ffmpeg"), $(du -h "$OUT/bin/ffmpeg" | cut -f1) + ffprobe $(du -h "$OUT/bin/ffprobe" | cut -f1), LGPL" >&2
echo "$OUT"
