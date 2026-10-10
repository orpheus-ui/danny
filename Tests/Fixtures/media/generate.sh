#!/bin/bash
# Regenerates the media fixtures that scripts/check-ffmpeg.sh runs the bundled
# ffmpeg against. Everything comes from ffmpeg's built-in test sources (testsrc2,
# sine), so the files are tiny, synthetic and free of third-party content.
#
# Needs an ffmpeg with libx264, libx265, libvpx, libsvtav1 and libopus (Homebrew's
# has them) and cwebp (`brew install webp`). The bundled build can't make these:
# it carries no video encoders.
set -euo pipefail
cd "$(dirname "$0")"

ff() { ffmpeg -hide_banner -loglevel error -y "$@"; }
picture=(-f lavfi -i "testsrc2=size=160x90:rate=15:duration=2")
tone() { echo "sine=frequency=440:sample_rate=$1:duration=2"; }

# What sites serve as separate streams for yt-dlp to merge: DASH video-only
# (H.264 and AV1 in MP4, VP9 in WebM) and audio-only (AAC in M4A, Opus in WebM).
# A keyframe every second, like real segmented streams.
ff "${picture[@]}" -pix_fmt yuv420p -c:v libx264 -crf 35 -g 15 video-h264.mp4
SVT_LOG=1 ff "${picture[@]}" -pix_fmt yuv420p -c:v libsvtav1 -preset 12 -crf 50 -g 15 video-av1.mp4
ff "${picture[@]}" -pix_fmt yuv420p -c:v libvpx-vp9 -b:v 50k -g 15 video-vp9.webm
ff -f lavfi -i "$(tone 44100)" -c:a aac -b:a 32k audio-aac.m4a
ff -f lavfi -i "$(tone 48000)" -c:a libopus -b:a 24k audio-opus.webm

# HLS segments: H.264 or HEVC, with ADTS AAC, in MPEG-TS.
ff "${picture[@]}" -f lavfi -i "$(tone 44100)" -pix_fmt yuv420p -c:v libx264 -crf 35 -g 15 \
  -c:a aac -b:a 32k -f mpegts hls-segment.ts
ff "${picture[@]}" -f lavfi -i "$(tone 44100)" -pix_fmt yuv420p -c:v libx265 -crf 35 -g 15 \
  -x265-params log-level=error -c:a aac -b:a 32k -f mpegts hls-segment-hevc.ts

# A thumbnail as sites serve them.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
ff -f lavfi -i "testsrc2=size=160x90" -frames:v 1 "$work/thumbnail.png"
cwebp -quiet -q 80 "$work/thumbnail.png" -o thumbnail.webp

cat > subtitles.vtt <<'EOF'
WEBVTT

00:00:00.000 --> 00:00:01.000
First line

00:00:01.000 --> 00:00:02.000
Second line
EOF

ls -l
