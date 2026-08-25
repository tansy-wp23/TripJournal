import '../models/verification_code.dart';
import 'verification_code_repository.dart';

/// In-memory fake of [VerificationCodeRepository] so UI work in Phases 2–5
/// never blocks on a backend.
///
/// Generates a fixed code (`"123456"` in mock mode, printed to console),
/// tracks `attempt_count`, enforces expiry via a short configurable timer.
class MockVerificationCodeRepository implements VerificationCodeRepository {
  /// The fixed code used in mock mode.
  static const String mockCode = '123456';

  /// How long a sent code stays valid before it expires.
  final Duration codeLifetime;

  /// Max attempts before the code is locked out.
  final int maxAttempts;

  /// The user id the code is sent to (for traceability in logs).
  final String mockUserId;

  /// The email the code is "sent" to (for traceability in logs).
  final String mockEmail;

  /// The currently active (unused, unexpired) code, if any.
  VerificationCode? _activeCode;

  /// Whether the current code has been locked out by too many attempts.
  bool _lockedOut = false;

  /// Monotonic counter so two codes sent in the same millisecond still get
  /// distinct IDs.
  int _codeCounter = 0;

  MockVerificationCodeRepository({
    this.codeLifetime = const Duration(minutes: 5),
    this.maxAttempts = 5,
    this.mockUserId = 'user-001',
    this.mockEmail = 'sangyou@example.com',
  });

  /// The currently active code, exposed for tests to inspect state.
  VerificationCode? get activeCode => _activeCode;

  @override
  Future<void> sendCode(VerificationPurpose purpose) async {
    final now = DateTime.now();
    _codeCounter++;
    // Resend reuses sendCode — calling it again invalidates the prior code
    // (a fresh one with a new codeID replaces it), which is the same
    // behavior the real verification-send function has server-side.
    _activeCode = VerificationCode(
      codeID: 'code-${now.millisecondsSinceEpoch}-$_codeCounter',
      codeHash: mockCode, // mock: store plaintext for simplicity; real impl hashes
      purpose: purpose,
      attemptCount: 0,
      createdAt: now,
      expiresAt: now.add(codeLifetime),
      userID: mockUserId,
    );
    _lockedOut = false;
    // ignore: avoid_print
    print('[MockVerificationCodeRepository] Code for $purpose sent to '
        '$mockEmail: $mockCode');
  }

  @override
  Future<CodeValidationResult> validateCode({
    required String code,
    required VerificationPurpose purpose,
  }) async {
    final active = _activeCode;
    if (active == null) {
      return CodeValidationResult.invalid;
    }
    if (active.purpose != purpose) {
      return CodeValidationResult.invalid;
    }
    if (active.isExpired) {
      return CodeValidationResult.expired;
    }
    if (_lockedOut) {
      return CodeValidationResult.invalid;
    }
    if (code != mockCode) {
      _activeCode = active.copyWith(attemptCount: active.attemptCount + 1);
      if (_activeCode!.attemptCount >= maxAttempts) {
        _lockedOut = true;
      }
      return CodeValidationResult.invalid;
    }
    // Valid: mark used.
    _activeCode = active.copyWith(usedAt: DateTime.now());
    return CodeValidationResult.valid;
  }
}
