import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/validation/profile_validation.dart';

void main() {
  group('validateProfileDisplayName', () {
    test('returns null for a valid display name', () {
      expect(validateProfileDisplayName('Sang You'), isNull);
      expect(validateProfileDisplayName('  Sang You  '), isNull);
    });

    test('returns error for empty display name', () {
      expect(validateProfileDisplayName(''), isNotNull);
      expect(validateProfileDisplayName('   '), isNotNull);
      expect(validateProfileDisplayName(null), isNotNull);
    });

    test('returns error for display name over max length', () {
      final long = 'A' * (kProfileDisplayNameMaxLength + 1);
      expect(validateProfileDisplayName(long), isNotNull);
    });

    test('accepts display name at exactly max length', () {
      final exact = 'A' * kProfileDisplayNameMaxLength;
      expect(validateProfileDisplayName(exact), isNull);
    });
  });

  group('validateDateOfBirth', () {
    test('null is always valid — date of birth is optional', () {
      expect(validateDateOfBirth(null), isNull);
    });

    test('accepts a plausible past date', () {
      expect(validateDateOfBirth(DateTime(2000, 5, 7)), isNull);
    });

    test('rejects a future date', () {
      final future = DateTime.now().add(const Duration(days: 1));
      expect(validateDateOfBirth(future), isNotNull);
    });

    test('rejects a date before 1900', () {
      expect(validateDateOfBirth(DateTime(1899, 12, 31)), isNotNull);
    });

    test('accepts today', () {
      expect(validateDateOfBirth(DateTime.now()), isNull);
    });
  });

  group('kTravelInterestOptions', () {
    test('is non-empty and has no duplicates', () {
      expect(kTravelInterestOptions, isNotEmpty);
      expect(kTravelInterestOptions.toSet().length, kTravelInterestOptions.length);
    });
  });
}