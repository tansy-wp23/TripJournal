import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_verification_code_repository.dart';
import 'package:tripjournal/models/verification_code.dart';
import 'package:tripjournal/data/verification_code_repository.dart';

void main() {
  group('MockVerificationCodeRepository', () {
    test('sendCode creates an active code with the fixed mock code', () async {
      final repo = MockVerificationCodeRepository();

      await repo.sendCode(VerificationPurpose.reactivation);

      final active = repo.activeCode;
      expect(active, isNotNull);
      expect(active!.codeHash, MockVerificationCodeRepository.mockCode);
      expect(active.purpose, VerificationPurpose.reactivation);
      expect(active.isUsed, isFalse);
      expect(active.isExpired, isFalse);
    });

    test('validateCode returns valid for the correct code', () async {
      final repo = MockVerificationCodeRepository();
      await repo.sendCode(VerificationPurpose.reactivation);

      final result = await repo.validateCode(
        code: MockVerificationCodeRepository.mockCode,
        purpose: VerificationPurpose.reactivation,
      );

      expect(result, CodeValidationResult.valid);
      expect(repo.activeCode!.isUsed, isTrue);
    });

    test('validateCode returns invalid for a wrong code', () async {
      final repo = MockVerificationCodeRepository();
      await repo.sendCode(VerificationPurpose.reactivation);

      final result = await repo.validateCode(
        code: '000000',
        purpose: VerificationPurpose.reactivation,
      );

      expect(result, CodeValidationResult.invalid);
      expect(repo.activeCode!.attemptCount, 1);
    });

    test('validateCode returns invalid when no code has been sent', () async {
      final repo = MockVerificationCodeRepository();

      final result = await repo.validateCode(
        code: MockVerificationCodeRepository.mockCode,
        purpose: VerificationPurpose.reactivation,
      );

      expect(result, CodeValidationResult.invalid);
    });

    test('validateCode returns invalid for a mismatched purpose', () async {
      final repo = MockVerificationCodeRepository();
      await repo.sendCode(VerificationPurpose.reactivation);

      final result = await repo.validateCode(
        code: MockVerificationCodeRepository.mockCode,
        purpose: VerificationPurpose.deactivation,
      );

      expect(result, CodeValidationResult.invalid);
    });

    test('validateCode returns expired after the code lifetime', () async {
      final repo = MockVerificationCodeRepository(
        codeLifetime: const Duration(milliseconds: 1),
      );
      await repo.sendCode(VerificationPurpose.reactivation);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final result = await repo.validateCode(
        code: MockVerificationCodeRepository.mockCode,
        purpose: VerificationPurpose.reactivation,
      );

      expect(result, CodeValidationResult.expired);
    });

    test('resendCode invalidates the previous code', () async {
      final repo = MockVerificationCodeRepository();
      await repo.sendCode(VerificationPurpose.reactivation);
      final firstCode = repo.activeCode;

      await repo.resendCode(VerificationPurpose.reactivation);

      final secondCode = repo.activeCode;
      expect(secondCode, isNotNull);
      expect(secondCode!.codeID, isNot(firstCode!.codeID));
      expect(secondCode.attemptCount, 0);
    });

    test('locks out after maxAttempts wrong attempts', () async {
      final repo = MockVerificationCodeRepository(maxAttempts: 3);
      await repo.sendCode(VerificationPurpose.reactivation);

      for (var i = 0; i < 3; i++) {
        final result = await repo.validateCode(
          code: '000000',
          purpose: VerificationPurpose.reactivation,
        );
        expect(result, CodeValidationResult.invalid);
      }

      // Even the correct code is now rejected (locked out).
      final result = await repo.validateCode(
        code: MockVerificationCodeRepository.mockCode,
        purpose: VerificationPurpose.reactivation,
      );
      expect(result, CodeValidationResult.invalid);
    });
  });
}