# Community Trip Sharing Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give another user's published-trip screen the same Share link and Copy trip ID actions as the owner's published-trip screen.

**Architecture:** Keep the change local to `PublicTripViewScreen`: replace its Share icon with the existing shared `AppActionMenu` and route the two menu values to focused share and clipboard methods. Reuse `tripLinkFor` for the direct URI and the same visible labels, keys, clipboard confirmation, and payload rules already used by `TripViewScreen`.

**Tech Stack:** Flutter, Dart, Material widgets, `share_plus`, Flutter Clipboard API, `flutter_test`.

## Global Constraints

- The public trip remains read-only; do not add edit, publish, unpublish, or delete actions.
- **Share link** sends only `tripjournal://trip/<trip-id>` with no title, instructions, subject, or other text.
- **Copy trip ID** copies only the raw Trip ID and displays `Trip ID copied`.
- Do not modify the user's existing `web/index.html` change.

---

### Task 1: Public Trip Sharing Menu

**Files:**
- Modify: `test/public_trip_view_screen_test.dart`
- Modify: `lib/features/community/public_trip_view_screen.dart`

**Interfaces:**
- Consumes: `String tripLinkFor(String tripId)`, `Share.share(String text)`, and `Clipboard.setData(ClipboardData data)`.
- Produces: popup menu keys `public-trip-more-menu`, `public-trip-share-link-button`, and `public-trip-copy-id-button`.

- [x] **Step 1: Write failing widget tests**

Import `package:flutter/services.dart` and add tests that open `public-trip-more-menu`. The first records calls to `dev.fluttercommunity.plus/share`, taps `public-trip-share-link-button`, and asserts the single call has `text == 'tripjournal://trip/trip-001'` and a null `subject`. The second records `Clipboard.setData`, taps `public-trip-copy-id-button`, and asserts the clipboard contains exactly `trip-001` and the screen displays `Trip ID copied`. Update the existing visibility assertion to require both menu actions after opening the menu.

- [x] **Step 2: Run the target test and verify RED**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\public_trip_view_screen_test.dart --no-pub
```

Expected: FAIL because `public-trip-more-menu`, `public-trip-share-link-button`, and `public-trip-copy-id-button` do not exist and the existing share function adds text and a subject.

- [x] **Step 3: Implement the minimal menu behaviour**

In `public_trip_view_screen.dart`:

1. Import `package:flutter/services.dart`.
2. Add a private enum with `shareLink` and `copyTripId` values.
3. Change `_shareTripLink()` to call `Share.share(tripLinkFor(widget.trip.id))`.
4. Add `_copyTripId()` that copies `widget.trip.id`, checks `mounted`, and shows `SnackBar(content: Text('Trip ID copied'))`.
5. Replace the current `IconButton` with the shared `AppActionMenu` keyed `public-trip-more-menu`. Add menu items labelled `Share link` and `Copy trip ID`, keyed `public-trip-share-link-button` and `public-trip-copy-id-button`, and dispatch each selection to its corresponding method.

- [x] **Step 4: Run the target test and verify GREEN**

Run the same target test and confirm every test in `public_trip_view_screen_test.dart` passes.

- [x] **Step 5: Run focused regression checks**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\public_trip_view_screen_test.dart test\trip_view_screen_test.dart test\trip_link_test.dart --no-pub
D:\Download\flutter-sdk\bin\flutter.bat analyze --no-pub
```

Expected: all focused tests pass and analysis reports no issues.

- [x] **Step 6: Commit the implementation**

```powershell
git add test/public_trip_view_screen_test.dart lib/features/community/public_trip_view_screen.dart docs/superpowers/plans/2026-09-06-community-trip-sharing-parity.md
git commit -m "feat: align community trip sharing actions"
```

- [x] **Step 7: Restart the running app**

Hot restart the existing Flutter run session so the user can test the new Community sharing menu on `emulator-5554`.
