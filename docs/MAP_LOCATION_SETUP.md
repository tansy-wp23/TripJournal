# Map rendering setup

TripJournal renders trip-entry coordinates with **OpenStreetMap** tiles via
`flutter_map`. There is no API key, no Google Cloud project, and no billing
account involved — the Trip Map and the Place Picker both render for every
developer and every build with zero setup.

The Trip Map shows saved entry coordinates only. The Place Picker can request
a single foreground location after the user taps **Use my location**. It does
not request background location, subscribe to continuous GPS, or keep
location history.

This guide covers map **rendering** only. Searching for a place, and
resolving a dropped pin to a place name, go through a Supabase Edge Function
that calls OpenStreetMap's Nominatim geocoder: see
[`PLACES_SEARCH_SETUP.md`](PLACES_SEARCH_SETUP.md).

## 1. The OpenStreetMap tile usage policy — read before shipping

Both map surfaces load raster tiles from the public
`tile.openstreetmap.org` server, governed by the
[OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/).
This is a free, best-effort community service, not a paid API — it comes with
real obligations:

- **Attribution is required, not optional** (ODbL license). Both
  `OsmTripMapSurface` and `PlacePickerMap` render a `RichAttributionWidget`
  with `TextSourceAttribution('OpenStreetMap contributors')` — never remove it.
- **A distinct, stable User-Agent is required.** `TileLayer.userAgentPackageName`
  is set to `com.tripjournal.tripjournal` for exactly this reason. A generic
  default gets silently blocked with no error surfaced to Dart.
- **No pre-seeding or bulk prefetch.** Never add an "offline maps" download
  feature against the public tile server — the policy explicitly forbids
  downloading multiple zoom levels or large areas in advance.
- **No SLA.** `tile.openstreetmap.org` can be slow or briefly unavailable;
  there is nothing to "fix" on our side when that happens.
- **If usage ever grows past low/moderate traffic**, move to a paid tile
  provider (e.g. MapTiler, Stadia Maps, Thunderforest) or a self-hosted tile
  server, and only change `TileLayer.urlTemplate` — nothing else in the app
  depends on which server is behind that URL.

## 2. Nothing to configure locally

`flutter run` (any platform, any developer machine) renders real map tiles
immediately. There is no `maps.local.json`, no per-developer key exchange, no
"Map unavailable" fallback state to fight with — `.env.example` documents
this directly instead of listing key names to fill in.

## 3. Android release signing (unrelated to maps, kept here for continuity)

This section predates the OSM switch and is unchanged by it — release builds
still need a real signing identity, so it stays documented here rather than
being dropped.

Release builds read the project-specific keystore from
`.local/tripjournal-release.jks` through `.local/android-signing.properties`.
Both files are ignored by Git. A Release build fails clearly when that
configuration is missing instead of falling back to the debug certificate.
**These two files must be backed up together** — losing the private key
prevents future APK updates from being installed over an older
course-distribution build.

Read a built APK's signing certificate SHA-1 without exposing a password:

```powershell
D:\Download\Android\Sdk\build-tools\36.0.0\apksigner.bat verify `
  --print-certs build\app\outputs\flutter-apk\app-release.apk
```

For the standard debug keystore on Windows:

```powershell
keytool -list -v -alias androiddebugkey `
  -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -storepass android -keypass android
```

## 4. Failure behavior and diagnostics

- `flutter_map` is a pure Dart widget, not a platform view — there is no
  native SDK auth/billing failure mode to catch, unlike the Google Maps SDK
  this replaced. A camera-controller error (e.g. a call issued before the map
  has attached) is still caught defensively and shows
  `TripMapUnavailableSurface` with **Retry**.
- If tiles don't load, it is almost always network connectivity, or
  `tile.openstreetmap.org` rate-limiting an unset/non-compliant User-Agent —
  check that `TileLayer.userAgentPackageName` is still set before assuming
  anything else is wrong.
