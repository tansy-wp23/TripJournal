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
}