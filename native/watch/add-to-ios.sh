#!/bin/bash
# Puts the Apple Watch app into the iPhone project. Run from native/ after `npx cap sync ios`.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf ios/App/PlushbucketWatch
cp -R watch/PlushbucketWatch ios/App/PlushbucketWatch
ruby -e 'require "xcodeproj"' 2>/dev/null || sudo gem install xcodeproj --no-document
ruby watch/add-watch-target.rb ios/App/App.xcodeproj
