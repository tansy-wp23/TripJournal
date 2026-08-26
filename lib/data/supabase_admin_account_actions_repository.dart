import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_account_actions_repository.dart';

/// Real [AdminAccountActionsRepository] (Phase 7 of
/// ADMIN_MODULE_IMPLEMENTATION_PLAN.md). Both methods call the privileged
/// `admin-suspend-user` / `admin-reactivate-user` Edge Functions rather
/// than writing to `profiles` directly — a direct client write can't call
/// `auth.admin.signOut()` (Architecture Decision 4), and there is
/// deliberately no admin UPDATE policy on `profiles` for the same reason
/// (see `202608190001_admin_rbac_and_audit_logs.sql`).
class SupabaseAdminAccountActionsRepository
    implements AdminAccountActionsRepository {
  SupabaseAdminAccountActionsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> suspendUser({
    // Accepted to satisfy the interface (matches
    // MockAdminAccountActionsRepository's shape and what
    // AdminUserDetailScreen already passes in), but not sent to the
    // server — the Edge Function derives the acting admin's identity from
    // the caller's own JWT, which is more trustworthy than a
    // client-supplied id.
    required String adminUserId,
    required String targetUserId,
    String? reason,
  }) async {
    try {
      await _client.functions.invoke(
        'admin-suspend-user',
        body: {
          'targetUserId': targetUserId,
          'reason': ?reason,
        },
      );
    } on FunctionException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> reactivateUser({
    required String adminUserId,
    required String targetUserId,
  }) async {
    try {
      await _client.functions.invoke(
        'admin-reactivate-user',
        body: {'targetUserId': targetUserId},
      );
    } on FunctionException catch (e) {
      throw _mapError(e);
    }
  }

  /// Surfaces the Edge Function's `{"error": "<reason>"}` body as the
  /// exception message where possible, rather than an opaque
  /// [FunctionException], mirroring
  /// `SupabaseAccountLifecycleRepository._mapConfirmError`.
  Object _mapError(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return StateError(details['error'] as String);
    }
    return e;
  }
}
