import '../models/profile.dart';
import '../models/verification_code.dart';
import 'account_lifecycle_repository.dart';
import 'mock_profile_repository.dart';
import 'mock_verification_code_repository.dart';
import 'verification_code_repository.dart';

/// In-memory fake of [AccountLifecycleRepository] so UI work in Phases 2–5
/// never blocks on a backend.
///
/// Deactivate/reactivate state transitions happen on the mock profile,
/// calling into the mock verification repo for code validation.
class MockAccountLifecycleRepository implements AccountLifecycleRepository {
  final MockProfileRepository profileRepository;
  final MockVerificationCodeRepository verificationCodeRepository;

  MockAccountLifecycleRepository({
    required this.profileRepository,
    required this.verificationCodeRepository,
  });

  @override
  Future<void> requestDeactivation() async {
    await verificationCodeRepository.sendCode(VerificationPurpose.deactivation);
  }

  @override
  Future<void> confirmDeactivation(String code) async {
    final result = await verificationCodeRepository.validateCode(
      code: code,
      purpose: VerificationPurpose.deactivation,
    );
    if (result != CodeValidationResult.valid) {
      throw CodeValidationException(result, 'Invalid or expired code.');
    }
    final profile = await profileRepository.getProfile(
      profileRepository.mockUserId,
    );
    if (profile == null) {
      throw StateError('No profile to deactivate.');
    }
    await profileRepository.updateProfile(
      profile.copyWith(
        status: AccountStatus.deactivated,
        deactivatedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> requestReactivation() async {
    await verificationCodeRepository.sendCode(VerificationPurpose.reactivation);
  }

  @override
  Future<void> confirmReactivation(String code) async {
    final result = await verificationCodeRepository.validateCode(
      code: code,
      purpose: VerificationPurpose.reactivation,
    );
    if (result != CodeValidationResult.valid) {
      throw CodeValidationException(result, 'Invalid or expired code.');
    }
    final profile = await profileRepository.getProfile(
      profileRepository.mockUserId,
    );
    if (profile == null) {
      throw StateError('No profile to reactivate.');
    }
    // Admin Module Phase 5 guard: a suspended account can only be cleared
    // by AdminAccountActionsRepository.reactivateUser, never by this
    // self-service flow — see AccountSuspendedException's doc comment.
    if (profile.isSuspended) {
      throw const AccountSuspendedException();
    }
    await profileRepository.updateProfile(
      profile.copyWith(
        status: AccountStatus.active,
        clearDeactivatedAt: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> requestDeletion() async {
    await verificationCodeRepository.sendCode(VerificationPurpose.deletion);
  }

  @override
  Future<void> deleteAccount(String code) async {
    final result = await verificationCodeRepository.validateCode(
      code: code,
      purpose: VerificationPurpose.deletion,
    );
    if (result != CodeValidationResult.valid) {
      throw CodeValidationException(result, 'Invalid or expired code.');
    }
    // Simulate the server-side auth.users deletion. The real flow's
    // AuthController.deleteAccount calls signOut() right after this, which
    // clears the local session/profile — so there's nothing to mutate here;
    // a valid code is all the mock needs to model.
  }
}
