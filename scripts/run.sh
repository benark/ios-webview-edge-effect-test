#!/bin/bash
# Boots a simulator, runs the test app once per case, and saves a screenshot and a report for each in out/.
#   BASE_URL     folder that holds the test pages (default: the live reproduction pages)
#   DEVICE_NAME  simulator device type (default: iPhone 18 Pro Max)
set -euo pipefail
cd "$(dirname "$0")/.."

BASE_URL="${BASE_URL:-https://ado-mobile.benark.com/repro/}"
DEVICE_NAME="${DEVICE_NAME:-iPhone 18 Pro Max}"
BUNDLE=test.webview.edgeeffect
APP=build/EdgeEffectTest.app

# name | page | style | scroll (CSS px)
CASES=(
  "automatic-top|translucent/|automatic|0"
  "automatic-scrolled|translucent/|automatic|110"
  "soft-top|translucent/|soft|0"
  "soft-scrolled|translucent/|soft|110"
  "hard-top|translucent/|hard|0"
  "hard-scrolled|translucent/|hard|110"
  "hard-solid-top|translucent-solid/|hard|0"
  "hidden-top|translucent/|hidden|0"
)

# Newest iOS runtime that has the requested device; otherwise the newest with any iPhone.
UDID=$(xcrun simctl list devices available -j | DEVICE_NAME="$DEVICE_NAME" python3 -c '
import json, os, re, sys
want = os.environ["DEVICE_NAME"]
found = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    m = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        if d["name"].startswith("iPhone"):
            found.append((d["name"] == want, version, d["name"], d["udid"]))
if not found:
    sys.exit("no iPhone simulator available")
found.sort()
exact, version, name, udid = found[-1]
print("Using %s on iOS %d.%d%s" % (name, version[0], version[1], "" if exact else " (requested device not found)"), file=sys.stderr)
print(udid)
')

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"
DATA=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)

rm -rf out
mkdir -p out
for entry in "${CASES[@]}"; do
  IFS='|' read -r name page style scroll <<<"$entry"
  report="$DATA/Documents/$name.txt"
  rm -f "$report"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -name "$name" -url "$BASE_URL$page" -style "$style" -scroll "$scroll" >/dev/null

  for _ in $(seq 1 90); do
    [ -f "$report" ] && break
    sleep 1
  done
  echo "=== $name"
  if [ -f "$report" ]; then
    cp "$report" "out/$name.txt"
    cat "$report"
  else
    echo "no report after 90 s" | tee "out/$name.txt"
  fi
  xcrun simctl io "$UDID" screenshot "out/$name.png" >/dev/null
done
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
ls -l out
