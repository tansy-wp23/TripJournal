# Trips Home Redesign Implementation Plan

> **For Codex:** Execute this plan task by task with test-driven development. Preserve the local `web/index.html` edit and do not add `.superpowers/` to Git.

**Goal:** Bring the Trips home screen into the Sky & Aurora design system while preserving its current search, filtering, navigation, refresh, and nested-action behavior.

**Architecture:** Keep `HomeScreen` as the state owner. Add a shell-aware presentation flag so the authenticated root shell can avoid duplicate Community navigation while standalone uses remain compatible. Compose the refreshed screen from the existing Aurora primitives and small private widgets; repositories and controllers remain unchanged.

**Tech Stack:** Flutter, Material 3, Riverpod, flutter_test.

---

### Task 1: Make the home header root-shell aware

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/navigation/authenticated_app_shell.dart`
- Test: `test/authenticated_app_shell_test.dart`

1. Add a failing widget test proving the root Trips destination has the new heading and no duplicate Community action.
2. Add an `embeddedInRootShell` presentation flag to `HomeScreen`.
3. Pass the flag from `AuthenticatedAppShell`; retain standalone defaults for existing focused tests.
4. Run the navigation and home widget tests.

### Task 2: Redesign the active-trip hero

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/widgets/aurora_panel.dart`
- Modify: `lib/features/trip/widgets/stat_tile.dart`
- Modify: `lib/features/trip/widgets/wellness_stats_row.dart`
- Test: `test/home_active_trip_card_tap_test.dart`
- Test: `test/ui_foundation_widgets_test.dart`

1. Add failing widget tests for the active-trip semantic structure and compact responsive stats.
2. Allow `AuroraPanel` to provide an ink-compatible interactive surface.
3. Rebuild the active trip as a layered aurora hero with clear trip progress, today prompt, and compact metrics.
4. Preserve the whole-card tap and nested write-entry action behavior.
5. Run the active-trip, nudge, and foundation widget tests in Light and Dark themes.

### Task 3: Refresh trip discovery and trip cards

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/trip/widgets/trip_list_controls.dart`
- Test: `test/trip_list_controls_test.dart`
- Test: `test/home_screen_nudge_test.dart`

1. Add failing tests for the section hierarchy and minimum control tap targets.
2. Use `AppSectionHeader`, improve filter/search composition, and update trip cards with destination/status metadata and a clear trailing affordance.
3. Keep all existing keys and filtering/sorting behavior.
4. Verify narrow Android and wider Web layouts do not overflow.

### Task 4: Verify and checkpoint the phase

1. Run all home/navigation/theme/widget tests.
2. Run `flutter analyze --no-pub`.
3. Run the full Flutter test suite.
4. Confirm `web/index.html` has the preserved SHA256 and inspect Git status before committing only the intended files.
