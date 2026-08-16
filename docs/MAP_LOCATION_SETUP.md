# Google Maps rendering setup

TripJournal renders trip-entry coordinates with Google Maps only when the
current platform has its own restricted rendering key. With no key, the app
uses the navigable **Map unavailable** list; the default checkout, tests, and
web release build therefore work without Google credentials.

The map shows saved entry coordinates only. It does not request GPS/current
location, background location, or any Android/iOS location permission.

## 1. Create three restricted keys

In one Google Cloud project, enable billing and the platform API needed by
each client. Use three separate keys so a leaked web key cannot be used by a
native app (or vice versa).

### Android key

1. Enable **Maps SDK for Android** and restrict the key to that API.
2. Set the application restriction to **Android apps**.
3. Add package name `com.tripjournal.tripjournal`.
4. Add the signing certificate's **SHA-1** fingerprint. Register the SHA-1 for
   every certificate that signs an APK users actually install; debug and
   release certificates are normally different.

For the standard debug keystore on Windows, inspect its SHA-1 with:

```powershell
keytool -list -v -alias androiddebugkey `
  -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -storepass android -keypass android
```

For Google Play builds, copy the **Play app-signing certificate SHA-1** from
Play Console's app-integrity page, not the upload certificate. The upload
certificate authenticates the bundle submitted to Play; Google signs the APK
installed by users with the app-signing certificate. For an APK distributed
directly or through another store, register the SHA-1 of the certificate that
signs that installed APK. Never use the debug certificate for production.

### iOS key

1. Enable **Maps SDK for iOS** and restrict the key to that API.
2. Set the application restriction to **iOS apps**.
3. Add bundle ID `com.tripjournal.tripjournal` (or the exact bundle ID of the
   flavor being built).

The installed Flutter Maps package supports iOS 14 and later, matching the
deployment target in the Xcode project.

### Web key

1. Enable **Maps JavaScript API** and restrict the key to that API.
2. Set the application restriction to **Websites**.
3. Add the exact production **HTTP referrer** patterns, for example
   `https://journal.example.com/*`. Add preview domains individually. Add a
   bare `http://localhost` entry and `http://localhost/*` for all local paths
   only to a development key, never to the production key. In website
   restrictions, omitting the port matches any port; a wildcard in the port is
   not valid.

Allowing all referrers defeats the web restriction. Do not use an IP-address
restriction for a browser key.

## 2. Local build-time input

The blank `GOOGLE_MAPS_ANDROID_KEY`, `GOOGLE_MAPS_IOS_KEY`, and
`GOOGLE_MAPS_WEB_KEY` lines in `.env.example` document the deployment secret
names only. Leave them blank in `.env`: native Google SDK initialization cannot
be supplied by Dart's bundled `.env` asset.

Create a gitignored `maps.local.json` at the repository root instead:

```json
{
  "GOOGLE_MAPS_ANDROID_KEY": "<android-restricted-key>",
  "GOOGLE_MAPS_IOS_KEY": "<ios-restricted-key>",
  "GOOGLE_MAPS_WEB_KEY": "<web-referrer-restricted-key>"
}
```

Only the key for the platform being built needs a value. Keep other values as
empty strings. `maps.local.json` is ignored by Git; do not force-add it.

### Android

```powershell
D:\Download\flutter-sdk\bin\flutter.bat run `
  --dart-define-from-file=maps.local.json
```

Flutter passes the define to Dart (which enables the Google surface) and to
Gradle. `android/app/build.gradle.kts` decodes only
`GOOGLE_MAPS_ANDROID_KEY` into the `${GOOGLE_MAPS_ANDROID_KEY}` manifest
placeholder. If the define is absent, the placeholder is empty and Dart uses
the fallback surface.

### iOS

Run from macOS:

```bash
flutter run --dart-define-from-file=maps.local.json
```

Flutter writes its encoded build defines to Xcode's `DART_DEFINES` setting.
`Info.plist` contains only that build placeholder, and `AppDelegate.swift`
decodes only `GOOGLE_MAPS_IOS_KEY` before initializing `GMSServices`. With no
iOS key, `GMSServices` is not initialized and Dart uses the fallback surface.

### Web

The tracked `web/index.html` contains `__GOOGLE_MAPS_WEB_KEY__`, not a key. A
normal no-key build finds no local web configuration, skips loading the Maps
JavaScript API, and uses the fallback surface.

The bootstrap exposes whether that SDK load is ready, unconfigured, or failed
before starting Flutter. Dart requires both the web build key and the ready
state, so a loader failure shows the fallback instead of constructing a
`GoogleMap` while `google.maps` is absent.

For a configured release, generate the gitignored web configuration containing
only the web key, then build with the matching Dart define:

```powershell
$mapsConfig = Get-Content -Raw maps.local.json | ConvertFrom-Json
@{
  GOOGLE_MAPS_WEB_KEY = [string]$mapsConfig.GOOGLE_MAPS_WEB_KEY
} | ConvertTo-Json -Compress |
  Set-Content -Encoding utf8 -Path web\google_maps_config.json

try {
  D:\Download\flutter-sdk\bin\flutter.bat build web --release `
    --dart-define-from-file=maps.local.json
} finally {
  Remove-Item -ErrorAction SilentlyContinue web\google_maps_config.json
}
```

Flutter copies `google_maps_config.json` into `build/web` and includes it in the
generated service-worker asset manifest. Deploy `build/web`; never replace the
token in tracked `web/index.html`. Do not copy all of `maps.local.json` into web
assets, because that would expose the Android and iOS keys unnecessarily.

## 3. CI injection

Store the three values in the CI provider's encrypted secret store under the
same names. Pass only the current platform key as a Dart define; do not echo
the command or secret value in public logs.

Android example:

```powershell
D:\Download\flutter-sdk\bin\flutter.bat build appbundle --release `
  --dart-define="GOOGLE_MAPS_ANDROID_KEY=$env:GOOGLE_MAPS_ANDROID_KEY"
```

iOS example (on macOS):

```bash
flutter build ipa --release \
  --dart-define="GOOGLE_MAPS_IOS_KEY=$GOOGLE_MAPS_IOS_KEY"
```

For web, generate `web/google_maps_config.json` from the protected
`GOOGLE_MAPS_WEB_KEY` value before `flutter build`, pass the same value through
`--dart-define="GOOGLE_MAPS_WEB_KEY=..."`, and delete the source config in a
cleanup/finally step. The rendered browser key is necessarily visible to
browsers; the HTTP referrer and API restrictions are the security boundary.

## 4. Failure behavior and diagnostics

- Missing or blank current-platform configuration always selects
  `TripMapUnavailableSurface`, where every located entry remains selectable
  and **Retry** rechecks the platform gate. A build-time key cannot appear in a
  running release, so the fallback remains until a correctly configured build
  is installed or deployed.
- A catchable controller/camera platform error switches the Google surface to
  the same fallback and shows **Retry**.
- A Maps JavaScript SDK network/loader failure starts Flutter with a failed
  readiness state, which selects the same fallback and **Retry** surface.
- Google Maps tile authentication, billing, API-enable, and restriction errors
  are reported by the native/web SDK and are not exposed by `GoogleMap` as a
  catchable Dart exception. Check device/browser logs and Google Cloud's Maps
  diagnostics; do not add a fake Dart error handler that claims to catch them.
- If tiles fail, verify that the correct platform API is enabled and that the
  package/SHA, bundle ID, or HTTP referrer exactly matches the deployed app.
