import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/screens/admin_login_screen.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';
import 'package:tripjournal/features/auth/screens/login_screen.dart';
import 'package:tripjournal/widgets/app_logo.dart';

import 'support/admin_test_harness.dart';
import 'support/auth_test_harness.dart';

Future<void> pumpAuthFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  // `tester.pump(duration)` doesn't advance real wall-clock time, so tests
  // simulating an elapsed gap fake `loginScreenDebugClock` instead of
  // actually sleeping. Reset after every test so it never leaks between
  // them (default tests below rely on the real clock, which always
  // produces small real gaps well within the 3s window).
  late AuthTestHarness harness;

  setUp(() async {
    harness = AuthTestHarness();
    await harness.signOut();
  });

  tearDown(() async {
    loginScreenDebugClock = DateTime.now;
    await harness.dispose();
  });

  Widget buildLoginScreen() => harness.wrap(const LoginScreen());

  testWidgets(
    'the sign-in screen shows the app artwork, not a placeholder icon',
    (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await pumpAuthFrame(tester);

      // The logo doubles as the hidden admin tap target, so it has to stay
      // *inside* that GestureDetector rather than become a sibling of it.
      expect(
        find.descendant(
          of: find.byKey(const Key('login-logo-tap-target')),
          matching: find.byType(AppLogo),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.card_travel), findsNothing);
    },
  );

  testWidgets('explains the benefits and exposes one clear sign-in action', (
    tester,
  ) async {
    await tester.pumpWidget(buildLoginScreen());
    await pumpAuthFrame(tester);

    expect(find.text('Keep every trip in one place'), findsOneWidget);
    expect(find.text('Remember places, photos and moods'), findsOneWidget);
    expect(find.text('Follow your travel wellness'), findsOneWidget);
    expect(find.bySemanticsLabel('Sign in with Google'), findsOneWidget);
  });

  group('LoginScreen hidden admin entry', () {
    testWidgets('no visible "Admin Portal" text is shown to travelers', (
      tester,
    ) async {
      await tester.pumpWidget(buildLoginScreen());
      await pumpAuthFrame(tester);

      expect(find.text('Admin Portal'), findsNothing);
    });

    testWidgets('tapping the logo 3 times within the window opens AdminGate', (
      tester,
    ) async {
      // The 3rd tap pushes AdminGate onto the same ProviderScope this
      // screen is wrapped in, and AdminGate/AdminLoginScreen immediately
      // watch adminAuthControllerProvider — so this test needs both the
      // traveler-side override (harness.wrap) and the admin one merged
      // into a single ProviderScope, unlike every other test in this file,
      // which never reaches AdminGate's own provider reads.
      final adminHarness = AdminTestHarness();
      addTearDown(adminHarness.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => harness.controller,
              disposeNotifier: false,
            ),
            ...adminHarness.overrides,
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await pumpAuthFrame(tester);

      final logo = find.byKey(const Key('login-logo-tap-target'));
      await tester.tap(logo);
      await pumpAuthFrame(tester);
      await tester.tap(logo);
      await pumpAuthFrame(tester);
      await tester.tap(logo);
      await pumpAuthFrame(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
    });

    testWidgets('2 taps does not open the admin portal', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await pumpAuthFrame(tester);

      final logo = find.byKey(const Key('login-logo-tap-target'));
      await tester.tap(logo);
      await pumpAuthFrame(tester);
      await tester.tap(logo);
      await pumpAuthFrame(tester);

      expect(find.byType(AdminLoginScreen), findsNothing);
    });

    testWidgets('taps spread outside the window do not accumulate', (
      tester,
    ) async {
      await tester.pumpWidget(buildLoginScreen());
      await pumpAuthFrame(tester);

      var fakeNow = DateTime(2026, 1, 1);
      loginScreenDebugClock = () => fakeNow;

      final logo = find.byKey(const Key('login-logo-tap-target'));
      await tester.tap(logo); // tap 1 at fakeNow
      await pumpAuthFrame(tester);
      fakeNow = fakeNow.add(
        const Duration(seconds: 4),
      ); // exceeds the 3s window
      await tester.tap(logo); // window resets; this becomes tap 1 again
      await pumpAuthFrame(tester);
      fakeNow = fakeNow.add(const Duration(milliseconds: 100));
      await tester.tap(logo); // tap 2 within the (reset) window
      await pumpAuthFrame(tester);

      expect(find.byType(AdminLoginScreen), findsNothing);
    });
  });
}
