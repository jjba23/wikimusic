#!/usr/bin/env bash
# Encode a showcase capture into the GIF the README shows.
#
#   encode.sh capture.mkv wikimusic-demo.gif
#
# ffmpeg pulls frames out at the GIF's frame rate, gifski turns them into a
# palette of its own choosing, and gifsicle's lossy pass removes the dithering
# noise the eye does not miss at this size.  Width, frame rate, quality and
# lossiness can be overridden from the environment; run.sh passes them through.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 CAPTURE.mkv OUTPUT.gif" >&2
  exit 2
fi

capture=$1
output=$2
width=${WIDTH:-1000}
fps=${FPS:-9}
quality=${QUALITY:-90}
lossy=${LOSSY:-80}

if [ ! -s "$capture" ]; then
  echo "encode: $capture is missing or empty" >&2
  exit 1
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/wikimusic-showcase-frames.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/frames" "$(dirname "$output")"

# gifski and gifsicle are showcase-only tools, so they are not in the
# project's manifest.  Use them when they are installed, and otherwise borrow
# them from Guix or Nix rather than asking the reader to install anything.
run_tool() {
  local tool=$1
  shift
  if command -v "$tool" >/dev/null 2>&1; then
    "$tool" "$@"
    return
  fi
  # Guix does not carry every tool (gifski, for one), so ask it for the
  # package before handing it the real command.
  if command -v guix >/dev/null 2>&1 \
      && guix shell "$tool" -- "$tool" --version >/dev/null 2>&1; then
    guix shell "$tool" -- "$tool" "$@"
    return
  fi
  if command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p "$tool" --run "$(printf '%q ' "$tool" "$@")"
    return
  fi
  echo "encode: $tool is not installed, and neither Guix nor Nix can lend it" >&2
  exit 1
}

echo "encode: $capture -> $output (${width}px, ${fps}fps, quality ${quality}, lossy ${lossy})"
ffmpeg -y -loglevel error -i "$capture" \
  -vf "fps=${fps},scale=${width}:-2:flags=lanczos" \
  -pix_fmt rgb24 "$work/frames/%04d.png"

run_tool gifski --fps "$fps" --width "$width" --quality "$quality" \
  --output "$work/raw.gif" "$work"/frames/*.png

# --lossy only exists in gifsicle; without it the GIF is still valid, just
# larger.  The CI-less development machine usually has it through Nix.
if [ "$lossy" -gt 0 ] 2>/dev/null; then
  run_tool gifsicle -O3 --lossy="$lossy" --output "$output" "$work/raw.gif"
else
  cp "$work/raw.gif" "$output"
fi

if command -v ffprobe >/dev/null 2>&1; then
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height,duration,nb_frames \
    -of default=noprint_wrappers=1 "$output"
fi
printf 'encode: wrote %s (%s)\n' "$output" \
  "$(du -h "$output" | cut -f1)"
