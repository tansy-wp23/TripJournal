# TripJournal Forms Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Trip and Entry forms into clear, accessible Sky & Aurora sections while preserving all validation, save, photo, location, health, restore, and discard behavior.

**Architecture:** Add one reusable presentational form-section widget built on the existing Aurora panel. Compose the existing form controls into these sections without moving persistence or validation logic, then add observable widget tests for headings, actions, responsiveness, and dark mode.

**Tech Stack:** Flutter, Material 3, Riverpod, flutter_test, existing TripJournal Aurora theme and repositories.

## Global Constraints

- Preserve the user's unstaged `web/index.html` change exactly.
- Do not stage `.superpowers/`.
- Keep all existing keys and business behavior used by tests and production flows.
- Support Android phone layouts first, including 320 logical pixels and text scale 1.3.
- Support independent Light and Dark themes.
- Do not add dependencies or expose local secrets.

---

## File Structure

- Create `lib/widgets/app_form_section.dart`: reusable icon, title, optional helper/action, and Aurora panel body.
- Create `test/app_form_section_test.dart`: semantic heading, action, and narrow-layout coverage.
- Modify `lib/features/trip/trip_form_screen.dart`: group details, dates, cover, and notes; improve save state and responsive width.
- Modify `test/trip_destination_form_test.dart`: assert user-visible Trip form hierarchy and accessible controls.
- Modify `lib/features/journal/screens/create_edit_entry_screen.dart`: group story, mood, photos, place, wellness, advice, and save state.
- Modify `test/create_edit_entry_validation_test.dart`: assert user-visible Entry form hierarchy and accessible controls.
- Reuse `lib/features/journal/widgets/health_log_form.dart` unchanged unless targeted tests expose a layout issue.

### Task 1: Reusable Form Section

**Files:**
- Create: `lib/widgets/app_form_section.dart`
- Create: `test/app_form_section_test.dart`

**Interfaces:**
- Consumes: `AuroraPanel`, current `ThemeData`, and arbitrary child/action widgets.
- Produces: `AppFormSection({Key? key, required String title, required IconData icon, String? helperText, Widget? action, required Widget child})`.

- [ ] **Step 1: Write the failing widget tests**

Add tests that pump an `AppFormSection` and assert the title is exposed as a semantic header, the helper and supplied action are visible, and a 320-pixel layout has no Flutter overflow exception.

- [ ] **Step 2: Run the focused test to verify RED**

Run `flutter test --no-pub test/app_form_section_test.dart` and expect failure because `AppFormSection` does not exist.

- [ ] **Step 3: Implement the section**

Build the header with a themed icon tile, a semantic heading, optional helper below the title, and an optional trailing action that wraps below on narrow widths. Place the supplied body in `AuroraPanel` with consistent spacing.

- [ ] **Step 4: Run the focused test to verify GREEN**

Run `flutter test --no-pub test/app_form_section_test.dart` and expect all tests to pass.

- [ ] **Step 5: Commit**

Stage only the new widget and test, then commit `feat(ui): add reusable form sections`.

### Task 2: Trip Form Hierarchy

**Files:**
- Modify: `lib/features/trip/trip_form_screen.dart`
- Modify: `test/trip_destination_form_test.dart`

**Interfaces:**
- Consumes: `AppFormSection`, existing field keys, validators, date pickers, cover draft, save, restore, and delete callbacks.
- Produces: sections named `Trip details`, `Travel dates`, `Cover photo`, and `Notes`; an accessible full-width primary save action.

- [ ] **Step 1: Write the failing Trip form test**

Extend the destination test to assert each section heading appears once, the save action remains discoverable by `save-trip-button`, and the date controls retain their visible labels.

- [ ] **Step 2: Run the focused test to verify RED**

Run `flutter test --no-pub test/trip_destination_form_test.dart` and expect missing section headings.

- [ ] **Step 3: Implement the Trip form redesign**

Constrain the form to a readable centered width, use adaptive horizontal padding, place title/destination, dates/error, cover preview/action, and notes into the named sections, add concise helper text, keep every existing key/callback, and show a progress indicator plus `Saving…` or `Restoring…` while disabled.

- [ ] **Step 4: Run Trip form regression tests**

Run `flutter test --no-pub test/trip_destination_form_test.dart test/trip_form_cover_photo_test.dart test/trip_form_overlap_test.dart test/trip_form_restore_test.dart test/responsive_layout_test.dart` and expect all tests to pass.

- [ ] **Step 5: Commit**

Stage only the Trip form and its test, then commit `feat(ui): redesign Trip form`.

### Task 3: Entry Form Hierarchy

**Files:**
- Modify: `lib/features/journal/screens/create_edit_entry_screen.dart`
- Modify: `test/create_edit_entry_validation_test.dart`

**Interfaces:**
- Consumes: `AppFormSection`, existing dirty tracking, mood picker, photo/location callbacks, `HealthLogForm`, advice generation, confirmation, and persistence.
- Produces: sections named `Your story`, `Mood`, `Photos`, `Place`, `Wellness`, and conditional `AI suggestion`; an accessible save status/action.

- [ ] **Step 1: Write the failing Entry form test**

Extend validation coverage to assert the main section headings, visible field labels, photo/location actions, and save action are present on a new entry.

- [ ] **Step 2: Run the focused test to verify RED**

Run `flutter test --no-pub test/create_edit_entry_validation_test.dart` and expect missing section headings.

- [ ] **Step 3: Implement the Entry form redesign**

Constrain the form to a readable centered width with adaptive padding. Compose existing controls into the named sections, move add-photo and add/change-location actions into section headers/body, theme empty states and advice, keep all keys and callbacks, and show `Saving…` with progress while saving without changing the saved/dirty contract.

- [ ] **Step 4: Run Entry form regression tests**

Run the validation, save-flow, discard, day derivation, health prefill, location, photo, meal, health-form, and responsive widget tests; expect all to pass.

- [ ] **Step 5: Commit**

Stage only the Entry screen and its test, then commit `feat(ui): redesign Entry form`.

### Task 4: Phase Verification

**Files:**
- Verify only; modify production or tests only to correct a demonstrated regression.

**Interfaces:**
- Consumes: completed Trip and Entry form redesign.
- Produces: analyzer-clean, test-clean form phase with preserved local user files.

- [ ] **Step 1: Format changed Dart files**

Run `dart format` on the explicitly changed Dart files only.

- [ ] **Step 2: Run static analysis**

Run `flutter analyze --no-pub` and require zero issues.

- [ ] **Step 3: Run the full Flutter test suite**

Run `flutter test --no-pub` and require zero failures; platform-conditional skips are acceptable.

- [ ] **Step 4: Verify protected workspace state**

Confirm the `web/index.html` SHA-256 remains `DA5E56E066F95C40328B72A2B286E8BBBF630BA6B0BA92097645231AF0814BD2` and `.superpowers/` is untracked and unstaged.

- [ ] **Step 5: Commit any verified corrective change**

If verification required a correction, stage only the named production/test files and commit it separately; otherwise make no extra commit.
