import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/screens/admin_login_screen.dart';
import 'package:tripjournal/features/auth/screens/login_screen.dart';

void main() {
  // `tester.pump(duration)` doesn't advance real wall-clock time, so tests
  // simulating an elapsed gap fake `loginScreenDebugClock` instead of
  // actually sleeping. Reset after every test so it never leaks between
  // them (default tests below rely on the real clock, which always
  // produces small real gaps well within the 3s window).
  tearDown(() => loginScreenDebugClock = DateTime.now);

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
