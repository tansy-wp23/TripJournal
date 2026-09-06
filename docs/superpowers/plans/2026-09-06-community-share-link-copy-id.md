# Community Share Link and Copy Trip ID Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Share only the TripJournal deep link for a published trip and add a neighboring menu action that copies only the raw trip ID.

**Architecture:** Keep the behavior inside the existing owner-facing `TripViewScreen`. Verify the share payload through the `share_plus` method channel and verify clipboard contents through Flutter's clipboard API, then add one overflow-menu action and its handler.

**Tech Stack:** Flutter, Dart, Material, `share_plus`, Flutter clipboard services, `flutter_test`

## Global Constraints

- The change applies only to the owner-facing Trip Details overflow menu.
- Share payload must be exactly `tripjournal://trip/<trip-id>` with no subject or explanatory text.
- Copy payload must be exactly the raw trip ID.
- Both actions are visible only for published trips.
- Copy confirmation text must be exactly `Trip ID copied`.
- Preserve the existing Community public-trip share button.
- Preserve the user's existing `web/index.html` modification.

---

### Task 1: Published Trip Sharing Actions

**Files:**
- Modify: `test/trip_view_screen_test.dart`
- Modify: `lib/features/trip/trip_view_screen.dart`

**Interfaces:**
- Consumes: `tripLinkFor(String tripId) -> String`, `Clipboard.setData(ClipboardData)`
- Produces: `_TripViewMenuAction.copyTripId`, menu key `trip-view-copy-id-button`

- [ ] **Step 1: Write failing widget tests**

Add tests that publish `trip-001`, open the overflow menu, and assert:

```dart
expect(find.byKey(const Key('trip-view-share-link-button')), findsOneWidget);
expect(find.byKey(const Key('trip-view-copy-id-button')), findsOneWidget);
```

Intercept `dev.fluttercommunity.plus/share`, tap **Share link**, and assert:

```dart
expect(call.method, 'share');
expect(call.arguments['text'], 'tripjournal://trip/trip-001');
expect(call.arguments['subject'], isNull);
```

Tap **Copy trip ID**, then assert:

```dart
final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
expect(clipboard?.text, 'trip-001');
expect(find.text('Trip ID copied'), findsOneWidget);
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\trip_view_screen_test.dart
```

Expected: FAIL because `trip-view-copy-id-button` does not exist and the current share payload includes explanatory text and a subject.

- [ ] **Step 3: Implement minimal behavior**

In `trip_view_screen.dart`:

```dart
void _shareTripLink(Trip trip) {
  Share.share(tripLinkFor(trip.id));
}

Future<void> _copyTripId(Trip trip) async {
  await Clipboard.setData(ClipboardData(text: trip.id));
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Trip ID copied')),
  );
}
```

Add `copyTripId` to `_TripViewMenuAction`, handle it in `onSelected`, and add a published-only menu item immediately after **Share link**:

```dart
const AppActionMenuItem(
  key: Key('trip-view-copy-id-button'),
  value: _TripViewMenuAction.copyTripId,
  label: 'Copy trip ID',
  icon: Icons.content_copy_outlined,
),
```

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the same focused test command. Expected: all tests pass.

- [ ] **Step 5: Commit the feature**

```powershell
git add -- test/trip_view_screen_test.dart lib/features/trip/trip_view_screen.dart
git commit -m "feat: simplify trip sharing and copy trip IDs"
```

### Task 2: Regression Verification

**Files:**
- Verify: `test/trip_link_test.dart`
- Verify: `test/trip_link_listener_test.dart`
- Verify: `test/trip_publish_test.dart`
- Verify: `test/public_trip_view_screen_test.dart`
- Verify: `lib/features/trip/trip_view_screen.dart`

**Interfaces:**
- Consumes: published-trip menu behavior completed in Task 1
- Produces: verified sharing and deep-link flow

- [ ] **Step 1: Run related regression tests**

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\trip_view_screen_test.dart test\trip_link_test.dart test\trip_link_listener_test.dart test\trip_publish_test.dart test\public_trip_view_screen_test.dart
```

Expected: all tests pass.

- [ ] **Step 2: Run static analysis**

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat analyze --no-pub
```

Expected: no issues found.

- [ ] **Step 3: Confirm scoped working tree**

Run `git status --short` and confirm that `web/index.html` remains untouched by this feature and all feature files are committed.
