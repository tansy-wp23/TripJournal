import 'account_lifecycle_repository.dart';
import 'auth_repository.dart';
import 'mock_account_lifecycle_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_profile_repository.dart';
import 'mock_verification_code_repository.dart';
import 'profile_repository.dart';
import 'verification_code_repository.dart';

/// The one place the app resolves its user-management repositories from —
/// mirrors `repository_locator.dart` / `trip_repository_locator.dart` so the
/// Phase 7 swap to Supabase is a one-line change here.
///
/// All four repositories are wired to their mock implementations for
/// Phases 1–5. Swap each `Mock*` for the real `Supabase*` in Phase 7.
final AuthRepository authRepository = MockAuthRepository();
final ProfileRepository profileRepository = MockProfileRepository();
final VerificationCodeRepository verificationCodeRepository =
    MockVerificationCodeRepository();
final AccountLifecycleRepository accountLifecycleRepository =
    MockAccountLifecycleRepository(
  profileRepository: profileRepository as MockProfileRepository,
  verificationCodeRepository:
      verificationCodeRepository as MockVerificationCodeRepository,
);