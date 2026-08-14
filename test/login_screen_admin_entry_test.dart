import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/screens/admin_login_screen.dart';
import 'package:tripjournal/features/auth/screens/login_screen.dart';
import 'package:tripjournal/widgets/app_logo.dart';

void main() {
  // `tester.pump(duration)` doesn't advance real wall-clock time, so tests
  // simulating an elapsed gap fake `loginScreenDebugClock` instead of
  // actually sleeping. Reset after every test so it never leaks between
  // them (default tests below rely on the real clock, which always
  // produces small real gaps well within the 3s window).
  tearDown(() => loginScreenDebugClock = DateTime.now);

  testWidgets('the sign-in screen shows the app artwork, not a placeholder icon',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pumpAndSettle();

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
  });

  group('LoginScreen hidden admin entry', () {
    testWidgets('no visible "Admin Portal" text is shown to travelers',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
      await tester.pumpAndSettle();

      expect(find.text('Admin Portal'), findsNothing);
    });

    testWidgets('tapping the logo 3 times within the window opens AdminGate',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
      await tester.pumpAndSettle();

      final logo = find.byKey(const Key('login-logo-tap-target'));
      await tester.tap(logo);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(logo);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(logo);
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
    });

    testWidgets('2 taps does not open the admin portal', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
      await tester.pumpAndSettle();

      final logo = find.byKey(const Key('login-logo-tap-target'));
      await tester.tap(logo);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(logo);
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsNothing);
    });

    testWidgets('taps spread outside the window do not accumulate',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
      await tester.pumpAndSettle();

      var fakeNow = DateTime(2026, 1, 1);
      loginScreenDebugClock = () => fakeNow;

      final logo = find.byKey(const Key('login-logo-tap-target'));
      await tester.tap(logo); // tap 1 at fakeNow
      fakeNow = fakeNow.add(const Duration(seconds: 4)); // exceeds the 3s window
      await tester.tap(logo); // window resets; this becomes tap 1 again
      fakeNow = fakeNow.add(const Duration(milliseconds: 100));
      await tester.tap(logo); // tap 2 within the (reset) window
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsNothing);
    });
  });
}
