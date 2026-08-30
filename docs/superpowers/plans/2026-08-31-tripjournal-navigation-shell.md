# TripJournal Navigation Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the approved authenticated root navigation for Trips, Community, and Profile while preserving each destination's state and existing navigation behavior.

**Architecture:** `AuthGate` routes authenticated users to a new stateful `AuthenticatedAppShell`. The shell owns a Material 3 `NavigationBar` and an `IndexedStack` of the existing destination screens, keeping each destination mounted so its search, filters, scroll position, and controller state survive tab switches.

**Tech Stack:** Flutter 3.44.x, Dart 3.12.x, Material 3, Riverpod, Flutter widget tests

## Global Constraints

- Android phones are the primary target; Web must remain usable and free of overflow.
- Interface copy remains English.
- Do not change controllers, repositories, models, Supabase calls, persistence formats, validation, or map behavior.
- Preserve existing widget keys used by tests and automation.
- Navigation destinations must have at least 48×48 dp touch targets through Material `NavigationBar`.
- Do not overwrite or stage the user's local `web/index.html` modification.

---

### Task 1: Authenticated root shell

**Files:**
- Create: `lib/features/navigation/authenticated_app_shell.dart`
- Modify: `lib/features/auth/auth_gate.dart`
- Modify: `lib/theme/app_theme.dart`
- Test: `test/authenticated_app_shell_test.dart`

**Interfaces:**
- Consumes: existing `HomeScreen`, `CommunityScreen`, and `ProfileViewScreen` widgets.
- Produces: `AuthenticatedAppShell({Key? key})`, navigation keys `nav-trips`, `nav-community`, and `nav-profile`.

- [ ] **Step 1: Write failing root navigation tests**

Create `test/authenticated_app_shell_test.dart` with a signed-in `AuthTestHarness`. Verify:

```dart
testWidgets('authenticated users receive three persistent root destinations', (
  tester,
) async {
  final harness = AuthTestHarness();
  addTearDown(harness.dispose);
  await harness.signIn();

  await tester.pumpWidget(harness.wrap(const AuthenticatedAppShell()));
  await tester.pumpAndSettle();

  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.text('Trips'), findsOneWidget);
  expect(find.text('Community'), findsOneWidget);
  expect(find.text('Profile'), findsOneWidget);
  expect(find.byType(HomeScreen), findsOneWidget);
});
```

Add a second test that taps `nav-community`, then `nav-profile`, and asserts the visible destination by using `find.byType(...).hitTestable()`. Add a third test that opens Home search, switches away and back, and asserts `trip-search-field` remains visible.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\authenticated_app_shell_test.dart
```

Expected: compilation fails because `AuthenticatedAppShell` does not exist.

- [ ] **Step 3: Implement the shell**

Create `lib/features/navigation/authenticated_app_shell.dart`:

```dart
class AuthenticatedAppShell extends StatefulWidget {
  const AuthenticatedAppShell({super.key});

  @override
  State<AuthenticatedAppShell> createState() =>
      _AuthenticatedAppShellState();
}

class _AuthenticatedAppShellState extends State<AuthenticatedAppShell> {
  int _selectedIndex = 0;

  static const _destinations = <Widget>[
    HomeScreen(),
    CommunityScreen(),
    ProfileViewScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _destinations),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              key: Key('nav-trips'),
              icon: Icon(Icons.luggage_outlined),
              selectedIcon: Icon(Icons.luggage),
              label: 'Trips',
            ),
            NavigationDestination(
              key: Key('nav-community'),
              icon: Icon(Icons.public_outlined),
              selectedIcon: Icon(Icons.public),
              label: 'Community',
            ),
            NavigationDestination(
              key: Key('nav-profile'),
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Route authenticated users through the shell**

In `lib/features/auth/auth_gate.dart`, import the shell and change only the authenticated branch:

```dart
case AuthStatus.authenticated:
  return const AuthenticatedAppShell();
```

Do not change guest, onboarding, deactivated, suspended, or admin routing.

- [ ] **Step 5: Theme the root navigation**

In `AppTheme._build`, add a `NavigationBarThemeData` that uses `surface` as the background, a transparent elevation/tint, a primary-colored selected indicator, and themed selected/unselected label styles. Do not hard-code separate Light/Dark values inside the component theme.

- [ ] **Step 6: Run focused navigation and auth tests**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\authenticated_app_shell_test.dart test\auth_gate_test.dart test\admin_account_screen_test.dart
```

Expected: all tests pass; authenticated users see the shell and non-user auth states are unchanged.

- [ ] **Step 7: Commit the shell**

```powershell
git add -- lib/features/navigation/authenticated_app_shell.dart lib/features/auth/auth_gate.dart lib/theme/app_theme.dart test/authenticated_app_shell_test.dart
git commit -m "feat(ui): add authenticated app navigation"
```

### Task 2: Navigation regression gate

**Files:**
- Modify only if verification reveals a shell defect: files from Task 1
- Test: existing Home, Community, Profile, auth, and responsive suites

**Interfaces:**
- Consumes: `AuthenticatedAppShell` from Task 1.
- Produces: a stable root shell ready for Trips Home visual redesign.

- [ ] **Step 1: Format and analyze**

Run:

```powershell
D:\Download\flutter-sdk\bin\dart.bat format lib\features\navigation\authenticated_app_shell.dart lib\features\auth\auth_gate.dart lib\theme\app_theme.dart test\authenticated_app_shell_test.dart
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat analyze --no-pub
```

Expected: `No issues found!`.

- [ ] **Step 2: Run affected suites**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test test\authenticated_app_shell_test.dart test\auth_gate_test.dart test\widget_test.dart test\community_screen_test.dart test\profile_controller_test.dart test\responsive_layout_test.dart
```

If `test/community_screen_test.dart` is not present, use the existing `test/public_trip_search_test.dart` and `test/public_trip_view_screen_test.dart` instead. Expected: zero failures.

- [ ] **Step 3: Confirm protected local files**

Run:

```powershell
git status --short
Get-FileHash -Algorithm SHA256 -LiteralPath 'web/index.html'
```

Expected: `web/index.html` remains unstaged with SHA-256 `DA5E56E066F95C40328B72A2B286E8BBBF630BA6B0BA92097645231AF0814BD2`.
