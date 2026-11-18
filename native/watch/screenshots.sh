#!/bin/bash
# Takes the App Store screenshots of the watch app in the watchOS Simulator, using its built-in sample bikes.
# Usage: bash watch/screenshots.sh path/to/PlushbucketWatch.app output-folder
set -euo pipefail
APP="$1"; OUT="$2"; mkdir -p "$OUT"
BUNDLE=com.plushbucket.app.watchkitapp

RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys
r=[x for x in json.load(sys.stdin)["runtimes"] if x.get("platform")=="watchOS" and x.get("isAvailable")]
print(r[-1]["identifier"] if r else "")')
if [ -z "$RUNTIME" ]; then
  echo "No watchOS simulator installed; downloading one (a few minutes)"
  xcodebuild -downloadPlatform watchOS
  RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys
r=[x for x in json.load(sys.stdin)["runtimes"] if x.get("platform")=="watchOS" and x.get("isAvailable")]
print(r[-1]["identifier"])')
fi

# The biggest watch Apple accepts screenshots from, newest first
TYPE=$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys,re
t=[x for x in json.load(sys.stdin)["devicetypes"] if "Watch" in x["name"]]
def score(x):
    n=x["name"];m=re.search(r"(\d+)mm",n);size=int(m.group(1)) if m else 0
    gen=re.search(r"(Series|Ultra) ?(\d*)",n);g=int(gen.group(2) or 1) if gen else 0
    return (size,"Ultra" in n,g)
t.sort(key=score);print(t[-1]["identifier"]);print(t[-1]["name"],file=sys.stderr)')
echo "Using $TYPE on $RUNTIME"

DEV=$(xcrun simctl create "Plushbucket shots" "$TYPE" "$RUNTIME")
xcrun simctl boot "$DEV"
xcrun simctl bootstatus "$DEV" -b
xcrun simctl status_bar "$DEV" override --time "9:41" || true
xcrun simctl install "$DEV" "$APP"

n=0
for shot in list fork shock ride save; do
  n=$((n+1))
  xcrun simctl terminate "$DEV" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$DEV" "$BUNDLE" -PBDemo -PBShot "$shot"
  sleep 6
  xcrun simctl io "$DEV" screenshot "$OUT/$n-$shot.png"
done
sips -g pixelWidth -g pixelHeight "$OUT"/*.png
xcrun simctl shutdown "$DEV" || true
xcrun simctl delete "$DEV" || true
