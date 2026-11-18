#!/bin/bash
# Builds the iPhone app (with the Apple Watch app inside) on this Mac and uploads it to TestFlight.
# It does what the "iPhone to TestFlight" workflow does on GitHub, but with this Mac's Xcode, so it can use
# a newer Xcode than GitHub has (Xcode 27.1 is what makes the app fill the iPhone Duo's inner screen).
#
# Needs: Xcode (signed in under Xcode > Settings > Accounts with the Apple developer account) and Node.js 22+.
# Run from the repo folder:   bash native/scripts/build-on-mac.sh 1.2
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then echo "Give the version to build, for example:  bash native/scripts/build-on-mac.sh 1.2"; exit 1; fi
# Date-based build number, always higher than GitHub's builds (13, 14, ...) for the same version
BUILD="${2:-$(date +%Y%m%d.%H%M)}"
cd "$(dirname "$0")/.."    # native/
NATIVE="$PWD"
step() { printf '\n\033[1;33m== %s\033[0m\n' "$1"; }

step "Checking this Mac"
command -v node >/dev/null || { echo "Node.js isn't installed. Get the LTS version from https://nodejs.org, then run this again."; exit 1; }
node -v
xcodebuild -version
SDK=$(xcrun --sdk iphoneos --show-sdk-version)
echo "iOS SDK $SDK"
if [ "$(printf '%s\n' 27.1 "$SDK" | sort -V | head -1)" != "27.1" ] && [ -z "${ALLOW_OLD_SDK:-}" ]; then
  echo "This Xcode has iOS SDK $SDK. Update Xcode to 27.1 or newer from the App Store for iPhone Duo support."
  echo "(To build anyway, run again with ALLOW_OLD_SDK=1 in front.)"
  exit 1
fi

# Team ID: remembered after the first run
TEAM_FILE="$HOME/.plushbucket-team-id"
TEAM_ID="${TEAM_ID:-$(cat "$TEAM_FILE" 2>/dev/null || true)}"
if [ -z "$TEAM_ID" ]; then
  echo
  echo "Your Apple Team ID is the 10-character code at https://developer.apple.com/account under Membership details."
  read -r -p "Team ID: " TEAM_ID
fi
TEAM_ID=$(echo "$TEAM_ID" | tr -d '[:space:]')
[ ${#TEAM_ID} -eq 10 ] || { echo "That doesn't look like a Team ID (it should be 10 letters and numbers)."; exit 1; }
echo "$TEAM_ID" > "$TEAM_FILE"

step "Copying the website into the app"
npm install --no-audit --no-fund
npm run build:web

step "Creating a fresh iPhone project"
rm -rf ios
npx cap add ios
npm run icons -- --ios
npx cap sync ios

step "Adding the Apple Watch app"
command -v ruby >/dev/null || { echo "Ruby isn't on this Mac. Install Homebrew (https://brew.sh), run: brew install ruby  and then run this again."; exit 1; }
if ! ruby -e 'require "xcodeproj"' 2>/dev/null; then
  echo "Installing the xcodeproj Ruby gem (one time)"
  gem install --user-install --no-document xcodeproj || { echo "Couldn't install it. Run:  sudo gem install xcodeproj  (it asks for your Mac password), then run this again."; exit 1; }
fi
bash watch/add-to-ios.sh
/usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" ios/App/App/Info.plist 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :ITSAppUsesNonExemptEncryption false" ios/App/App/Info.plist

OUT="$NATIVE/build-output"
rm -rf "$OUT" && mkdir -p "$OUT"

step "Building and signing Plushbucket $VERSION ($BUILD). This takes about 5 minutes."
cd "$NATIVE/ios/App"
xcodebuild archive -project App.xcodeproj -scheme App -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/App.xcarchive" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
  | grep -E "error:|warning: .*(sign|provision)|\*\* ARCHIVE" || true
[ -d "$OUT/App.xcarchive" ] || { echo "The build failed. Scroll up for the lines that say error:"; exit 1; }

step "Uploading to TestFlight"
cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
EOF
xcodebuild -exportArchive -archivePath "$OUT/App.xcarchive" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -exportPath "$OUT/export" \
  -allowProvisioningUpdates

step "Done"
echo "Plushbucket $VERSION ($BUILD) is uploaded. It shows in TestFlight after Apple processes it (10-30 minutes)."
