# TripJournal Action Hierarchy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace unexplained icon rows with a consistent, labelled action hierarchy across the TripJournal user app and Admin while preserving every existing behavior and data flow.

**Architecture:** Add stateless shared action/header components under `lib/widgets` that receive callbacks and never read providers. Migrate screens in functional groups, keeping existing widget keys on their equivalent controls and moving contextual actions beside the content they affect. Controllers, repositories, models, Supabase calls, and persistence remain unchanged.

**Tech Stack:** Flutter 3.44.x, Dart, Material 3, Riverpod, flutter_test.

## Global Constraints

- Preserve the existing Sky & Aurora Light, Dark, and System themes.
- Use Flutter Material vector icons; add no icon package or asset dependency.
- Keep every interactive Android touch target at least 48 by 48 dp.
- Keep existing behavior, navigation destinations, widget keys, controllers, repositories, Supabase data, and confirmations intact.
- App bars contain navigation, a readable title, and at most one trailing primary action or overflow entry.
- Search, filtering, sorting, and clear-filter actions live beside the content they affect.
- Destructive actions are labelled, visually separated, and protected by existing confirmations.
- Android phone layouts are primary; narrow phone, landscape, large text, and Web layouts must remain usable.
- Do not stage or modify the user's existing `web/index.html` change or the untracked `.superpowers/` directory.
- Do not create or modify cloud data during visual verification.

---

### Task 1: Shared action hierarchy components

**Files:**
- Create: `lib/widgets/app_page_header.dart`
- Create: `lib/widgets/app_content_toolbar.dart`
- Create: `lib/widgets/app_action_menu.dart`
- Create: `lib/widgets/app_navigation_tile.dart`
- Modify: `lib/theme/aurora_theme.dart`
- Test: `test/app_action_widgets_test.dart`

**Interfaces:**
- Consumes: `AppSpacing`, `AppRadii`, and theme colours from the existing theme foundation.
- Produces: `AppPageHeader`, `AppContentToolbar`, `AppActionMenu<T>`, `AppActionMenuItem<T>`, and `AppNavigationTile` for Tasks 2–6.

- [ ] **Step 1: Write failing shared-component tests**

```dart
testWidgets('AppActionMenu renders labelled rows and separates destructive actions', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(appBar: AppBar(actions: [
    AppActionMenu<String>(
      tooltip: 'More actions',
      onSelected: (_) {},
      items: const [
        AppActionMenuItem(value: 'edit', label: 'Edit', icon: Icons.edit_outlined),
        AppActionMenuItem(
          value: 'delete',
          label: 'Move to Trash',
          icon: Icons.delete_outline,
          destructive: true,
          startsSection: true,
        ),
      ],
    ),
  ]))));
  await tester.tap(find.byTooltip('More actions'));
  await tester.pumpAndSettle();
  expect(find.text('Edit'), findsOneWidget);
  expect(find.text('Move to Trash'), findsOneWidget);
  expect(find.byType(PopupMenuDivider), findsOneWidget);
});

testWidgets('AppContentToolbar wraps controls and exposes active filter state', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppContentToolbar(
    resultLabel: '5 entries',
    activeFilterLabel: '2 filters active',
    children: [Text('Search'), Text('Filter')],
  ))));
  expect(find.text('5 entries'), findsOneWidget);
  expect(find.text('2 filters active'), findsOneWidget);
  expect(tester.getSize(find.byType(AppContentToolbar)).height, greaterThanOrEqualTo(48));
});
```

- [ ] **Step 2: Run the tests and verify the missing types fail**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\app_action_widgets_test.dart`

Expected: FAIL because the four shared action component files and classes do not exist.

- [ ] **Step 3: Implement the shared component contracts**

```dart
final class AppActionMenuItem<T> {
  const AppActionMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.key,
    this.destructive = false,
    this.startsSection = false,
  });
  final T value;
  final String label;
  final IconData icon;
  final Key? key;
  final bool destructive;
  final bool startsSection;
}

class AppActionMenu<T> extends StatelessWidget {
  const AppActionMenu({
    super.key,
    required this.tooltip,
    required this.items,
    required this.onSelected,
  });
  final String tooltip;
  final List<AppActionMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  // Build PopupMenuEntry<T> values, insert PopupMenuDivider before
  // startsSection items, use ListTile with visible labels, and use
  // colorScheme.error for destructive rows.
}
```

`AppPageHeader` accepts `title`, optional `eyebrow`, `subtitle`, and `action`.
`AppContentToolbar` accepts `resultLabel`, optional `activeFilterLabel`, and a
wrapping `List<Widget> children`. `AppNavigationTile` accepts `icon`, `title`,
optional `subtitle`, `onTap`, and optional `trailing`.

- [ ] **Step 4: Run shared component and theme tests**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\app_action_widgets_test.dart test\app_theme_test.dart test\ui_foundation_widgets_test.dart`

Expected: PASS with labelled menus, 48 dp targets, and Light/Dark rendering.

- [ ] **Step 5: Commit the shared foundation**

```powershell
git add -- lib/widgets/app_page_header.dart lib/widgets/app_content_toolbar.dart lib/widgets/app_action_menu.dart lib/widgets/app_navigation_tile.dart lib/theme/aurora_theme.dart test/app_action_widgets_test.dart
git commit -m "feat(ui): add shared action hierarchy components"
```

### Task 2: Trip detail and Entries action hierarchy

**Files:**
- Modify: `lib/features/trip/trip_view_screen.dart`
- Modify: `lib/features/trip/widgets/journal_search_bar.dart`
- Modify: `lib/features/admin/widgets/report_issue_button.dart`
- Modify: `test/trip_view_screen_test.dart`
- Modify: `test/trip_view_search_test.dart`
- Modify: `test/trip_view_map_tab_test.dart`
- Modify: `test/pdf_export_button_test.dart`
- Modify: `test/report_issue_button_test.dart`

**Interfaces:**
- Consumes: `AppActionMenu<T>` and `AppContentToolbar` from Task 1.
- Produces: a Trip app bar with only `trip-view-more-menu`, plus Entries-only controls retaining `trip-view-search-toggle` and `trip-view-filter-button`.

- [ ] **Step 1: Rewrite Trip action tests to express the new hierarchy**

```dart
expect(find.byKey(const Key('trip-view-more-menu')), findsOneWidget);
expect(find.byKey(const Key('trip-view-edit-button')), findsNothing);
expect(find.byKey(const Key('trip-view-delete-button')), findsNothing);
expect(find.byKey(const Key('report-issue-button')), findsNothing);
expect(find.byKey(const Key('trip-view-search-toggle')), findsOneWidget);
expect(find.byKey(const Key('trip-view-filter-button')), findsOneWidget);

await tester.tap(find.byKey(const Key('trip-view-more-menu')));
await tester.pumpAndSettle();
expect(find.text('Edit trip'), findsOneWidget);
expect(find.text('Export trip as PDF'), findsOneWidget);
expect(find.text('Report an issue'), findsOneWidget);
expect(find.text('Move to Trash'), findsOneWidget);
```

Add an assertion that tapping Map removes the entire Entries toolbar and leaves
only one app-bar overflow action. Keep the old keys on the labelled menu rows so
navigation, publishing, PDF, and deletion tests continue to address the same
actions.

- [ ] **Step 2: Run targeted tests and verify the old icon row fails the assertions**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\trip_view_screen_test.dart test\trip_view_search_test.dart test\trip_view_map_tab_test.dart test\pdf_export_button_test.dart test\report_issue_button_test.dart`

Expected: FAIL because edit, delete, and report are still standalone app-bar icons and search/filter are not inside the shared toolbar.

- [ ] **Step 3: Replace the Trip app-bar actions and add the contextual toolbar**

Extend `_TripViewMenuAction` with `edit`, `reportIssue`, and `moveToTrash`. Build
one `AppActionMenu<_TripViewMenuAction>` with the existing keys:

```dart
AppActionMenu<_TripViewMenuAction>(
  key: const Key('trip-view-more-menu'),
  tooltip: 'More trip actions',
  onSelected: (action) => _handleTripAction(action, trip, tripEntries, tripPhotos),
  items: [
    const AppActionMenuItem(
      key: Key('trip-view-edit-button'),
      value: _TripViewMenuAction.edit,
      label: 'Edit trip',
      icon: Icons.edit_outlined,
    ),
    // Existing publish/share/export/food actions retain their keys.
    const AppActionMenuItem(
      key: Key('report-issue-button'),
      value: _TripViewMenuAction.reportIssue,
      label: 'Report an issue',
      icon: Icons.report_problem_outlined,
      startsSection: true,
    ),
    const AppActionMenuItem(
      key: Key('trip-view-delete-button'),
      value: _TripViewMenuAction.moveToTrash,
      label: 'Move to Trash',
      icon: Icons.delete_outline,
      destructive: true,
      startsSection: true,
    ),
  ],
)
```

Extract `showReportIssueDialog(BuildContext, {required String page, required Future<String?> Function() userIdProvider})` from `ReportIssueButton` so the menu action opens the existing form without duplicating submission logic.

Place Search and Filter inside `AppContentToolbar` above the Entries list. Keep
the filter badge, active-count semantics, query clearing, and Map tab behavior.

- [ ] **Step 4: Run Trip action, publish, deletion, search, map, and PDF tests**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\trip_view_screen_test.dart test\trip_view_search_test.dart test\trip_view_map_tab_test.dart test\trip_publish_test.dart test\pdf_export_button_test.dart test\report_issue_button_test.dart test\responsive_layout_test.dart`

Expected: PASS; the title has room, all actions remain reachable, and Entries filters retain their state through Map tab switches.

- [ ] **Step 5: Commit the Trip action redesign**

```powershell
git add -- lib/features/trip/trip_view_screen.dart lib/features/trip/widgets/journal_search_bar.dart lib/features/admin/widgets/report_issue_button.dart test/trip_view_screen_test.dart test/trip_view_search_test.dart test/trip_view_map_tab_test.dart test/pdf_export_button_test.dart test/report_issue_button_test.dart
git commit -m "feat(ui): restructure Trip actions"
```

### Task 3: Entry details and remaining user-screen actions

**Files:**
- Modify: `lib/features/journal/screens/entry_detail_screen.dart`
- Modify: `lib/features/community/community_screen.dart`
- Modify: `lib/features/community/public_trip_view_screen.dart`
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/profile/screens/profile_view_screen.dart`
- Modify: `lib/features/trip/trip_form_screen.dart`
- Modify: `lib/features/journal/screens/create_edit_entry_screen.dart`
- Modify: `lib/features/location/place_picker_screen.dart`
- Test: `test/entry_detail_action_test.dart`
- Modify: `test/community_screen_test.dart`
- Modify: `test/public_trip_view_screen_test.dart`
- Modify: `test/profile_view_screen_test.dart`
- Modify: `test/responsive_layout_test.dart`

**Interfaces:**
- Consumes: shared headers, toolbars, action menus, and navigation tiles from Task 1.
- Produces: consistent user-facing app bars with no more than one trailing action and labelled destructive menu rows.

- [ ] **Step 1: Add failing tests for Entry and user-screen action limits**

```dart
testWidgets('Entry detail exposes one edit action and a labelled overflow menu', (tester) async {
  await tester.pumpWidget(buildEntryDetailHarness());
  await tester.pumpAndSettle();
  final appBar = tester.widget<AppBar>(find.byType(AppBar));
  expect(appBar.actions, hasLength(2)); // Edit plus More.
  await tester.tap(find.byTooltip('More entry actions'));
  await tester.pumpAndSettle();
  expect(find.text('Export entry as PDF'), findsOneWidget);
  expect(find.text('Move to Trash'), findsOneWidget);
});
```

Add responsive assertions that Community, public Trip, Profile, Trip form, Entry
form, and Place picker titles are not replaced by ellipsized icon rows at 320 dp.

- [ ] **Step 2: Run targeted user-screen tests and verify failures**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\entry_detail_action_test.dart test\community_screen_test.dart test\public_trip_view_screen_test.dart test\profile_view_screen_test.dart test\responsive_layout_test.dart`

Expected: FAIL because Entry detail still has three standalone actions and remaining page actions do not yet share the hierarchy.

- [ ] **Step 3: Implement the user-screen action audit**

For Entry detail, keep Edit visible and move PDF/Delete into
`AppActionMenu<_EntryAction>`, retaining the existing edit and delete keys and
confirmation behavior. For each other listed screen:

- keep one trailing primary action or overflow entry in the app bar;
- keep list search/filter controls in their existing content toolbars;
- use labelled Save/Done/Confirm actions for forms and place selection;
- keep conventional Back/Close icon-only controls;
- add missing tooltips and semantic labels;
- preserve all existing callbacks and test keys.

Use `AppNavigationTile` for Profile navigation destinations and labelled public
Trip actions where the current icon lacks context.

- [ ] **Step 4: Run all affected user-flow tests**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\entry_detail_action_test.dart test\community_screen_test.dart test\public_trip_view_screen_test.dart test\profile_view_screen_test.dart test\trip_form_overlap_test.dart test\create_edit_entry_save_flow_test.dart test\place_picker_screen_test.dart test\responsive_layout_test.dart`

Expected: PASS with unchanged navigation, validation, location, and account behavior.

- [ ] **Step 5: Commit user-screen consistency changes**

```powershell
git add -- lib/features/journal/screens/entry_detail_screen.dart lib/features/community/community_screen.dart lib/features/community/public_trip_view_screen.dart lib/features/home/home_screen.dart lib/features/profile/screens/profile_view_screen.dart lib/features/trip/trip_form_screen.dart lib/features/journal/screens/create_edit_entry_screen.dart lib/features/location/place_picker_screen.dart test/entry_detail_action_test.dart test/community_screen_test.dart test/public_trip_view_screen_test.dart test/profile_view_screen_test.dart test/responsive_layout_test.dart
git commit -m "feat(ui): unify user screen actions"
```

### Task 4: Admin dashboard navigation hierarchy

**Files:**
- Modify: `lib/features/admin/screens/admin_dashboard_screen.dart`
- Modify: `test/admin_dashboard_screen_test.dart`
- Modify: `test/admin_logout_test.dart`
- Modify: `test/responsive_layout_test.dart`

**Interfaces:**
- Consumes: `AppPageHeader`, `AppNavigationTile`, and `AppActionMenu<T>` from Task 1.
- Produces: labelled Admin navigation cards retaining `admin-manage-users`, `admin-issue-reports`, `admin-audit-log`, and `admin-monitoring`; `admin-logout` moves into the sole app-bar menu.

- [ ] **Step 1: Change Admin dashboard tests to require labelled navigation**

```dart
expect(find.text('Manage users'), findsOneWidget);
expect(find.text('Issue reports'), findsOneWidget);
expect(find.text('Audit log'), findsOneWidget);
expect(find.text('Monitoring'), findsOneWidget);
expect(tester.widget<AppBar>(find.byType(AppBar)).actions, hasLength(1));

await tester.tap(find.byTooltip('Admin account actions'));
await tester.pumpAndSettle();
expect(find.text('Sign out'), findsOneWidget);
expect(find.byKey(const Key('admin-logout')), findsOneWidget);
```

Keep existing navigation tests tapping the original keys so the new labelled
tiles prove they call the same routes.

- [ ] **Step 2: Run dashboard and logout tests and verify failure**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\admin_dashboard_screen_test.dart test\admin_logout_test.dart test\responsive_layout_test.dart`

Expected: FAIL because Dashboard still has five icon-only app-bar actions.

- [ ] **Step 3: Build the labelled Admin navigation section**

Replace the four navigation `IconButton`s with a responsive `Wrap` of
`AppNavigationTile`s. Use one or two columns based on `LayoutBuilder` width.
Keep stat cards in their existing grid and label the new section `Admin tools`.
Replace the app-bar actions with one account menu containing the existing
`admin-logout` key and callback.

- [ ] **Step 4: Run Dashboard, routing, logout, theme, and responsive tests**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\admin_dashboard_screen_test.dart test\admin_logout_test.dart test\admin_gate_back_navigation_test.dart test\app_theme_test.dart test\responsive_layout_test.dart`

Expected: PASS; all Admin destinations remain reachable by labelled controls.

- [ ] **Step 5: Commit the Admin dashboard redesign**

```powershell
git add -- lib/features/admin/screens/admin_dashboard_screen.dart test/admin_dashboard_screen_test.dart test/admin_logout_test.dart test/responsive_layout_test.dart
git commit -m "feat(ui): redesign Admin navigation"
```

### Task 5: Admin search, filters, and monitoring toolbars

**Files:**
- Modify: `lib/features/admin/screens/admin_user_list_screen.dart`
- Modify: `lib/features/admin/screens/admin_issue_report_list_screen.dart`
- Modify: `lib/features/admin/screens/audit_log_screen.dart`
- Modify: `lib/features/admin/screens/system_error_log_screen.dart`
- Modify: `lib/features/admin/screens/ai_request_monitoring_screen.dart`
- Modify: `lib/features/admin/screens/system_monitoring_screen.dart`
- Modify: `test/admin_user_list_screen_test.dart`
- Modify: `test/admin_issue_report_list_screen_test.dart`
- Modify: `test/audit_log_screen_test.dart`
- Modify: `test/system_error_log_screen_test.dart`
- Modify: `test/ai_request_monitoring_screen_test.dart`
- Modify: `test/system_monitoring_screen_test.dart`

**Interfaces:**
- Consumes: `AppContentToolbar` and `AppNavigationTile` from Task 1.
- Produces: labelled, responsive search/filter regions; existing clear-filter keys move out of app bars and Failed requests becomes a labelled page action.

- [ ] **Step 1: Add failing Admin toolbar assertions**

```dart
expect(find.byType(AppContentToolbar), findsOneWidget);
expect(find.textContaining('results'), findsOneWidget);
expect(find.byKey(const Key('admin-audit-log-clear-filters')), findsNothing);

await tester.tap(find.byKey(const Key('admin-audit-target-type-user')));
await tester.pumpAndSettle();
expect(find.byKey(const Key('admin-audit-log-clear-filters')), findsOneWidget);
expect(find.text('Clear filters'), findsOneWidget);
```

For AI monitoring, assert a labelled `Failed requests` action retains
`admin-ai-requests-failed`. For narrow-width tests, assert the Filter button is
48 dp and opens a bottom sheet containing the current choices.

- [ ] **Step 2: Run Admin list and monitoring tests and verify failures**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\admin_user_list_screen_test.dart test\admin_issue_report_list_screen_test.dart test\audit_log_screen_test.dart test\system_error_log_screen_test.dart test\ai_request_monitoring_screen_test.dart test\system_monitoring_screen_test.dart`

Expected: FAIL because clear-filter and Failed-request actions still occupy app bars or lack labelled toolbar treatment.

- [ ] **Step 3: Move contextual controls into responsive content toolbars**

Wrap each screen's existing search field, ChoiceChips, date/module controls,
result count, and conditional clear action in `AppContentToolbar`. At widths
below 600 dp, expose a labelled Filter button that opens a `showModalBottomSheet`
containing the same existing controls. At 600 dp and above, render controls
inline. Preserve controller methods, debounce behavior, keys, and empty-state
copy. Move Failed requests below the AI page header as a labelled action.

- [ ] **Step 4: Run Admin controller and screen regressions**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\admin_user_management_controller_test.dart test\admin_user_list_screen_test.dart test\issue_report_management_controller_test.dart test\admin_issue_report_list_screen_test.dart test\audit_log_controller_test.dart test\audit_log_screen_test.dart test\system_error_log_controller_test.dart test\system_error_log_screen_test.dart test\ai_request_monitoring_controller_test.dart test\ai_request_monitoring_screen_test.dart test\system_monitoring_screen_test.dart`

Expected: PASS with identical filtering results and clearer control placement.

- [ ] **Step 5: Commit Admin toolbar changes**

```powershell
git add -- lib/features/admin/screens/admin_user_list_screen.dart lib/features/admin/screens/admin_issue_report_list_screen.dart lib/features/admin/screens/audit_log_screen.dart lib/features/admin/screens/system_error_log_screen.dart lib/features/admin/screens/ai_request_monitoring_screen.dart lib/features/admin/screens/system_monitoring_screen.dart test/admin_user_list_screen_test.dart test/admin_issue_report_list_screen_test.dart test/audit_log_screen_test.dart test/system_error_log_screen_test.dart test/ai_request_monitoring_screen_test.dart test/system_monitoring_screen_test.dart
git commit -m "feat(ui): unify Admin filtering controls"
```

### Task 6: Admin details and full-screen consistency audit

**Files:**
- Modify: `lib/features/admin/screens/admin_user_detail_screen.dart`
- Modify: `lib/features/admin/screens/issue_report_detail_screen.dart`
- Modify: `lib/features/admin/screens/failed_ai_requests_screen.dart`
- Modify: `lib/features/admin/screens/monitoring_report_screen.dart`
- Modify: `lib/features/admin/screens/system_health_screen.dart`
- Modify: `lib/features/auth/screens/code_entry_screen.dart`
- Modify: `lib/features/auth/screens/delete_account_screen.dart`
- Modify: `test/admin_user_detail_screen_test.dart`
- Modify: `test/issue_report_detail_screen_test.dart`
- Modify: `test/failed_ai_requests_screen_test.dart`
- Modify: `test/monitoring_report_screen_test.dart`
- Modify: `test/system_health_screen_test.dart`
- Modify: `test/code_entry_screen_test.dart`
- Modify: `test/delete_account_screen_test.dart`
- Modify: `test/responsive_layout_test.dart`

**Interfaces:**
- Consumes: all shared action components and rules from Task 1.
- Produces: labelled state-changing actions, sectioned detail layouts, and a final app-wide guarantee that no nonstandard screen exposes an unexplained action row.

- [ ] **Step 1: Add failing consistency tests for state-changing actions**

```dart
expect(find.text('Suspend user'), findsOneWidget);
expect(find.text('Reactivate user'), findsNothing);
expect(find.byTooltip('Suspend user'), findsNothing); // action is visibly labelled.
```

Add equivalent visible-label assertions for Resolve, Retry, Export report,
Delete account, and verification-code completion. Add a responsive helper that
pumps each listed screen at 320 dp and asserts `tester.takeException()` is null.

- [ ] **Step 2: Run detail/auth tests and verify failures**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\admin_user_detail_screen_test.dart test\issue_report_detail_screen_test.dart test\failed_ai_requests_screen_test.dart test\monitoring_report_screen_test.dart test\system_health_screen_test.dart test\code_entry_screen_test.dart test\delete_account_screen_test.dart test\responsive_layout_test.dart`

Expected: FAIL where state changes are icon-only, visually mixed with navigation, or overflow at narrow widths.

- [ ] **Step 3: Apply the action hierarchy to details and auth edge screens**

Use `AppPageHeader` and `AppFormSection` to establish title, supporting status,
and section order. Render Suspend, Reactivate, Resolve, Retry, Export, and Delete
as visible labelled buttons or action tiles. Keep existing dialogs, remark
requirements, loading states, error messages, provider calls, and keys. Place
destructive actions after a divider or in a dedicated safety section using the
theme error colour.

- [ ] **Step 4: Run every affected Admin and auth test**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test\admin_user_detail_screen_test.dart test\issue_report_detail_screen_test.dart test\failed_ai_requests_screen_test.dart test\monitoring_report_screen_test.dart test\system_health_screen_test.dart test\code_entry_screen_test.dart test\delete_account_screen_test.dart test\suspend_confirmation_dialog_test.dart test\reactivate_confirmation_dialog_test.dart test\leaving_resolved_remark_dialog_test.dart test\responsive_layout_test.dart`

Expected: PASS with unchanged mutation and confirmation behavior.

- [ ] **Step 5: Commit Admin detail and consistency changes**

```powershell
git add -- lib/features/admin/screens/admin_user_detail_screen.dart lib/features/admin/screens/issue_report_detail_screen.dart lib/features/admin/screens/failed_ai_requests_screen.dart lib/features/admin/screens/monitoring_report_screen.dart lib/features/admin/screens/system_health_screen.dart lib/features/auth/screens/code_entry_screen.dart lib/features/auth/screens/delete_account_screen.dart test/admin_user_detail_screen_test.dart test/issue_report_detail_screen_test.dart test/failed_ai_requests_screen_test.dart test/monitoring_report_screen_test.dart test/system_health_screen_test.dart test/code_entry_screen_test.dart test/delete_account_screen_test.dart test/responsive_layout_test.dart
git commit -m "feat(ui): polish Admin and account actions"
```

### Task 7: Full verification and Android Light/Dark acceptance

**Files:**
- Modify only if verification exposes a scoped defect in files from Tasks 1–6.

**Interfaces:**
- Consumes: completed user and Admin UI hierarchy.
- Produces: evidence that the redesign is regression-safe and visually coherent.

- [ ] **Step 1: Run static analysis**

Run: `D:\Download\flutter-sdk\bin\flutter.bat analyze --no-pub`

Expected: `No issues found!`

- [ ] **Step 2: Run the complete Flutter test suite**

Run: `D:\Download\flutter-sdk\bin\flutter.bat test --no-pub`

Expected: all tests pass; only explicitly platform-conditional tests may skip.

- [ ] **Step 3: Verify protected workspace state**

```powershell
git status --short --branch
Get-FileHash -Algorithm SHA256 -LiteralPath 'D:\Download\TripJournal\web\index.html'
```

Expected: `web/index.html` remains unstaged with SHA256
`DA5E56E066F95C40328B72A2B286E8BBBF630BA6B0BA92097645231AF0814BD2`;
`.superpowers/` remains untracked.

- [ ] **Step 4: Run the configured Supabase/Maps Android build**

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
$env:GRADLE_USER_HOME='D:\FlutterCache\gradle'
D:\Download\flutter-sdk\bin\flutter.bat run -d emulator-5554 --dart-define=BACKEND_MODE=supabase --dart-define-from-file=.local\maps_defines.json
```

Expected: the app builds, installs, initializes Supabase, and opens without a
Flutter exception. Do not print the define file.

- [ ] **Step 5: Manually inspect user and Admin interfaces**

Verify in Light and Dark mode:

- Trip title remains readable and only one overflow action is in its app bar.
- Entries search/filter toolbar is visible; Map does not show Entries controls.
- Trip and Entry menus show labelled routine and separated destructive actions.
- Admin Dashboard shows labelled tools and one account menu.
- Admin filter screens show labelled filter state and clear actions.
- Admin state-changing actions remain labelled and confirmed.
- 320 dp phone, emulator phone portrait/landscape, and large text do not clip or
  hide controls.

- [ ] **Step 6: Commit only scoped verification fixes, if any**

```powershell
$verificationFiles = git diff --name-only -- lib test
if ($verificationFiles) {
  git add -- $verificationFiles
  git commit -m "fix(ui): resolve action hierarchy regressions"
}
```

If no fix is required, do not create an empty commit.
