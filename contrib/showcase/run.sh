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

die() { echo "run.sh: $*" >&2; exit 1; }

demo=${DEMO:-/tmp/wikimusic-showcase-demo}
out=${OUT:-"$here/out"}
# SHOWCASE_* rather than the usual PORT/DISPLAY names: a shell that exports
# PORT=0 or DISPLAY for another program should not silently move the demo.
# Left alone, the ports are picked fresh, so a Chrome still shutting down
# from the previous take cannot block the next one.
free_port() {
  python3 - <<'PY'
import socket
probe = socket.socket()
probe.bind(("127.0.0.1", 0))
print(probe.getsockname()[1])
probe.close()
PY
}

port=${SHOWCASE_PORT:-}
case $port in ''|0) port=$(free_port) ;; esac
cdp_port=${SHOWCASE_CDP_PORT:-}
case $cdp_port in ''|0) cdp_port=$(free_port) ;; esac

if [ -n "${SHOWCASE_DISPLAY:-}" ]; then
  display=$SHOWCASE_DISPLAY
else
  for candidate in 99 100 101 102 103 104 105; do
    if [ ! -e "/tmp/.X11-unix/X$candidate" ] \
        && [ ! -e "/tmp/.X$candidate-lock" ]; then
      display=$candidate
      break
    fi
  done
  [ -n "${display:-}" ] || die "no free X display between :99 and :105; set SHOWCASE_DISPLAY"
fi
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
import socket, sys, time

# A Chrome from a previous take can hold its debugging port for a moment
# after being told to quit, so give the sockets a few seconds to clear.
deadline = time.time() + 10
for value in sys.argv[1:]:
    port = int(value)
    while True:
        probe = socket.socket()
        try:
            probe.bind(("127.0.0.1", port))
            break
        except OSError:
            if time.time() > deadline:
                sys.exit(f"port {port} is already in use")
            time.sleep(0.25)
        finally:
            probe.close()
PY

mkdir -p "$out"
if [ ! -d "$here/node_modules/playwright-core" ]; then
  echo "run.sh: installing playwright-core"
  if [ -f "$here/package-lock.json" ]; then
    (cd "$here" && npm ci --no-audit --no-fund)
  else
    (cd "$here" && npm install --no-audit --no-fund)
  fi
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
  if [ -n "$xvfb_pid" ]; then kill -- -"$xvfb_pid" 2>/dev/null; fi
  wait 2>/dev/null
  rm -rf "$profile"
  exit "$status"
}
trap cleanup EXIT INT TERM

if [ -e "/tmp/.X11-unix/X$display" ] || [ -e "/tmp/.X$display-lock" ]; then
  die "display :$display is already in use; set SHOWCASE_DISPLAY to a free one"
fi
echo "run.sh: starting Xvfb on :$display"
# setsid, like the server and Chrome: the command may be a Guix wrapper, and
# killing the wrapper alone would orphan the X server it started.
setsid "${xvfb[@]}" ":$display" -screen 0 "${view_width}x${view_height}x24" \
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
  if curl -fsS -o /dev/null --max-time 2 "$base/" 2>/dev/null; then
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
# DISPLAY is what puts Chrome on the Xvfb screen the camera is pointed at;
# without it Chrome renders wherever the caller's session is.
setsid env DISPLAY=":$display" "$chrome" \
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
      "http://127.0.0.1:$cdp_port/json/version" 2>/dev/null; then
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

# An X11 grab of the wrong (or a blank) display is a perfectly valid video,
# and gifski happily encodes it into a black GIF.  Look at a frame first.
echo "run.sh: checking the capture"
frame="$out/check/capture-frame.png"
ffmpeg -y -loglevel error -ss 10 -i "$out/capture.mkv" -frames:v 1 "$frame" \
  || die "could not read $out/capture.mkv"
[ -s "$frame" ] || die "the capture has no frame at ten seconds"
python3 - "$frame" <<'PY'
import sys
from PIL import Image

image = Image.open(sys.argv[1]).convert("L")
low, high = image.getextrema()
if high - low < 8:
    sys.exit("the capture is blank: Chrome was not drawing on the Xvfb display")
PY

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
