# Fresh Current Location Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent `Use my location` from accepting a stale native location cached before the user started the request.

**Architecture:** Keep the existing `CurrentLocationService` boundary used by the picker. Native platforms consume a short-lived high-accuracy position stream and accept the first reading timestamped at or after the request start; web keeps its one-shot request. Timeout and permission behavior continue to use the existing failure enum.

**Tech Stack:** Flutter, Dart streams, `geolocator` 14.x, Flutter test.

## Global Constraints

- Location remains user-triggered and foreground-only.
- Do not add continuous tracking, background permissions, location history, or a map blue dot.
- Stop listening immediately after the first fresh reading or any failure.
- Native timeout is 15 seconds and maps to `CurrentLocationFailure.unavailable`.
- Web, desktop, reverse-geocoding, confirmation, and `GeoTag` persistence contracts remain unchanged.

---

### Task 1: Reject stale native readings

**Files:**
- Modify: `test/current_location_service_test.dart`
- Modify: `lib/features/location/current_location_service.dart`

**Interfaces:**
- Consumes: existing `CurrentLocationService.locate()` and permission flow.
- Produces: gateway-only `CurrentLocationReading`, `CurrentLocationGateway.getPositionStream()`, and constructor injection for a request clock and native timeout. The picker-facing `CurrentLocation` type remains latitude/longitude only.

- [ ] **Step 1: Write the failing stale-reading test**

Add a native service test with a controlled request time and stream:

```dart
test('native location ignores a reading cached before the request', () async {
  final requestedAt = DateTime.utc(2026, 8, 25, 4);
  final positions = StreamController<CurrentLocationReading>();
  addTearDown(positions.close);
  final gateway = _FakeCurrentLocationGateway()..positionStream = positions.stream;
  final service = GeolocatorCurrentLocationService(
    gateway: gateway,
    now: () => requestedAt,
  );

  final result = service.locate();
  positions.add(CurrentLocationReading(
    latitude: 37.421998,
    longitude: -122.084,
    timestamp: requestedAt.subtract(const Duration(minutes: 30)),
  ));
  positions.add(CurrentLocationReading(
    latitude: 3.139,
    longitude: 101.6869,
    timestamp: requestedAt,
  ));

  await expectLater(
    result,
    completion(
      isA<CurrentLocation>()
          .having((value) => value.latitude, 'latitude', 3.139)
          .having((value) => value.longitude, 'longitude', 101.6869),
    ),
  );
});
```

Update gateway test fixtures to return `CurrentLocationReading` values with literal timestamps, and give the fake gateway a `positionStream` field plus `getPositionStream()` implementation. Picker-facing `CurrentLocation` fixtures do not change.

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\current_location_service_test.dart
```

Expected: compilation fails because `CurrentLocationReading`, `now`, and `getPositionStream()` do not exist.

- [ ] **Step 3: Implement the minimal native fresh-stream path**

In `current_location_service.dart`:

```dart
class CurrentLocationReading {
  const CurrentLocationReading({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
}
```

Change the gateway one-shot return type to `Future<CurrentLocationReading>` and add `Stream<CurrentLocationReading> getPositionStream()`. Inject `DateTime Function() now` and `Duration nativeTimeout` into `GeolocatorCurrentLocationService`, defaulting to `DateTime.now` and 15 seconds. On native platforms, record the request time after permission succeeds, select the first non-stale reading, then map it back to the existing picker-facing `CurrentLocation`:

```dart
final reading = await _gateway
    .getPositionStream()
    .where((position) => !position.timestamp.isBefore(requestedAt))
    .first
    .timeout(_nativeTimeout);
return CurrentLocation(
  latitude: reading.latitude,
  longitude: reading.longitude,
);
```

Keep web on `_gateway.getCurrentPosition()`. Implement the production stream with `Geolocator.getPositionStream` using `LocationAccuracy.high`, `distanceFilter: 0`, and map each `Position` including its timestamp. Keep the production one-shot mapping for web.

- [ ] **Step 4: Run the focused test and confirm GREEN**

Run the command from Step 2. Expected: all current-location service tests pass.

- [ ] **Step 5: Commit Task 1**

```powershell
git add -- lib/features/location/current_location_service.dart test/current_location_service_test.dart
git commit -m "fix(location): wait for a fresh native position"
```

### Task 2: Verify picker behavior and integration

**Files:**
- Verify: `test/place_picker_screen_test.dart`

**Interfaces:**
- Consumes: unchanged picker-facing `CurrentLocation` from Task 1.
- Produces: verification evidence; no additional production interface changes.

- [ ] **Step 1: Run location and picker tests**

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test `
  test\current_location_service_test.dart `
  test\place_picker_screen_test.dart
```

Expected: all tests pass, including existing success, permission, timeout, reverse-geocoding, and no-concurrent-request cases.

- [ ] **Step 2: Run static analysis and the complete suite**

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat analyze
D:\Download\flutter-sdk\bin\flutter.bat test
```

Expected: analyzer exits 0 and the complete test suite reports zero failures.

- [ ] **Step 3: Android emulator verification**

Run with all caches on D: and the existing local map configuration when present. In the place picker, click `Use my location`, then send a new emulator location while the request is active. Verify the old Mountain View coordinate is ignored and the new coordinate is displayed; do not click `Use this location` unless persistence is also being tested.
