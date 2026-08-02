/// A one-time code emailed to a user to confirm an action (deactivation or
/// reactivation). Supabase Auth has no concept of this, so it is fully
/// hand-built.
///
/// Only the hash of the code is ever stored server-side (Phase 6); the
/// plaintext code is sent to the user's email and never persisted.
class VerificationCode {
  final String codeID;
  final String codeHash;
  final VerificationPurpose purpose;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final String userID;

  const VerificationCode({
    required this.codeID,
    required this.codeHash,
    required this.purpose,
    this.attemptCount = 0,
    required this.createdAt,
    required this.expiresAt,
    this.usedAt,
    required this.userID,
  });

  bool get isUsed => usedAt != null;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory VerificationCode.fromJson(Map<String, dynamic> json) {
    return VerificationCode(
      codeID: json['codeID'] as String,
      codeHash: json['codeHash'] as String,
      purpose: VerificationPurpose.values.firstWhere(
        (p) => p.name == json['purpose'],
        orElse: () => VerificationPurpose.reactivation,
      ),
      attemptCount: json['attemptCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      usedAt: json['usedAt'] != null
          ? DateTime.parse(json['usedAt'] as String)
          : null,
      userID: json['userID'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codeID': codeID,
      'codeHash': codeHash,
      'purpose': purpose.name,
      'attemptCount': attemptCount,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'usedAt': usedAt?.toIso8601String(),
      'userID': userID,
    };
  }

  VerificationCode copyWith({
    String? codeID,
    String? codeHash,
    VerificationPurpose? purpose,
    int? attemptCount,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? usedAt,
    String? userID,
  }) {
    return VerificationCode(
      codeID: codeID ?? this.codeID,
      codeHash: codeHash ?? this.codeHash,
      purpose: purpose ?? this.purpose,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      usedAt: usedAt ?? this.usedAt,
      userID: userID ?? this.userID,
    );
  }
}

/// What a verification code is for. The shared OTP widget (Phase 4) takes a
/// [VerificationPurpose] so it can be reused for both flows.
enum VerificationPurpose { deactivation, reactivation }