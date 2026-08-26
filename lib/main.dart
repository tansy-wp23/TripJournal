import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_reporting.dart';
import 'features/auth/auth_gate.dart';
import 'features/settings/settings_providers.dart';
import 'models/system_error_log.dart';

Future<void> main() async {
  // Everything — including `ensureInitialized()` — runs inside the same
  // `runZonedGuarded` zone as `runApp()`. Splitting these across two zones
  // (bindings set up in the root zone, `runApp()` called inside a child
  // zone created later) trips Flutter's "Zone mismatch" assertion and
  // leaves zone-scoped async state (e.g. what a request made during the
  // widget tree's build resolves against) inconsistent between the two
  // zones — which surfaced as Supabase auth calls firing against a client
  // that looked initialized but hadn't fully propagated. Flutter's own
  // guidance is to keep binding init and `runApp()` in one zone.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Admin module Sprint 3, Phase 17 (Architecture Decision 9): every
      // unhandled error, framework-level or uncaught-async, is recorded to
      // the admin module's system error log — see `error_reporting.dart`.
      // This is a cross-module touch (core app entry point, not
      // `lib/features/admin/`), flagged in `docs/admin/PROGRESS.md`.
      //
      // `FlutterError.onError` catches errors raised during the framework's
      // own build/layout/paint work (e.g. a widget throwing mid-build) —
      // these are usually recoverable enough that the app keeps running, so
      // they're recorded as `ErrorSeverity.error` rather than `fatal`.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        reportSystemError(
          details.exception,
          details.stack,
          severity: ErrorSeverity.error,
        );
      };

      await dotenv.load(fileName: '.env');
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
      );

      runApp(const ProviderScope(child: TripJournalApp()));
    },
    // Catches everything else — uncaught errors in async code outside the
    // widget tree's build/layout/paint path, which would otherwise crash
    // the isolate entirely. Recorded as `fatal` since, unlike a framework
    // rendering error, nothing here already caught it or kept the app in a
    // known state.
    (error, stack) => reportSystemError(error, stack),
  );
}

final supabase = Supabase.instance.client;

class TripJournalApp extends ConsumerWidget {
  const TripJournalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsControllerProvider).preferences.themeMode;
    return MaterialApp(
      title: 'TripJournal',
      themeMode: themeMode,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const AuthGate(),
    );
  }
}
