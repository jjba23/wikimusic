#!/usr/bin/env bash
# Regenerate the WikiMusic showcase GIF.
#
#   contrib/showcase/run.sh                 # record, encode, install
#   contrib/showcase/run.sh --dry-run       # screenshots at each beat, no GIF
#   contrib/showcase/run.sh --no-install    # keep the GIF under out/
#
# The demo instance, Xvfb and Chrome are all throw-away and are stopped when
# this script exits.  See README.org next to this file for the requirements
# and for what the recording walks through.
set -euo pipefail

# >/dev/null: a CDPATH in the environment makes `cd` print the directory,
# which would turn $here into two lines.
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)
repo=$(cd -- "$here/../.." >/dev/null && pwd)

demo=${DEMO:-/tmp/wikimusic-showcase-demo}
out=${OUT:-"$here/out"}
port=${PORT:-50051}
cdp_port=${CDP_PORT:-9222}
display=${DISPLAY_NUM:-99}
view_width=${VIEW_WIDTH:-1440}
view_height=${VIEW_HEIGHT:-900}
gif_width=${WIDTH:-1000}
gif_fps=${FPS:-9}
gif_quality=${QUALITY:-90}
gif_lossy=${LOSSY:-80}
install=1
dry=0
offline=()

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
}

while [ "$#" -gt 0 ]; do
  case $1 in
    --install) install=1 ;;
    --no-install) install=0 ;;
    --dry-run) dry=1 ;;
    --offline) offline=(--offline) ;;
    -h|--help) usage; exit 0 ;;
    *) echo "run.sh: unknown option $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

die() { echo "run.sh: $*" >&2; exit 1; }

for tool in python3 node npm ffmpeg curl setsid; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is required"
done
python3 -c 'import requests, PIL' 2>/dev/null \
  || die "python3 needs requests and Pillow (python3 -m pip install --user requests pillow)"
[ -f "$repo/wikimusic.db" ] \
  || die "$repo/wikimusic.db is missing; run 'maak init-db' and seed the instance first"

chrome=${CHROME:-}
if [ -z "$chrome" ]; then
  for candidate in google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$candidate" >/dev/null 2>&1; then
      chrome=$(command -v "$candidate")
      break
    fi
  done
fi
[ -n "$chrome" ] || die "Google Chrome or Chromium is required (set CHROME=/path/to/chrome)"

xvfb=()
if command -v Xvfb >/dev/null 2>&1; then
  xvfb=(Xvfb)
elif command -v guix >/dev/null 2>&1; then
  xvfb=(guix shell xorg-server -- Xvfb)
else
  die "Xvfb is required (or Guix, to borrow it from xorg-server)"
fi

server=()
if command -v art >/dev/null 2>&1; then
  server=(art work)
elif command -v guix >/dev/null 2>&1; then
  server=(guix shell -m "$repo/manifest.scm" -- art work)
else
  die "the Artanis server ('art') is required, or Guix and manifest.scm"
fi

python3 - "$port" "$cdp_port" <<'PY'
import socket, sys
for value in sys.argv[1:]:
    port = int(value)
    probe = socket.socket()
    try:
        probe.bind(("127.0.0.1", port))
    except OSError:
        sys.exit(f"port {port} is already in use")
    finally:
        probe.close()
PY

mkdir -p "$out"
if [ ! -d "$here/node_modules/playwright-core" ]; then
  echo "run.sh: installing playwright-core"
  (cd "$here" && npm install --no-audit --no-fund)
fi

echo "run.sh: building the demo instance"
python3 "$here/build_demo.py" --repo "$repo" --demo "$demo" --port "$port" \
  ${offline[@]+"${offline[@]}"}

profile=$(mktemp -d "${TMPDIR:-/tmp}/wikimusic-showcase-chrome.XXXXXX")
server_pid=
chrome_pid=
xvfb_pid=

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  set +e
  if [ -n "$chrome_pid" ]; then kill -- -"$chrome_pid" 2>/dev/null; fi
  if [ -n "$server_pid" ]; then kill -- -"$server_pid" 2>/dev/null; fi
  if [ -n "$xvfb_pid" ]; then kill "$xvfb_pid" 2>/dev/null; fi
  wait 2>/dev/null
  rm -rf "$profile"
  exit "$status"
}
trap cleanup EXIT INT TERM

if [ -e "/tmp/.X11-unix/X$display" ]; then
  die "display :$display is already in use; set DISPLAY_NUM to a free one"
fi
echo "run.sh: starting Xvfb on :$display"
"${xvfb[@]}" ":$display" -screen 0 "${view_width}x${view_height}x24" \
  -nolisten tcp >"$out/xvfb.log" 2>&1 &
xvfb_pid=$!

# The demo instance has symlinks for everything but its own database,
# pictures and conf, and runs from its own directory.
echo "run.sh: starting the demo server on port $port"
setsid bash -c "cd $(printf '%q' "$demo") && exec $(printf '%q ' "${server[@]}")" \
  >"$out/server.log" 2>&1 &
server_pid=$!

base="http://localhost:$port"
for _ in $(seq 1 240); do
  if curl -fsS -o /dev/null --max-time 2 "$base/"; then
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    echo "run.sh: the demo server exited; see $out/server.log" >&2
    tail -20 "$out/server.log" >&2
    exit 1
  fi
  sleep 1
done
curl -fsS -o /dev/null --max-time 2 "$base/" \
  || die "the demo server did not answer on $base; see $out/server.log"

echo "run.sh: starting Chrome"
setsid "$chrome" \
  --kiosk --window-size="${view_width},${view_height}" \
  --window-position=0,0 --force-device-scale-factor=1 \
  --no-first-run --no-default-browser-check --disable-infobars \
  --disable-features=Translate,TranslateUI --disable-translate --lang=en-US \
  --ozone-platform=x11 --disable-gpu --disable-dev-shm-usage \
  --disable-session-crashed-bubble \
  --user-data-dir="$profile" --remote-debugging-port="$cdp_port" \
  "$base/" >"$out/chrome.log" 2>&1 &
chrome_pid=$!

for _ in $(seq 1 120); do
  if curl -fsS -o /dev/null --max-time 2 \
      "http://127.0.0.1:$cdp_port/json/version"; then
    break
  fi
  if ! kill -0 "$chrome_pid" 2>/dev/null; then
    echo "run.sh: Chrome exited; see $out/chrome.log" >&2
    tail -20 "$out/chrome.log" >&2
    exit 1
  fi
  sleep 0.5
done
curl -fsS -o /dev/null --max-time 2 \
  "http://127.0.0.1:$cdp_port/json/version" \
  || die "Chrome's debugging port did not open; see $out/chrome.log"

record=(
  BASE="$base"
  OUT="$out"
  SHOWCASE="$demo/showcase.json"
  DISPLAY=":$display"
  X11_DISPLAY=":$display.0"
  WIDTH="$view_width"
  HEIGHT="$view_height"
  CDP_PORT="$cdp_port"
)
if [ "$dry" = 1 ]; then
  record+=(DRY=1 SHOTS=1)
fi

echo "run.sh: recording"
env "${record[@]}" node "$here/record.js"

if [ "$dry" = 1 ]; then
  echo "run.sh: dry run finished; screenshots are in $out/check"
  exit 0
fi

echo "run.sh: encoding"
WIDTH="$gif_width" FPS="$gif_fps" QUALITY="$gif_quality" LOSSY="$gif_lossy" \
  "$here/encode.sh" "$out/capture.mkv" "$out/wikimusic-demo.gif"

if [ "$install" = 1 ]; then
  cp -- "$out/wikimusic-demo.gif" "$repo/pub/img/wikimusic-demo.gif"
  echo "run.sh: installed pub/img/wikimusic-demo.gif"
else
  echo "run.sh: left the GIF at $out/wikimusic-demo.gif (--no-install)"
fi

echo "run.sh: done.  If the beats changed, update the figure's caption in README.org."
