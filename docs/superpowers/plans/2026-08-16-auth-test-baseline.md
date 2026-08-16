# Authentication Test Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore a deterministic, fully green Flutter test baseline before any Map & Location production code is added.

**Architecture:** Keep authentication behavior unchanged and isolate each widget test with an owned mock repository/controller lifecycle. Replace unbounded animation settling in static authentication screens with bounded pumps, then fix only reproducible controller/UI races demonstrated by focused tests.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, Riverpod 3.3.2, `flutter_test`.

## Global Constraints

- Work only in `D:\Download\TripJournal\.worktrees\map-location-integration` on branch `map-location-integration`.
- Keep `PUB_CACHE` at `D:\FlutterCache\pub-cache`; do not create SDK or cache directories on C:.
- Preserve intended Google sign-in, deactivation, reactivation and suspension behavior.
- Do not weaken assertions, skip tests or increase arbitrary timeouts to hide a race.
- Run the four affected test files separately because Flutter 3.44.8 currently crashes while compiling several native-asset test targets in one invocation on this machine.

---

### Task 1: Deterministic authentication test harness

**Files:**
- Create: `test/support/auth_test_harness.dart`
- Modify: `lib/data/mock_auth_repository.dart`
- Modify: `test/code_entry_screen_test.dart`
- Modify: `test/login_screen_admin_entry_test.dart`
- Modify: `test/responsive_layout_test.dart`
- Modify: `test/suspended_screen_test.dart`
- Test: the four test files above

**Interfaces:**
- Produces: `AuthTestHarness`, with `Widget wrap(Widget home)`, `Future<void> signIn()`, and `Future<void> dispose()`.
- Produces: `MockAuthRepository.dispose()` to close its broadcast stream after the owning test ends.

- [ ] **Step 1: Add a focused failing lifecycle test**

Add to `test/auth_controller_test.dart`:

```dart
test('disposed mock auth repository closes without late auth events', () async {
  final auth = MockAuthRepository();
  final events = <AppSession>[];
  final subscription = auth.authStateChanges().listen(events.add);

  await auth.signOut();
  await auth.dispose();
  await subscription.asFuture<void>();

  expect(events, [const AppSession.signedOut()]);
});
```

- [ ] **Step 2: Verify the lifecycle test fails for the missing API**

Run:

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
D:\Download\flutter-sdk\bin\flutter.bat test --no-pub test/auth_controller_test.dart
```

Expected: compilation fails because `MockAuthRepository.dispose` does not exist.

- [ ] **Step 3: Implement owned test resources**

Add to `MockAuthRepository`:

```dart
Future<void> dispose() async {
  await _controller.close();
}
```

Create `test/support/auth_test_harness.dart` with an object that constructs one `MockAuthRepository`, `MockProfileRepository`, `MockVerificationCodeRepository`, `MockAccountLifecycleRepository`, and `AuthController`. Its `wrap` method overrides `authControllerProvider`; its `dispose` method calls `controller.dispose()` and then `authRepository.dispose()`.

```dart
final class AuthTestHarness {
  AuthTestHarness({MockProfileState profileState = MockProfileState.active})
      : authRepository = MockAuthRepository(),
        profileRepository = MockProfileRepository(state: profileState),
        verificationRepository = MockVerificationCodeRepository() {
    lifecycleRepository = MockAccountLifecycleRepository(
      profileRepository: profileRepository,
      verificationCodeRepository: verificationRepository,
    );
    controller = AuthController(
      authRepository,
      profileRepository,
      lifecycleRepository,
    );
  }

  final MockAuthRepository authRepository;
  final MockProfileRepository profileRepository;
  final MockVerificationCodeRepository verificationRepository;
  late final MockAccountLifecycleRepository lifecycleRepository;
  late final AuthController controller;

  Widget wrap(Widget home) => ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(home: home),
      );

  Future<void> signIn() => controller.signInWithGoogle();

  Future<void> dispose() async {
    controller.dispose();
    await authRepository.dispose();
  }
}
```

- [ ] **Step 4: Migrate the four failing files to one harness per test**

In each `setUp`, create `harness`; in each `tearDown`, await `harness.dispose()`. Replace separately constructed repositories/controllers with harness fields. In responsive tests, create the harness inside the test and register `addTearDown(harness.dispose)` so each size sweep owns exactly one live controller.

- [ ] **Step 5: Run the affected files individually**

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
$flutter='D:\Download\flutter-sdk\bin\flutter.bat'
& $flutter test --no-pub test/code_entry_screen_test.dart
& $flutter test --no-pub test/login_screen_admin_entry_test.dart
& $flutter test --no-pub test/responsive_layout_test.dart
& $flutter test --no-pub test/suspended_screen_test.dart
```

Expected: no leaked provider/controller state; any remaining failure is confined to a named interaction rather than suite order.

- [ ] **Step 6: Commit the test isolation change**

```powershell
git add lib/data/mock_auth_repository.dart test/support/auth_test_harness.dart test/code_entry_screen_test.dart test/login_screen_admin_entry_test.dart test/responsive_layout_test.dart test/suspended_screen_test.dart test/auth_controller_test.dart
git commit -m "test: isolate authentication widget state"
```

### Task 2: Remove authentication state races demonstrated by the focused tests

**Files:**
- Modify: `lib/features/auth/controller/auth_controller.dart`
- Modify: `lib/features/auth/screens/code_entry_screen.dart`
- Modify: `lib/features/auth/screens/suspended_screen.dart`
- Test: `test/auth_controller_test.dart`
- Test: `test/code_entry_screen_test.dart`
- Test: `test/suspended_screen_test.dart`

**Interfaces:**
- Produces: serialized `AuthController.signOut()` that cannot remain in `AuthStatus.loading`.
- Consumes: `AuthTestHarness` from Task 1.

- [ ] **Step 1: Add race regression tests**

Add controller tests asserting that sign-out during or immediately after an auth-stream event ends at `signedOut`, and add widget tests that await the button callback with bounded pumps:

```dart
await tester.tap(find.byKey(const Key('suspended-sign-out')));
await tester.pump();
await tester.pump(const Duration(milliseconds: 50));
expect(harness.controller.status, AuthStatus.signedOut);
```

For deactivation Back, push `CodeEntryScreen` above a sentinel route and assert the sentinel remains while the controller status is unchanged.

- [ ] **Step 2: Run the new tests and record the actual state sequence**

Run `test/auth_controller_test.dart`, `test/code_entry_screen_test.dart`, and `test/suspended_screen_test.dart` separately. Expected before the fix: the regression test exposes either a late loading state or a route assertion that reads a disposed element.

- [ ] **Step 3: Make sign-out an explicit state transition**

Update `AuthController.signOut` so state cleanup happens in `finally` and loading is always cleared:

```dart
Future<void> signOut() async {
  _loading = true;
  _error = null;
  notifyListeners();
  try {
    await _authRepository.signOut();
  } finally {
    _session = null;
    _profile = null;
    _loading = false;
    notifyListeners();
  }
}
```

Keep `_onAuthStateChanged` idempotent: a signed-out event clears session/profile but must not set `_loading` or re-enter `signOut`.

- [ ] **Step 4: Await sign-out actions from the UI**

Change the suspended button callback to an async callback that awaits `signOut`. Keep reactivation Cancel awaiting the same call. Deactivation Back remains a plain navigator pop and does not mutate auth.

- [ ] **Step 5: Verify controller and widget behavior**

Run the three focused files. Expected: all pass and no test reads a widget after it has been popped.

- [ ] **Step 6: Commit the race fix**

```powershell
git add lib/features/auth/controller/auth_controller.dart lib/features/auth/screens/code_entry_screen.dart lib/features/auth/screens/suspended_screen.dart test/auth_controller_test.dart test/code_entry_screen_test.dart test/suspended_screen_test.dart
git commit -m "fix: stabilize authentication state transitions"
```

### Task 3: Bounded login and responsive verification

**Files:**
- Modify: `test/login_screen_admin_entry_test.dart`
- Modify: `test/responsive_layout_test.dart`
- Test: both files

**Interfaces:**
- Produces: `pumpAuthFrame(WidgetTester)` test helper that performs two bounded pumps rather than waiting on unrelated image/animation frames.

- [ ] **Step 1: Add a bounded pump helper**

```dart
Future<void> pumpAuthFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
```

Use it after rendering the static Login screen and after each hidden-logo tap. Continue using `pumpAndSettle` only after Navigator pushes `AdminLoginScreen`.

- [ ] **Step 2: Verify hidden admin entry and all responsive sizes**

Run both files separately. Expected: triple tap opens Admin Login, two taps and expired windows do not, and all six viewport sizes plus 1.3x text render without overflow.

- [ ] **Step 3: Run the complete baseline**

```powershell
$env:PUB_CACHE='D:\FlutterCache\pub-cache'
$flutter='D:\Download\flutter-sdk\bin\flutter.bat'
& $flutter analyze --no-pub
Get-ChildItem test -Filter '*_test.dart' | ForEach-Object { & $flutter test --no-pub $_.FullName; if ($LASTEXITCODE -ne 0) { throw "Test failed: $($_.Name)" } }
```

Expected: analyze reports zero issues and every test file passes. Record the Flutter tool crash separately if it occurs before test compilation; do not count it as an application assertion result.

- [ ] **Step 4: Commit the baseline verification change**

```powershell
git add test/login_screen_admin_entry_test.dart test/responsive_layout_test.dart
git commit -m "test: bound authentication widget pumps"
```
