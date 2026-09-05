import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'profile_repository.dart';
import 'profile_supabase_mapper.dart';

/// Real [ProfileRepository] backed by direct RLS-protected table access to
/// the `profiles` table (Phase 7 of `USER_MANAGEMENT_IMPLEMENTATION_PLAN.md`).
///
/// Plain get/update go through RLS — no Edge Function needed for these.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile?> getProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : profileFromSupabaseRow(row);
  }

  @override
  Future<Profile> createProfileIfMissing({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    // The `handle_new_user` trigger is the primary mechanism (Phase 6);
    // this is a defensive fallback for profiles created before the trigger
    // existed or in edge cases where the trigger didn't fire.
    final existing = await getProfile(userId);
    if (existing != null) {
      // Only stamp last_login_at for an active profile. A deactivated or
      // suspended profile is routed by AuthController to the reactivation /
      // suspended screens and can never enter the app itself, and the
      // profiles UPDATE is RLS-blocked for non-active users
      // (profiles_update_own requires is_active_user()), so attempting the
      // stamp would throw a row-level-security error and turn the whole
      // sign-in into a hard failure (surfaced misleadingly as "couldn't
      // finish setting up your account"). Returning the row unchanged means
      // last_login_at just stays as it was before deactivation and gets
      // stamped again on the next active sign-in.
      if (!existing.isActive) return existing;
      return updateProfile(existing.copyWith(lastLoginAt: DateTime.now()));
    }

    final now = DateTime.now();
    final profile = Profile(
      userID: userId,
      email: email,
      displayName: displayName,
      status: AccountStatus.active,
      lastLoginAt: now,
      createdAt: now,
      updatedAt: now,
      // Genuinely new account (this is the defensive fallback path — the
      // handle_new_user trigger is primary and relies on the column's own
      // `false` default instead). Routes through onboarding once.
      profileCompleted: false,
    );

    final row = await _client
        .from('profiles')
        .insert(profileToSupabaseRow(profile))
        .select()
        .single();
    return profileFromSupabaseRow(row);
  }

  @override
  Future<Profile> updateProfile(Profile profile) async {
    final row = await _client
        .from('profiles')
        .update(profileEditableFieldsToSupabaseRow(profile))
        .eq('user_id', profile.userID)
        .select()
        .single();
    return profileFromSupabaseRow(row);
  }
}