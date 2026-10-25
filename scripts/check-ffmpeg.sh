#!/bin/bash
# Checks that an ffmpeg build can do what Danny and yt-dlp ask of it, before it
# is bundled. Each case runs the kind of command yt-dlp's post-processors and
# its ffmpeg downloader run, on the synthetic files in Tests/Fixtures/media
# (generate.sh there remakes them), and checks the result with ffprobe.
#
#   scripts/check-ffmpeg.sh <dir with ffmpeg and ffprobe>
#
# scripts/build-ffmpeg.sh runs it on every build it hands out. Output is
# captured before it is matched: with pipefail, `cmd | grep -q` can fail (or
# pass) on SIGPIPE instead of on what cmd printed.
set -euo pipefail
cd "$(dirname "$0")/.."

dir="${1:?usage: $0 <dir with ffmpeg and ffprobe>}"
FFMPEG="$dir/ffmpeg"
FFPROBE="$dir/ffprobe"
MEDIA="$PWD/Tests/Fixtures/media"
DEPLOYMENT_TARGET=$(sed -n 's/^ *MACOSX_DEPLOYMENT_TARGET: "\(.*\)"$/\1/p' project.yml | head -1)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failures=0
ok() { echo "  ✓ $1" >&2; }
fail() {
  echo "  ✗ $1" >&2
  failures=$((failures + 1))
}
check() { # check <what> <command…> — passes when the command succeeds; else shows its first line
  local what="$1" output
  shift
  if output=$("$@" 2>&1); then ok "$what"; else fail "$what${output:+ — $(head -1 <<< "$output")}"; fi
}

# streams <file> — "type:codec" for each top-level stream, e.g. "video:h264 audio:aac".
# The flat format keeps MPEG-TS program streams (programs.…) apart from these.
streams() {
  local flat
  flat=$("$FFPROBE" -v error -show_entries stream=codec_type,codec_name -of flat "$1") || return 1
  awk -F'[.=]' '/^streams\.stream\./ {
      gsub(/"/, "", $5)
      if ($4 == "codec_name") name[$3] = $5; else type[$3] = $5
      if ($3 + 1 > n) n = $3 + 1
    }
    END { for (i = 0; i < n; i++) printf "%s%s:%s", (i ? " " : ""), type[i], name[i] }' <<< "$flat"
}

# expect <what> <output file> <streams> <ffmpeg arguments before the output…>
expect() {
  local what="$1" out="$WORK/$2" want="$3" got
  shift 3
  if ! "$FFMPEG" -nostdin -hide_banner -loglevel error -y "$@" "$out" 2> "$WORK/error.log"; then
    fail "$what — ffmpeg failed:"
    sed 's/^/      /' "$WORK/error.log" >&2
    return
  fi
  if ! got=$(streams "$out" 2> "$WORK/error.log"); then
    fail "$what — unreadable output: $(tail -1 "$WORK/error.log")"
    return
  fi
  if [ "$got" = "$want" ]; then ok "$what"; else fail "$what — got \"$got\", want \"$want\""; fi
}

echo "→ Checking $FFMPEG" >&2

# The binaries themselves.
universal() {
  local archs
  archs=$(lipo -archs "$1") && [[ $archs == *arm64* && $archs == *x86_64* ]]
}
version_le() { [ "$(printf '%s\n%s' "$1" "$2" | sort -V)" = "$(printf '%s\n%s' "$1" "$2")" ]; }
runs_on_target() { # every slice's minimum macOS is at most the app's deployment target
  local arch minos
  for arch in arm64 x86_64; do
    minos=$(otool -arch "$arch" -l "$1" | awk '$1 == "minos" { m = $2 } END { print m }') || return 1
    [ -n "$minos" ] && version_le "$minos" "$DEPLOYMENT_TARGET" || return 1
  done
}
system_libraries_only() { # prints the libraries outside /usr/lib and /System/Library
  local libraries others
  libraries=$(otool -L "$1") || return 1
  # Dependencies are the indented lines; universal binaries add a header per architecture.
  others=$(awk '/^[[:space:]]/ && $1 !~ /^\/(usr\/lib|System\/Library)\// { print $1 }' <<< "$libraries" | sort -u)
  [ -z "$others" ] || { echo "links" $others; return 1; }
}
rosetta() { arch -x86_64 /usr/bin/true 2> /dev/null; }
intel_slice_runs() { arch -x86_64 "$1" -hide_banner -version > /dev/null; }
lgpl() {
  local license config
  license=$("$FFMPEG" -hide_banner -L) && config=$("$FFMPEG" -hide_banner -buildconf) || return 1
  grep -q "Lesser General Public License" <<< "$license" && ! grep -qE -- "--enable-(gpl|nonfree)" <<< "$config"
}
for tool in "$FFMPEG" "$FFPROBE"; do
  name=$(basename "$tool")
  check "$name is universal (arm64 + x86_64)" universal "$tool"
  check "$name runs on macOS $DEPLOYMENT_TARGET" runs_on_target "$tool"
  check "$name links only system libraries" system_libraries_only "$tool"
  if rosetta; then check "$name's x86_64 slice runs (Rosetta)" intel_slice_runs "$tool"; fi
done
check "licensed LGPL, without GPL or nonfree parts" lgpl

# What yt-dlp reads before using ffmpeg: the version line, the bitstream filters
# it switches on (setts, aac_adtstoasc), and ffprobe's JSON.
probes() {
  local version bsfs json
  version=$("$FFMPEG" -version) && bsfs=$("$FFMPEG" -hide_banner -bsfs) \
    && json=$("$FFPROBE" -v error -print_format json -show_format -show_streams "$MEDIA/video-h264.mp4") \
    || return 1
  [[ $version == "ffmpeg version "* ]] && grep -qx setts <<< "$bsfs" && grep -qx aac_adtstoasc <<< "$bsfs" \
    && grep -q '"codec_name": "h264"' <<< "$json"
}
check "answers yt-dlp's probes" probes

# yt-dlp hands live HLS, and streams its native downloader can't handle, to
# ffmpeg, which then fetches over HTTPS itself.
network() {
  local protocols demuxers p
  protocols=$("$FFMPEG" -hide_banner -protocols) && demuxers=$("$FFMPEG" -hide_banner -demuxers) || return 1
  for p in file http https tcp tls crypto; do grep -qx "  $p" <<< "$protocols" || return 1; done
  grep -qE '^ D +hls ' <<< "$demuxers"
}
check "reads http, https and HLS (yt-dlp's ffmpeg downloader)" network

# Merging separate video and audio, as yt-dlp's merger does (-f bv*+ba).
merge=(-c copy -map 0:v:0 -map 1:a:0 -movflags +faststart)
expect "merge H.264 + AAC into MP4" merged.mp4 "video:h264 audio:aac" \
  -i "$MEDIA/video-h264.mp4" -i "$MEDIA/audio-aac.m4a" "${merge[@]}"
expect "merge AV1 + Opus into MP4" merged-av1.mp4 "video:av1 audio:opus" \
  -i "$MEDIA/video-av1.mp4" -i "$MEDIA/audio-opus.webm" "${merge[@]}"
expect "merge VP9 + Opus into MP4" merged-vp9.mp4 "video:vp9 audio:opus" \
  -i "$MEDIA/video-vp9.webm" -i "$MEDIA/audio-opus.webm" "${merge[@]}"
expect "merge VP9 + Opus into WebM" merged.webm "video:vp9 audio:opus" \
  -i "$MEDIA/video-vp9.webm" -i "$MEDIA/audio-opus.webm" -c copy -map 0:v:0 -map 1:a:0
expect "merge H.264 + AAC into MKV" merged.mkv "video:h264 audio:aac" \
  -i "$MEDIA/video-h264.mp4" -i "$MEDIA/audio-aac.m4a" -c copy -map 0:v:0 -map 1:a:0

# HLS: the fixup after yt-dlp's native downloader, then ffmpeg as the downloader.
copy=(-map 0 -dn -ignore_unknown -c copy)
expect "fix up HLS (MPEG-TS into MP4, aac_adtstoasc)" fixed.mp4 "video:h264 audio:aac" \
  -i "$MEDIA/hls-segment.ts" "${copy[@]}" -f mp4 -bsf:a aac_adtstoasc -movflags +faststart
expect "fix up HEVC HLS (MPEG-TS into MP4)" fixed-hevc.mp4 "video:hevc audio:aac" \
  -i "$MEDIA/hls-segment-hevc.ts" "${copy[@]}" -f mp4 -bsf:a aac_adtstoasc -movflags +faststart
cp "$MEDIA/hls-segment.ts" "$WORK/segment0.ts"
printf '%s\n' "#EXTM3U" "#EXT-X-VERSION:3" "#EXT-X-TARGETDURATION:3" "#EXT-X-MEDIA-SEQUENCE:0" \
  "#EXTINF:2.0," "segment0.ts" "#EXT-X-ENDLIST" > "$WORK/playlist.m3u8"
expect "download HLS into MPEG-TS (live streams)" live.ts "video:h264 audio:aac" \
  -i "$WORK/playlist.m3u8" -c copy -f mpegts
expect "download HLS into MP4" downloaded.mp4 "video:h264 audio:aac" \
  -i "$WORK/playlist.m3u8" -c copy -f mp4 -bsf:a aac_adtstoasc
cp "$MEDIA/hls-segment-hevc.ts" "$WORK/segment0-hevc.ts"
sed 's/segment0\.ts/segment0-hevc.ts/' "$WORK/playlist.m3u8" > "$WORK/playlist-hevc.m3u8"
expect "download HEVC HLS into MP4" downloaded-hevc.mp4 "video:hevc audio:aac" \
  -i "$WORK/playlist-hevc.m3u8" -c copy -f mp4 -bsf:a aac_adtstoasc

# Thumbnails: converted for embedding (PNG) or on request (JPEG).
thumbnail=(-f image2 -pattern_type none -i "$MEDIA/thumbnail.webp" -update 1)
expect "convert a WebP thumbnail to PNG" thumbnail.png "video:png" "${thumbnail[@]}"
expect "convert a WebP thumbnail to JPEG" thumbnail.jpg "video:mjpeg" "${thumbnail[@]}" -bsf:v mjpeg2jpeg

# Audio extraction (-x), at yt-dlp's default quality.
expect "extract audio to MP3 (LAME)" audio.mp3 "audio:mp3" \
  -i "$MEDIA/audio-opus.webm" -vn -acodec libmp3lame -q:a 5.0
expect "extract audio to M4A (AAC)" audio.m4a "audio:aac" \
  -i "$MEDIA/audio-opus.webm" -vn -acodec aac -q:a 2.05 -bsf:a aac_adtstoasc
expect "extract AAC without re-encoding" copied.m4a "audio:aac" \
  -i "$WORK/merged.mp4" -vn -acodec copy -bsf:a aac_adtstoasc

# Subtitles, metadata and chapters, and the timestamp fixup.
expect "embed WebVTT subtitles into MP4" subtitled.mp4 "video:h264 audio:aac subtitle:mov_text" \
  -i "$WORK/merged.mp4" -i "$MEDIA/subtitles.vtt" "${copy[@]}" -c:s mov_text \
  -map -0:s -map 1:0 -metadata:s:s:0 language=eng
expect "convert WebVTT subtitles to SRT" subtitles.srt "subtitle:subrip" \
  -i "$MEDIA/subtitles.vtt" -f srt
printf '%s\n' ";FFMETADATA1" "[CHAPTER]" "TIMEBASE=1/1000" "START=0" "END=1000" "title=Opening" \
  > "$WORK/chapters.meta"
# MP4 chapters come with a QuickTime chapter track (bin_data), as in yt-dlp's output.
expect "write metadata and chapters" tagged.mp4 "video:h264 audio:aac data:bin_data" \
  -i "$WORK/merged.mp4" -i "$WORK/chapters.meta" "${copy[@]}" -map_metadata 1 -metadata title=Fixture
tagged() {
  local title chapters
  title=$("$FFPROBE" -v error -show_entries format_tags=title -of csv=p=0 "$WORK/tagged.mp4") \
    && chapters=$("$FFPROBE" -v error -show_chapters -of csv=p=0 "$WORK/tagged.mp4") || return 1
  [ "$title" = Fixture ] && [ "$(grep -c . <<< "$chapters")" = 1 ]
}
check "  … and read them back" tagged
expect "fix up timestamps (setts)" retimed.mp4 "video:h264 audio:aac" \
  -i "$WORK/merged.mp4" -c copy -bsf setts=ts=TS-STARTPTS -map 0 -dn -ignore_unknown -ss 0.001

if [ "$failures" -gt 0 ]; then
  echo "✗ $failures check(s) failed — this ffmpeg can't be bundled." >&2
  exit 1
fi
echo "✓ ffmpeg can do everything Danny and yt-dlp need" >&2
