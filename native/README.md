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

## Store details

- App ID: `com.plushbucket.app`. Changing it is easy now, but it's permanent once an app is published.
- Name: Plushbucket
