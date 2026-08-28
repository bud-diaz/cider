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

# Stage 3: build and smoke-run the reference apps under a real X11 backend.
"$CIDER" build --path examples/notes-cider > "$TMP/notes-build.log" 2>&1
"$CIDER" build --path examples/rest-client-cider > "$TMP/rest-build.log" 2>&1

Xvfb :99 -screen 0 1280x1024x24 > "$TMP/xvfb.log" 2>&1 &
XVFB_PID=$!
export DISPLAY=:99
sleep 1

timeout 10 "$CIDER" run --path examples/notes-cider --no-build --inspect --log-level debug > "$TMP/notes-run.log" 2>&1 &
NOTES_PID=$!
sleep 3
NOTES_WIN="$(xdotool search --name Notes | head -n1)"
xdotool windowfocus "$NOTES_WIN" >/dev/null 2>&1 || true
xdotool mousemove --window "$NOTES_WIN" 195 328 click 1
xdotool type --clearmodifiers --delay 50 "hello"
xdotool mousemove --window "$NOTES_WIN" 195 386 click 1
sleep 1
wait "$NOTES_PID" || NOTES_STATUS=$?
NOTES_STATUS=${NOTES_STATUS:-0}
[[ "$NOTES_STATUS" == "124" ]] || { echo "notes run exited unexpectedly with $NOTES_STATUS" >&2; exit 1; }
grep -q 'application started' "$TMP/notes-run.log"
grep -q 'TextFieldNode.*"h' "$TMP/notes-run.log"
grep -q 'Saved note.txt' "$TMP/notes-run.log"

timeout 18 "$CIDER" run --path examples/rest-client-cider --no-build --inspect --log-level debug > "$TMP/rest-run.log" 2>&1 &
REST_PID=$!
sleep 3
REST_WIN="$(xdotool search --name "REST Client" | head -n1)"
xdotool windowfocus "$REST_WIN" >/dev/null 2>&1 || true
xdotool mousemove --window "$REST_WIN" 195 294 click 1
sleep 7
wait "$REST_PID" || REST_STATUS=$?
REST_STATUS=${REST_STATUS:-0}
[[ "$REST_STATUS" == "124" ]] || { echo "REST run exited unexpectedly with $REST_STATUS" >&2; exit 1; }
grep -q 'application started' "$TMP/rest-run.log"
grep -q 'HTTP 200' "$TMP/rest-run.log"
grep -q 'Example Domain' "$TMP/rest-run.log"

# Stage 4: prove the published contributor flow from the CLI surface.
"$CIDER" init SmokeApp --app-id dev.cider.smoke --path "$TMP/SmokeApp" > "$TMP/init.log"
"$CIDER" scan --path "$TMP/SmokeApp" > "$TMP/scan-clean.log" 2>&1
"$CIDER" inspect --path "$TMP/SmokeApp" > "$TMP/inspect.log"
"$CIDER" network --path "$TMP/SmokeApp" > "$TMP/network.log"
mkdir -p "$XDG_DATA_HOME/cider/apps/dev.cider.smoke/Documents"
printf smoke > "$XDG_DATA_HOME/cider/apps/dev.cider.smoke/Documents/smoke.txt"
"$CIDER" storage --path "$TMP/SmokeApp" > "$TMP/storage.log"
"$CIDER" dev-loop --path "$TMP/SmokeApp" > "$TMP/dev-loop.log"
"$CIDER" compatibility-docs --output "$TMP/compatibility.md" > "$TMP/compatibility-command.log"
"$CIDER" build --path "$TMP/SmokeApp" > "$TMP/smoke-build.log"

timeout 8 "$CIDER" run --path "$TMP/SmokeApp" --no-build --inspect --log-level debug > "$TMP/smoke-run.log" 2>&1 &
SMOKE_PID=$!
sleep 3
SMOKE_WIN="$(xdotool search --name SmokeApp | head -n1)"
xdotool windowfocus "$SMOKE_WIN" >/dev/null 2>&1 || true
xdotool mousemove --window "$SMOKE_WIN" 195 424 click 1 || true
sleep 1
wait "$SMOKE_PID" || SMOKE_STATUS=$?
SMOKE_STATUS=${SMOKE_STATUS:-0}
[[ "$SMOKE_STATUS" == "124" ]] || { echo "template run exited unexpectedly with $SMOKE_STATUS" >&2; exit 1; }
"$CIDER" dev --path "$TMP/SmokeApp" --once --port 5758 > "$TMP/dev.log"
printf '\nimport SwiftUI\n' >> "$TMP/SmokeApp/Sources/SmokeApp/SmokeApp.swift"
"$CIDER" scan --path "$TMP/SmokeApp" > "$TMP/scan-warning.log" 2>&1 || true

grep -q 'created template' "$TMP/init.log"
grep -q 'compatibility scan passed' "$TMP/scan-clean.log"
grep -q '# Cider Project Inspector' "$TMP/inspect.log"
grep -q '# Cider Network Viewer' "$TMP/network.log"
grep -q 'Documents/smoke.txt' "$TMP/storage.log"
grep -q 'cider run --no-build' "$TMP/dev-loop.log"
grep -q '# Cider Compatibility Registry' "$TMP/compatibility.md"
grep -q 'built .*SmokeApp' "$TMP/smoke-build.log"
grep -q 'application started' "$TMP/smoke-run.log"
grep -q 'Count: 1' "$TMP/smoke-run.log"
grep -q 'dev dashboard validated' "$TMP/dev.log"
grep -q 'CID0605' "$TMP/scan-warning.log"

echo "[cider] Stage 3/4 validation passed"
