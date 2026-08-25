
/// App-specific profile fields that Supabase Auth knows nothing about.
///
/// `userID` is a 1:1 foreign key to `auth.users.id`. The `status` field
/// (active/deactivated) is the one thing this table exists for — Supabase
/// Auth has no concept of account deactivation.
///
/// Architecture note: `LinkedProvider` and `Session` are NOT modelled here —
/// they are superseded by Supabase Auth's `auth.identities` and its own
/// session/JWT handling. See `docs/user-management/PROGRESS.md`.
class Profile {
  final String userID;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final UserRole role;
  final AccountStatus status;
  final DateTime? deactivatedAt;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dateOfBirth;
  final String? country;
  final List<String> travelInterests;

  /// Drives first-login onboarding routing — see [AuthStatus.needsOnboarding]
  /// in `auth_controller.dart`. Defaults to `true` here (not `false`) so
  /// every existing call site that builds a [Profile] without naming this
  /// field — test fixtures, `MockProfileRepository`'s active/deactivated
  /// seeds, anything constructed before this field existed — keeps behaving
  /// as "already onboarded". Only the two call sites that create a genuinely
  /// new profile (`MockProfileRepository`/`SupabaseProfileRepository`'s
  /// `createProfileIfMissing` "no profile yet" branch) pass `false`
  /// explicitly.
  final bool profileCompleted;

  const Profile({
    required this.userID,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.role = UserRole.user,
    this.status = AccountStatus.active,
    this.deactivatedAt,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
    this.dateOfBirth,
    this.country,
    this.travelInterests = const [],
    this.profileCompleted = true,
  });

  bool get isActive => status == AccountStatus.active;
  bool get isDeactivated => status == AccountStatus.deactivated;
  bool get isSuspended => status == AccountStatus.suspended;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userID: json['userID'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.user,
      ),
      status: AccountStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => AccountStatus.active,
      ),
      deactivatedAt: json['deactivatedAt'] != null
          ? DateTime.parse(json['deactivatedAt'] as String)
          : null,
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      country: json['country'] as String?,
      travelInterests:
          (json['travelInterests'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      profileCompleted: json['profileCompleted'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userID': userID,
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'role': role.name,
      'status': status.name,
      'deactivatedAt': deactivatedAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'country': country,
      'travelInterests': travelInterests,
      'profileCompleted': profileCompleted,
    };
  }

  Profile copyWith({
    String? userID,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    UserRole? role,
    AccountStatus? status,
    DateTime? deactivatedAt,
    bool clearDeactivatedAt = false,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? country,
    bool clearCountry = false,
    List<String>? travelInterests,
    bool? profileCompleted,
  }) {
    return Profile(
      userID: userID ?? this.userID,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      role: role ?? this.role,
      status: status ?? this.status,
      deactivatedAt:
          clearDeactivatedAt ? null : (deactivatedAt ?? this.deactivatedAt),
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      country: clearCountry ? null : (country ?? this.country),
      travelInterests: travelInterests ?? this.travelInterests,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }
}

/// Provisional role vocabulary. The Admin module owns the final role
/// definitions; this is a placeholder so the Profile entity compiles.
enum UserRole { user, admin }

/// Whether the account is currently usable.
///
/// `suspended` (added for the Admin module, `ADMIN_MODULE_IMPLEMENTATION_PLAN.md`
/// Open Decision #2) is deliberately distinct from `deactivated`: a
/// `deactivated` account was closed by the user themselves and can be
/// reopened through the User Management module's self-service
/// `AccountLifecycleRepository.confirmReactivation` (Google sign-in + emailed
/// code). A `suspended` account was closed by an administrator
/// (`AdminAccountActionsRepository.suspendUser`) and must **not** be
/// reopenable through that same self-service flow — only
/// `AdminAccountActionsRepository.reactivateUser` may clear it. Wiring that
/// guard into `confirmReactivation` is Phase 5 of the Admin module plan;
/// until that lands, `suspended` exists as a status value but isn't yet
/// enforced against self-service reactivation — flagged as a known gap in
/// `docs/admin/PROGRESS.md`.
enum AccountStatus { active, deactivated, suspended }