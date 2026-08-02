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
  final UserRole role;
  final AccountStatus status;
  final DateTime? deactivatedAt;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.userID,
    required this.email,
    required this.displayName,
    this.role = UserRole.user,
    this.status = AccountStatus.active,
    this.deactivatedAt,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == AccountStatus.active;
  bool get isDeactivated => status == AccountStatus.deactivated;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userID: json['userID'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userID': userID,
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'status': status.name,
      'deactivatedAt': deactivatedAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Profile copyWith({
    String? userID,
    String? email,
    String? displayName,
    UserRole? role,
    AccountStatus? status,
    DateTime? deactivatedAt,
    bool clearDeactivatedAt = false,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      userID: userID ?? this.userID,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      status: status ?? this.status,
      deactivatedAt:
          clearDeactivatedAt ? null : (deactivatedAt ?? this.deactivatedAt),
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Provisional role vocabulary. The Admin module owns the final role
/// definitions; this is a placeholder so the Profile entity compiles.
enum UserRole { user, admin }

/// Whether the account is currently usable.
enum AccountStatus { active, deactivated }