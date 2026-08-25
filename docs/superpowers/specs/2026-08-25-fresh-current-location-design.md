# Fresh Current Location Design

## Problem

`Use my location` currently delegates to a medium-accuracy one-shot position
request. On Android, the fused location provider can satisfy that request with
an old cached coordinate before the emulator or device supplies a new GPS
update. The picker then reverse-geocodes and displays that stale coordinate.

## Scope

The fix applies only to the user-triggered foreground location request in the
place picker. It does not add continuous tracking, background location,
location history, a map blue dot, or automatic permission prompts.

## Design

On Android and iOS, the location gateway will open a short-lived,
high-accuracy position stream after permission is granted. It records the
request start time, ignores positions whose timestamps predate that request,
and returns the first fresh position. The subscription is cancelled
immediately after success or failure. A 15-second timeout maps to the existing
`CurrentLocationFailure.unavailable` result.

The browser keeps its current one-shot geolocation request because browser
permission and secure-context behavior differ from native location streams.
Desktop platforms remain unsupported.

The service boundary continues to return only latitude and longitude to the
picker. Timestamp and stream lifecycle details remain inside the gateway, so
the UI, reverse geocoding, confirmation flow, and stored `GeoTag` schema do not
change.

## Error Handling

- Stale positions are ignored rather than displayed.
- Timeout or provider errors leave the previously selected location intact.
- Existing permission-denied, permission-denied-forever, service-disabled,
  insecure-origin, and unsupported-platform messages remain unchanged.
- A successful fresh coordinate is still reverse-geocoded; reverse-geocoding
  failure continues to allow coordinate-only confirmation.

## Testing

Automated tests will prove that the native path requests a fresh position,
does not return an older cached position, cancels after the first acceptable
update, and maps a no-fresh-update timeout to `unavailable`. Existing web and
permission tests must remain green.

Final verification consists of the focused current-location and place-picker
tests, `flutter analyze`, the complete Flutter test suite, and an Android
emulator check where a changed virtual coordinate replaces the old Mountain
View coordinate.
