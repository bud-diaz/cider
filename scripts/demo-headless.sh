#!/usr/bin/env bash
#
# Runs the hello-cider example on a machine with no display, and captures what
# it drew.
#
# This is what a reviewer or a CI job wants: proof that the vertical slice
# works, without needing a graphical session. It starts a virtual display, runs
# the example, clicks the button, and saves a screenshot of each state.
#
# Requires: Xvfb, xdotool, and ImageMagick's `import`.
#     sudo apt install xvfb xdotool imagemagick

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${REPO_ROOT}/.cider-demo}"
DISPLAY_NUMBER="${CIDER_DEMO_DISPLAY:-:99}"

for tool in Xvfb xdotool import; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: $tool is not installed." >&2
        echo "" >&2
        echo "Install the demo prerequisites:" >&2
        echo "" >&2
        echo "    sudo apt install xvfb xdotool imagemagick" >&2
        exit 1
    fi
done

mkdir -p "$OUTPUT_DIR"

echo "==> building"
swift build --package-path "$REPO_ROOT"
CIDER="${REPO_ROOT}/.build/debug/cider"

echo "==> starting a virtual display on ${DISPLAY_NUMBER}"
Xvfb "$DISPLAY_NUMBER" -screen 0 1280x1024x24 >"${OUTPUT_DIR}/xvfb.log" 2>&1 &
XVFB_PID=$!
# Clean up the display even if a later step fails, so a rerun is not blocked.
trap 'kill "$XVFB_PID" 2>/dev/null || true' EXIT
sleep 2
export DISPLAY="$DISPLAY_NUMBER"

echo "==> cider doctor"
"$CIDER" doctor

echo "==> cider run"
cd "${REPO_ROOT}/examples/hello-cider"
setsid "$CIDER" run >"${OUTPUT_DIR}/run.log" 2>&1 </dev/null &
sleep 6

WINDOW_ID="$(xdotool search --name 'Hello Cider' | head -1)"
if [ -z "$WINDOW_ID" ]; then
    echo "error: the application window never appeared. Log:" >&2
    cat "${OUTPUT_DIR}/run.log" >&2
    exit 1
fi
echo "    window ${WINDOW_ID}"

import -window "$WINDOW_ID" "${OUTPUT_DIR}/count-0.png"

echo "==> clicking the button three times"
# The button sits at the centre of a 390x844 device screen.
xdotool mousemove --window "$WINDOW_ID" 195 435
for n in 1 2 3; do
    xdotool click --window "$WINDOW_ID" 1
    sleep 0.5
    import -window "$WINDOW_ID" "${OUTPUT_DIR}/count-${n}.png"
done

echo "==> closing the window"
xdotool windowclose "$WINDOW_ID"
sleep 2

echo ""
echo "Runtime log:"
sed 's/^/    /' "${OUTPUT_DIR}/run.log"
echo ""
echo "Screenshots written to ${OUTPUT_DIR}:"
ls -1 "${OUTPUT_DIR}"/*.png | sed 's/^/    /'
