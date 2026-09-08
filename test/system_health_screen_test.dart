import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/screens/system_health_screen.dart';

void main() {
  // `dotenv` is a process-wide singleton, so every test resets it in
  // tearDown rather than relying on test order.
  tearDown(dotenv.clean);

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SystemHealthScreen()));
    await tester.pumpAndSettle();
  }

  group('SystemHealthScreen', () {
    testWidgets('shows Gemini as "Not configured", with no Test Connection '
        'button, on the mock backend — there is no key on the client to check '
        'any more, so this tracks the backend mode instead', (tester) async {
      await pumpScreen(tester);

      expect(
        find.byKey(const Key('admin-system-health-gemini')),
        findsOneWidget,
      );
      expect(find.text('Not configured'), findsOneWidget);
      expect(
        find.byKey(const Key('admin-system-health-gemini-test')),
        findsNothing,
      );
    });

    testWidgets('shows Gemini as "Configured" with a Test Connection button on '
        'a real backend', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SystemHealthScreen(geminiConfiguredOverride: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Configured'), findsOneWidget);
      expect(find.text('Not configured'), findsNothing);
      expect(
        find.byKey(const Key('admin-system-health-gemini-test')),
        findsOneWidget,
      );
      expect(find.text('Test Connection'), findsOneWidget);
    });

    testWidgets('Test Connection asks the proxy and reports a working key', (
      tester,
    ) async {
      var seenAction = '';
      await tester.pumpWidget(
        MaterialApp(
          home: SystemHealthScreen(
            geminiConfiguredOverride: true,
            geminiInvoker: (action, _) async {
              seenAction = action;
              return {'ok': true, 'configured': true};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-system-health-gemini-test')));
      await tester.pumpAndSettle();

      // Never generateContent: a health check must not spend generation quota.
      expect(seenAction, 'health');
      expect(find.text('Reachable'), findsOneWidget);
    });

    testWidgets('Test Connection reports a key the server could not use', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SystemHealthScreen(
            geminiConfiguredOverride: true,
            geminiInvoker: (_, _) async => {'ok': false, 'configured': true},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-system-health-gemini-test')));
      await tester.pumpAndSettle();

      expect(find.text('Unreachable'), findsWidgets);
    });

    testWidgets('checks Supabase connectivity automatically on open, and '
        'honestly reports it unreachable in a test environment (no real '
        'Supabase.initialize() ever runs under flutter_test)', (tester) async {
      await pumpScreen(tester);

      expect(
        find.byKey(const Key('admin-system-health-supabase')),
        findsOneWidget,
      );
      expect(find.text('Unreachable'), findsOneWidget);
      // Never claims something unchecked/unreachable is "Connected".
      expect(find.text('Connected'), findsNothing);
    });

    testWidgets('the Supabase re-check button re-runs the check without '
        'throwing', (tester) async {
      // Doesn't assert the transient "Checking…" frame: with no real
      // Supabase instance to reach, the check fails near-instantly (no
      // real network delay to pump through) — same timing class as the AI
      // retry tests, so this checks the durable outcome instead.
      await pumpScreen(tester);

      expect(find.text('Re-check'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('admin-system-health-supabase-retry')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unreachable'), findsOneWidget);
    });

    testWidgets('only two indicators are shown — Database Connectivity and '
        'Backend API were consolidated into one Supabase Connectivity check '
        '(Phase 21, see the screen\'s own doc comment)', (tester) async {
      await pumpScreen(tester);

      expect(
        find.byKey(const Key('admin-system-health-gemini')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('admin-system-health-supabase')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('admin-system-health-database')),
        findsNothing,
      );
      expect(find.byKey(const Key('admin-system-health-api')), findsNothing);
    });
  });
}
