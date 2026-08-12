import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/data/mock_verification_code_repository.dart';
import 'package:tripjournal/models/profile.dart';
import 'package:tripjournal/models/verification_code.dart';

void main() {
  late MockProfileRepository profileRepository;
  late MockVerificationCodeRepository verificationCodeRepository;
  late MockAccountLifecycleRepository lifecycleRepository;

  setUp(() {
    profileRepository = MockProfileRepository(state: MockProfileState.active);
    verificationCodeRepository = MockVerificationCodeRepository();
    lifecycleRepository = MockAccountLifecycleRepository(
      profileRepository: profileRepository,
      verificationCodeRepository: verificationCodeRepository,
    );
  });

  group('MockAccountLifecycleRepository', () {
    test('requestDeactivation sends a deactivation code', () async {
      await lifecycleRepository.requestDeactivation();

      expect(
        verificationCodeRepository.activeCode?.purpose,
        VerificationPurpose.deactivation,
      );
    });

    test('confirmDeactivation with valid code deactivates the profile',
        () async {
      await lifecycleRepository.requestDeactivation();

      await lifecycleRepository.confirmDeactivation(
        MockVerificationCodeRepository.mockCode,
      );

      final profile = await profileRepository.getProfile('user-001');
      expect(profile!.status, AccountStatus.deactivated);
      expect(profile.deactivatedAt, isNotNull);
    });

    test('confirmDeactivation with wrong code throws and keeps profile active',
        () async {
      await lifecycleRepository.requestDeactivation();

      expect(
        () => lifecycleRepository.confirmDeactivation('000000'),
        throwsA(isA<CodeValidationException>()),
      );

      final profile = await profileRepository.getProfile('user-001');
      expect(profile!.status, AccountStatus.active);
    });

    test('requestReactivation sends a reactivation code', () async {
      await lifecycleRepository.requestReactivation();

      expect(
        verificationCodeRepository.activeCode?.purpose,
        VerificationPurpose.reactivation,
      );
    });

    test('confirmReactivation with valid code reactivates the profile',
        () async {
      // Start deactivated.
      profileRepository = MockProfileRepository(
        state: MockProfileState.deactivated,
      );
      lifecycleRepository = MockAccountLifecycleRepository(
        profileRepository: profileRepository,
        verificationCodeRepository: verificationCodeRepository,
      );

      await lifecycleRepository.requestReactivation();
      await lifecycleRepository.confirmReactivation(
        MockVerificationCodeRepository.mockCode,
      );

      final profile = await profileRepository.getProfile('user-001');
      expect(profile!.status, AccountStatus.active);
      expect(profile.deactivatedAt, isNull);
    });

    test('confirmReactivation with wrong code throws and keeps profile '
        'deactivated', () async {
      profileRepository = MockProfileRepository(
        state: MockProfileState.deactivated,
      );
      lifecycleRepository = MockAccountLifecycleRepository(
        profileRepository: profileRepository,
        verificationCodeRepository: verificationCodeRepository,
      );

      await lifecycleRepository.requestReactivation();

      expect(
        () => lifecycleRepository.confirmReactivation('000000'),
        throwsA(isA<CodeValidationException>()),
      );

      final profile = await profileRepository.getProfile('user-001');
      expect(profile!.status, AccountStatus.deactivated);
    });

    // Admin Module Phase 5 (docs/admin/PROGRESS.md, Open Decision 2): a
    // suspended account must not be reactivatable through this self-service
    // flow, even with a perfectly valid code — only
    // AdminAccountActionsRepository.reactivateUser may clear a suspension.
    test('confirmReactivation with a valid code still rejects a suspended '
        'profile', () async {
      // Start active, then admin-suspend it directly on the mock (mirrors
      // what AdminAccountActionsRepository.suspendUser does to Profile.status,
      // without pulling in the whole admin mock stack for this cross-module
      // test).
      final suspended = (await profileRepository.getProfile('user-001'))!
          .copyWith(status: AccountStatus.suspended, deactivatedAt: DateTime.now());
      await profileRepository.updateProfile(suspended);

      await lifecycleRepository.requestReactivation();

      expect(
        () => lifecycleRepository.confirmReactivation(
          MockVerificationCodeRepository.mockCode,
        ),
        throwsA(isA<AccountSuspendedException>()),
      );

      final profile = await profileRepository.getProfile('user-001');
      expect(profile!.status, AccountStatus.suspended);
    });
  });
}