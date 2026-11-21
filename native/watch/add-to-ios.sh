#!/bin/bash
# Puts the Apple Watch app into the iPhone project, and gives the iPhone app its Apple Health settings
# (read access for ride import, plugins/health-rides). Run from native/ after `npx cap sync ios`.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf ios/App/PlushbucketWatch
cp -R watch/PlushbucketWatch ios/App/PlushbucketWatch
# iPhone app: HealthKit entitlement and the text Apple shows when asking to read workouts
cp health/App.entitlements ios/App/App/App.entitlements
PL=ios/App/App/Info.plist
MSG="Plushbucket reads your cycling workouts, so rides you record with Garmin, Strava, Trailforks or other apps count toward your fork and shock service hours. Nothing leaves your iPhone."
plutil -replace NSHealthShareUsageDescription -string "$MSG" "$PL"
ruby -e 'require "xcodeproj"' 2>/dev/null || sudo gem install xcodeproj --no-document
ruby watch/add-watch-target.rb ios/App/App.xcodeproj
