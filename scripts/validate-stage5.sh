#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CIDER="$ROOT/.build/debug/cider"
TMP="$(mktemp -d)"
XVFB_PID=""
cleanup() {
  if [[ -n "$XVFB_PID" ]]; then
    kill "$XVFB_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 127
  fi
}

require swift
require timeout
require Xvfb
require xdotool

export XDG_DATA_HOME="$TMP/xdg"

swift build >/dev/null

NEW_APPS=(nav-list-cider form-input-cider image-loading-cider modal-presentation-cider timer-clipboard-cider lifecycle-cider)
for app in "${NEW_APPS[@]}"; do
  "$CIDER" build --path "examples/$app" > "$TMP/$app-build.log" 2>&1
done

Xvfb :99 -screen 0 1280x1024x24 > "$TMP/xvfb.log" 2>&1 &
XVFB_PID=$!
export DISPLAY=:99
sleep 1

# form-input-cider: focus the field, type, submit, and check the bound
# state round-tripped through TextField into the submitted Text.
timeout 10 "$CIDER" run --path examples/form-input-cider --no-build --inspect --log-level debug > "$TMP/form-run.log" 2>&1 &
FORM_PID=$!
sleep 3
FORM_WIN="$(xdotool search --name "Form Input" | head -n1)"
xdotool windowfocus "$FORM_WIN" >/dev/null 2>&1 || true
xdotool mousemove --window "$FORM_WIN" 195 406 click 1
xdotool type --clearmodifiers --delay 50 "hello"
xdotool mousemove --window "$FORM_WIN" 195 464 click 1
sleep 1
wait "$FORM_PID" || FORM_STATUS=$?
FORM_STATUS=${FORM_STATUS:-0}
[[ "$FORM_STATUS" == "124" ]] || { echo "form-input run exited unexpectedly with $FORM_STATUS" >&2; exit 1; }
grep -q 'application started' "$TMP/form-run.log"
grep -q 'TextFieldNode.*"h' "$TMP/form-run.log"
grep -q 'Submitted: hello' "$TMP/form-run.log"

# modal-presentation-cider: tap Show and confirm the presented sheet draws.
timeout 10 "$CIDER" run --path examples/modal-presentation-cider --no-build --inspect --log-level debug > "$TMP/modal-run.log" 2>&1 &
MODAL_PID=$!
sleep 3
MODAL_WIN="$(xdotool search --name "Modal Presentation" | head -n1)"
xdotool windowfocus "$MODAL_WIN" >/dev/null 2>&1 || true
xdotool mousemove --window "$MODAL_WIN" 195 126 click 1
sleep 1
wait "$MODAL_PID" || MODAL_STATUS=$?
MODAL_STATUS=${MODAL_STATUS:-0}
[[ "$MODAL_STATUS" == "124" ]] || { echo "modal-presentation run exited unexpectedly with $MODAL_STATUS" >&2; exit 1; }
grep -q 'application started' "$TMP/modal-run.log"
grep -q 'presenting=true' "$TMP/modal-run.log"
grep -q 'Presented Sheet' "$TMP/modal-run.log"

# nav-list-cider: tap the first row and confirm the push landed on its
# detail screen.
timeout 10 "$CIDER" run --path examples/nav-list-cider --no-build --inspect --log-level debug > "$TMP/nav-run.log" 2>&1 &
NAV_PID=$!
sleep 3
NAV_WIN="$(xdotool search --name "Nav List" | head -n1)"
xdotool windowfocus "$NAV_WIN" >/dev/null 2>&1 || true
xdotool mousemove --window "$NAV_WIN" 111 126 click 1
sleep 1
wait "$NAV_PID" || NAV_STATUS=$?
NAV_STATUS=${NAV_STATUS:-0}
[[ "$NAV_STATUS" == "124" ]] || { echo "nav-list run exited unexpectedly with $NAV_STATUS" >&2; exit 1; }
grep -q 'application started' "$TMP/nav-run.log"
grep -q 'Room 0' "$TMP/nav-run.log"
grep -q '"Back"' "$TMP/nav-run.log"

# Final gate check: the readiness report should have no missing rows, and
# only the accepted alpha caveats (installation packaging today) partial.
REPORT="$("$CIDER" alpha-readiness --path "$ROOT")"
echo "$REPORT"
if echo "$REPORT" | grep -qE '\| missing \|'; then
  echo "alpha-readiness reports a missing gate; see output above" >&2
  exit 1
fi
PARTIAL_COUNT="$(echo "$REPORT" | grep -cE '\| partial \|')"
if [[ "$PARTIAL_COUNT" -ne 1 ]] || ! echo "$REPORT" | grep -q '| installation packaging | partial |'; then
  echo "expected exactly one partial gate (installation packaging); got $PARTIAL_COUNT" >&2
  exit 1
fi

echo "[cider] Stage 5 validation passed"
