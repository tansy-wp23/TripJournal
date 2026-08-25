import 'package:supabase_flutter/supabase_flutter.dart';

/// PB-14's real database/API connectivity check (Phase 21,
/// `docs/admin/PROGRESS.md`) — collapses what Open Decision 7 (Phase 15)
/// separately called "database connectivity" and "API availability" into
/// one indicator, since this app has no custom backend server distinct
/// from Supabase itself (the original proposal's "Node.js / Python
/// FastAPI" line was aspirational, never built — see `CLAUDE.md`'s Tech
/// Stack table). A PostgREST query against `profiles` exercises both the
/// network path and the database in the same round trip, so a second,
/// separately-labeled "Backend API" indicator would just be re-testing the
/// same thing under a different name.
///
/// `profiles` specifically because `profiles_select_admin`
/// (202608190001_admin_module_phase7.sql) already grants read access to
/// any `is_admin_user()` session — the only session that can ever reach
/// `SystemHealthScreen` in the first place, so this never needs its own
/// bespoke RLS policy.
///
/// Returns `true` if the query succeeds, `false` otherwise — never throws.
Future<bool> checkSupabaseConnectivity({SupabaseClient? client}) async {
  try {
    // `Supabase.instance` itself throws synchronously if
    // `Supabase.initialize()` was never called (true of every widget
    // test) — resolved inside this try block, not before it, so that
    // throw is actually caught rather than propagating out of this
    // `async` function as a rejected Future nothing here awaits-and-catches.
    final supabase = client ?? Supabase.instance.client;
    await supabase.from('profiles').select('user_id').limit(1).timeout(const Duration(seconds: 10));
    return true;
  } catch (_) {
    return false;
  }
}
