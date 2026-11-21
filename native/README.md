# Plushbucket iPhone and Android apps

The apps wrap the website with [Capacitor](https://capacitorjs.com). There's one codebase: `../index.html` is the app on the web, on iPhone and on Android. `npm run build:web` copies it into `www/`, which Capacitor packs into each app.

## Test builds without a Mac

Every push that touches the app runs **Actions → Native apps** on GitHub:

- **Android:** builds a debug APK. Open the run, download `plushbucket-android-debug` under Artifacts, and install it on an Android phone (allow installs from unknown sources).
- **iPhone:** compiles for the iOS Simulator to prove it builds. Installing on a real iPhone needs an Apple Developer account and signing.

## Building on your own computer

Needs Node 22+. Android needs Android Studio (Otter 2025.2.1 or newer). iPhone needs a Mac with Xcode 26 or newer.

```sh
cd native
npm install
npm run add:android      # once: creates android/
npm run add:ios          # once, on a Mac: creates ios/
npm run icons            # app icons and splash screens from assets/
npm run android          # copies the site in and opens Android Studio
npm run ios              # same for Xcode
```

After creating `android/` and `ios/` the first time, commit them. Health permissions, signing and store settings live in those folders.

## What's different in the app

`index.html` checks `NATIVE` (true inside the apps):

- No service worker and no "install the app" banner
- Backup export writes the file and opens the share sheet (`@capacitor/filesystem` + `@capacitor/share`), since web downloads don't work in an app
- The service log note says data is saved on the phone and erased if the app is deleted
- Safe-area padding at the top for the notch and status bar

## Apple Watch

`watch/PlushbucketWatch/` is a small SwiftUI watch app that ships inside the iPhone app. It shows each garage bike's pressure, sag and clicks, and has a ride timer whose hours go into the phone's service log. With the rider's permission, each timed ride is also recorded as an Outdoor Cycle workout in Apple Health, so it shows in the Fitness app (`Workout.swift`, HealthKit entitlement and workout background mode in `PlushbucketWatch.entitlements` and `Info.plist`).

- The iPhone project is generated on every build, so `watch/add-to-ios.sh` adds the watch target to it after `npx cap sync ios` (it runs `watch/add-watch-target.rb`, which uses the `xcodeproj` Ruby gem).
- The phone side is the `plugins/watch-sync` Capacitor plugin. `index.html` sends the garage to it (`WatchSync.sendBikes`) and takes back rides timed on the watch (`WatchSync.takeRides`).
- Bundle ID `com.plushbucket.app.watchkitapp`, watchOS 10 or newer. Xcode's automatic signing registers it on the first TestFlight build.
- App Store screenshots: Actions → **Apple Watch screenshots** runs the app in the watchOS Simulator with sample bikes (`-PBDemo -PBShot list|fork|shock|ride|save`).

## Ride import (Apple Health and Health Connect)

Rides recorded with other apps (Garmin Connect, Strava, Trailforks...) count toward service when those apps save them to Apple Health on iPhone or Health Connect on Android. The Service tab's **Rides from Apple Health / Health Connect** panel lists new rides; the rider ticks them, picks the bike, marks wet ones and adds them to the service log. It only shows inside the apps.

- `plugins/health-rides` reads bike rides only (iPhone: HealthKit cycling workouts; Android: Health Connect biking sessions). It never writes and nothing leaves the phone.
- `index.html` leaves out rides the watch already logged (and anything recorded at the same time), counts a ride saved by two apps once, skips indoor trainer rides, and only counts a ride for a fork or shock after it was added, last serviced or marked done. Unticked and deleted imports aren't offered again.
- iPhone: `watch/add-to-ios.sh` gives the iPhone app the HealthKit entitlement (`health/App.entitlements`) and the permission text (`NSHealthShareUsageDescription`). Automatic signing turns HealthKit on for the app ID on the first build.
- Android: the plugin's manifest adds `READ_EXERCISE` and the screen Health Connect opens to explain data use (it opens the privacy policy). Health Connect shares rides from up to 30 days before access is first allowed. Google Play asks for a **Health apps declaration** (Play Console > App content) before a release with Health Connect permissions can go out.

## Building on your Mac (newer Xcode than GitHub has)

GitHub's Macs can lag behind Apple's Xcode releases. To build with your own Xcode (for example Xcode 27.1, which makes the app fill the iPhone Duo's inner screen), on an Apple silicon Mac with that Xcode and Node.js installed and your developer account signed in under Xcode > Settings > Accounts:

```sh
git clone https://github.com/Sibes991/Plushbucket.git ~/Plushbucket   # first time only (later: cd ~/Plushbucket && git pull)
cd ~/Plushbucket && bash native/scripts/build-on-mac.sh 1.2
```

It builds the iPhone and watch apps the same way the TestFlight workflow does, signs them with your Xcode account and uploads to TestFlight. The build number is the date and time (e.g. 20261117.2230), so it's always higher than GitHub's builds for the same version; build the next version on GitHub as usual.

## Store details

- App ID: `com.plushbucket.app`. Changing it is easy now, but it's permanent once an app is published.
- Name: Plushbucket
