/// Which set of data sources the whole app runs against.
///
/// This is deliberately **one** decision for the entire app rather than a
/// per-locator choice. Before this existed, `repository_locator.dart` and
/// `trip_repository_locator.dart` each picked their own implementation, which
/// made a half-migrated state representable: real journal rows written against
/// a mock trip id, or a real trip owned by [kMockUserId] that `auth.uid()` can
/// never match. Those states fail *silently* — the writes are accepted locally
/// and simply never come back — so the only safe design is one that cannot
/// express them.
///
/// Read it through [backendMode]; nothing else in the app should call
/// `String.fromEnvironment` for this.
enum BackendMode {
  /// In-memory fakes with seeded data. Survives no restart, needs no network,
  /// and works without a signed-in user. The default, and what `flutter test`
  /// always runs on.
  mock,

  /// The real Supabase tables and buckets, scoped by `auth.uid()`. Requires a
  /// signed-in user: every RLS policy in `supabase/migrations/` gates on it, so
  /// an unauthenticated session reads back empty rather than erroring.
  supabase,
}

/// The compile-time value of `--dart-define=BACKEND_MODE=...`.
///
/// Compile-time rather than a `.env` entry on purpose. `.env` is read by
/// `dotenv.load()` inside `main()`, which is *later* than the first locator
/// access in some widget trees — a runtime source would make the mode depend on
/// startup ordering. A `String.fromEnvironment` constant is fixed when the app
/// is built, so every read in the process agrees.
const String _rawBackendMode = String.fromEnvironment(
  'BACKEND_MODE',
  defaultValue: 'mock',
);

/// The mode this build runs in. Defaults to [BackendMode.mock] so an ordinary
/// `flutter run`, `flutter test`, or a teammate's checkout keeps working with
/// no extra flags and no Supabase session.
final BackendMode backendMode = parseBackendMode(_rawBackendMode);

/// Exposed for tests — production code reads [backendMode].
///
/// An empty value means "nobody passed the flag" and yields the default. A
/// *non-empty* value that isn't recognised throws instead of quietly falling
/// back to mock: `BACKEND_MODE=supabse` silently serving in-memory data is the
/// exact failure this switch was added to prevent, and because the value is a
/// compile-time constant a typo is a build mistake, not user input, so failing
/// loudly costs a rebuild rather than a corrupted database.
BackendMode parseBackendMode(String raw) {
  final normalized = raw.trim().toLowerCase();
  return switch (normalized) {
    '' || 'mock' => BackendMode.mock,
    'supabase' => BackendMode.supabase,
    _ => throw ArgumentError.value(
      raw,
      'BACKEND_MODE',
      'must be "mock" or "supabase"',
    ),
  };
}
