# Trip Detail, Entries, and Map Redesign Plan

> **For Codex:** Execute with test-driven development. Preserve the existing journal/map ordering behavior, all public widget keys, the local `web/index.html` edit, and the untracked `.superpowers/` directory.

**Goal:** Apply the Sky & Aurora system to Trip detail, its Entries timeline, and Map presentation without changing repository, filtering, map route, or entry-order logic.

**Architecture:** Keep `TripViewScreen` and `TripMapView` as behavior owners. Extract only small reusable presentation widgets where repetition warrants it. The existing `TabController`, map model, journal filters, and navigation callbacks remain unchanged.

**Tech Stack:** Flutter, Material 3, Riverpod, google_maps_flutter, flutter_test.

---

### Task 1: Refresh the Trip header and local navigation

1. Add failing tests for destination/date hierarchy, photo-led header semantics, and an accessible `Entries | Map` control.
2. Restyle the app bar, trip header, facts, actions, notes, wellness, and summary surfaces using theme colors and shared components.
3. Preserve all overflow menu actions, photo navigation, export, publish, edit, and delete flows.
4. Run Trip View, notes, summary, photo, and responsive tests.

### Task 2: Refresh the Entries timeline

1. Add failing tests for visible day hierarchy, rich entry cards, and independent search/filter state.
2. Restyle day headers, empty days, entry cards, search, filter indicators, and contextual add-entry action.
3. Preserve day-first and immutable creation-order sorting, existing keys, scroll retention, photo indices, and edit/detail navigation.
4. Run all Trip View entries/search/filter/order tests.

### Task 3: Refresh Map controls and overlays

1. Add failing tests for map summary, filter grouping, route disclaimer, preview cards, and empty/fallback states.
2. Restyle day chips, counts, disclaimer, map container, previews, and fallback surfaces for Light/Dark contrast.
3. Do not change marker grouping, clustering, route segments/arrows, selected-day behavior, or map SDK integration.
4. Run all pure map model, Google map surface, and Trip map widget tests.

### Task 4: Verify and checkpoint

1. Run affected Trip, Entries, Map, theme, and responsive tests.
2. Run `flutter analyze --no-pub`.
3. Run the full Flutter suite.
4. Confirm the preserved `web/index.html` hash and commit only intended files.
