import '../models/profile.dart';

/// Maps between the [Profile] model (camelCase) and the `profiles` table
/// (snake_case) — mirrors `trip_supabase_mapper.dart`.
Profile profileFromSupabaseRow(Map<String, dynamic> row) {
  return Profile(
    userID: row['user_id'] as String,
    email: row['email'] as String,
    displayName: row['display_name'] as String,
    avatarUrl: row['avatar_url'] as String?,
    role: UserRole.values.firstWhere(
      (r) => r.name == row['role'],
      orElse: () => UserRole.user,
    ),
    status: AccountStatus.values.firstWhere(
      (s) => s.name == row['status'],
      orElse: () => AccountStatus.active,
    ),
    deactivatedAt: row['deactivated_at'] == null
        ? null
        : DateTime.parse(row['deactivated_at'] as String),
    lastLoginAt: row['last_login_at'] == null
        ? null
        : DateTime.parse(row['last_login_at'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    dateOfBirth: row['date_of_birth'] == null
        ? null
        : DateTime.parse(row['date_of_birth'] as String),
    country: row['country'] as String?,
    travelInterests:
        (row['travel_interests'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const [],
    // Defaults true (not the column's own `false` default) so a row fetched before
    // this migration ran — or a hand-written test fixture missing the key —
    // reads as "already onboarded" rather than bouncing an existing user
    // into onboarding. The real default-false behaviour for genuinely new
    // signups comes from the column default on INSERT, not from this read
    // path.
    profileCompleted: row['profile_completed'] as bool? ?? true,
  );
}

/// Full row for insert (used by `createProfileIfMissing`'s defensive
/// fallback — the `handle_new_user` trigger is the primary mechanism).
Map<String, dynamic> profileToSupabaseRow(Profile profile) {
  return {
    'user_id': profile.userID,
    'email': profile.email,
    'display_name': profile.displayName,
    'avatar_url': profile.avatarUrl,
    'role': profile.role.name,
    'status': profile.status.name,
    'deactivated_at': profile.deactivatedAt?.toIso8601String(),
    'last_login_at': profile.lastLoginAt?.toIso8601String(),
    'created_at': profile.createdAt.toIso8601String(),
    'updated_at': profile.updatedAt.toIso8601String(),
    'date_of_birth': _formatDateOnly(profile.dateOfBirth),
    'country': profile.country,
    'travel_interests': profile.travelInterests,
    'profile_completed': profile.profileCompleted,
  };
}

/// Editable fields only — never lifecycle fields (`user_id`, `created_at`,
/// `updated_at` are server-managed).
Map<String, dynamic> profileEditableFieldsToSupabaseRow(Profile profile) {
  return {
    'email': profile.email,
    'display_name': profile.displayName,
    'avatar_url': profile.avatarUrl,
    'role': profile.role.name,
    'status': profile.status.name,
    'deactivated_at': profile.deactivatedAt?.toIso8601String(),
    'last_login_at': profile.lastLoginAt?.toIso8601String(),
    'date_of_birth': _formatDateOnly(profile.dateOfBirth),
    'country': profile.country,
    'travel_interests': profile.travelInterests,
    'profile_completed': profile.profileCompleted,
  };
}

String? _formatDateOnly(DateTime? date) {
  if (date == null) return null;
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}