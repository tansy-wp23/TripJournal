# TripJournal Community, Profile, Settings, and Auth Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the Sky & Aurora redesign across Community discovery, Profile, Settings, guest browsing, and authentication without changing their existing data or account flows.

**Architecture:** Recompose existing provider-driven screens with the shared theme, panels, section headers, and responsive width constraints. Keep controllers, repositories, navigation results, widget keys, dialogs, and account lifecycle behavior intact; add focused widget tests for user-visible hierarchy and accessibility before each screen group.

**Tech Stack:** Flutter, Material 3, Riverpod, flutter_test, existing TripJournal theme and shared widgets.

## Global Constraints

- Android phone is the primary layout; Web must remain usable.
- Support System, Light, and independently designed Dark themes.
- Keep all interface copy in English and reuse the existing logo artwork.
- Do not change repositories, Supabase calls, validation rules, or persistence formats.
- Preserve existing widget keys, guest/auth flows, confirmations, and root-tab state.
- Preserve `web/index.html` with SHA-256 `DA5E56E066F95C40328B72A2B286E8BBBF630BA6B0BA92097645231AF0814BD2`.
- Do not stage `.superpowers/` or add dependencies.

---

### Task 1: Community Discovery

**Files:**
- Modify: `lib/features/community/community_screen.dart`
- Modify: `lib/features/community/widgets/public_trip_card.dart`
- Modify: `lib/features/community/public_trip_view_screen.dart`
- Modify: `test/community_screen_test.dart`

**Interfaces:**
- Consumes: `CommunityController`, destination filtering, ID lookup, guest `onSignIn`, and public-trip navigation.
- Produces: a photo-first feed headed by `Discover journeys`, a visible discovery toolbar, themed loading/error/empty states, and semantic public-trip cards.

- [ ] Write failing tests for the discovery heading, visible destination search affordance, semantic card tap label, and guest CTA.
- [ ] Run `flutter test --no-pub test/community_screen_test.dart` and confirm the new expectations fail.
- [ ] Center content at a readable maximum width, preserve pull-to-refresh and all search keys, style empty/error states as quiet illustrated panels, and make each trip card photo-led with destination, dates, publisher, publication context, and a chevron.
- [ ] Reuse the private Trip visual hierarchy in public detail while retaining read-only behavior and owner-only control exclusions.
- [ ] Run Community, guest-home, public-trip, and responsive tests and require zero failures.
- [ ] Commit only Community production/tests as `feat(ui): redesign Community discovery`.

### Task 2: Profile and Profile Editing

**Files:**
- Modify: `lib/features/profile/screens/profile_view_screen.dart`
- Modify: `lib/features/profile/screens/profile_edit_screen.dart`
- Modify only if needed: `lib/features/profile/widgets/profile_avatar.dart`
- Modify: `test/profile_edit_screen_test.dart`

**Interfaces:**
- Consumes: `ProfileController`, avatar picker/storage, country, birth date, travel interests, Settings/Recently Deleted navigation, logout, and account lifecycle routes.
- Produces: identity hero; `Travel preferences`, `App preferences`, and `Account` groups; sectioned profile editing with a persistent accessible save action.

- [ ] Write failing tests for the profile group hierarchy and the edit form's visible section headings.
- [ ] Run focused profile tests and confirm the new expectations fail.
- [ ] Redesign profile view with an identity hero, grouped navigation cards, explicit chevrons, and a visually separated account-safety area while preserving every callback and key.
- [ ] Redesign profile editing with responsive card sections, existing fields/selectors, avatar behavior, validation, and disabled/loading save feedback.
- [ ] Run profile controller/view/edit/onboarding, navigation, avatar, validation, and responsive tests.
- [ ] Commit only Profile production/tests as `feat(ui): redesign Profile experience`.

### Task 3: Settings and Recently Deleted

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`
- Modify only if needed: `lib/features/trip/trip_trash_screen.dart`
- Modify: `test/settings_screen_test.dart`

**Interfaces:**
- Consumes: `SettingsController`, theme mode, journal reminder, health connection, About/Legal dialogs, and existing trash navigation.
- Produces: `Appearance`, `Journal`, `Health`, and `About` card groups with clear System/Light/Dark preview choices.

- [ ] Write failing tests for the Settings group hierarchy and three labeled theme choices.
- [ ] Run focused Settings tests and confirm the new hierarchy expectations fail.
- [ ] Recompose Settings into responsive grouped cards; show System, Light, and Dark as explicit selected choices, keep reminder controls and health states, and retain About/Legal content and callbacks.
- [ ] Align Recently Deleted empty/list surfaces with the theme without changing expiration, restore, conflict, or refresh behavior.
- [ ] Run Settings preferences/controller/screen, trash, and responsive tests.
- [ ] Commit only Settings/trash production/tests as `feat(ui): redesign Settings and trash`.

### Task 4: Guest and Authentication

**Files:**
- Modify: `lib/features/guest/guest_home_screen.dart`
- Modify: `lib/features/auth/screens/login_screen.dart`
- Modify only as required for visual consistency: `lib/features/auth/screens/code_entry_screen.dart`, `reactivation_screen.dart`, `suspended_screen.dart`, `delete_account_screen.dart`
- Modify: `test/login_screen_admin_entry_test.dart`
- Modify: `test/guest_home_screen_test.dart`

**Interfaces:**
- Consumes: current artwork, hidden admin-entry gesture, Google sign-in callback/state, auth errors, guest Community, OTP and account lifecycle flows.
- Produces: Community-first guest browsing, concise brand/benefit presentation, obvious sign-in action, themed errors, and consistent auth cards.

- [ ] Write failing tests for login benefit copy/semantic primary action and guest Community-first presentation.
- [ ] Run focused guest/login tests and confirm the new expectations fail.
- [ ] Redesign Login with existing artwork, restrained aurora atmosphere, concise benefits, responsive centered card, current sign-in/error behavior, and the unchanged hidden admin gesture.
- [ ] Keep GuestHome as the Community host with a clear sign-in action; align OTP and lifecycle pages to the same card hierarchy only where existing layouts are inconsistent.
- [ ] Run auth gate/controller, login, guest, OTP, lifecycle, and responsive tests.
- [ ] Commit only guest/auth production/tests as `feat(ui): redesign guest and authentication`.

### Task 5: Phase Verification

**Files:**
- Verify only; make corrective edits only for demonstrated regressions.

**Interfaces:**
- Consumes: all four completed screen groups.
- Produces: analyzer-clean, test-clean main app ready for emulator acceptance.

- [ ] Format only explicitly changed Dart files.
- [ ] Run `flutter analyze --no-pub` and require zero issues.
- [ ] Run `flutter test --no-pub` and require zero failures; platform-conditional skips are acceptable.
- [ ] Confirm protected workspace state and the exact `web/index.html` SHA-256.
- [ ] Inspect the implementation against the redesign spec for Community, Profile, Settings, Guest/Auth, dark mode, semantics, and narrow layouts; correct only concrete gaps and rerun affected checks.
