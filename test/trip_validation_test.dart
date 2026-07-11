import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/validation/trip_validation.dart';

void main() {
  group('validateTripTitle', () {
    test('empty title is rejected', () {
      expect(validateTripTitle(''), 'Please enter a trip title.');
      expect(validateTripTitle(null), 'Please enter a trip title.');
      expect(validateTripTitle('   '), 'Please enter a trip title.');
    });

    test('a 100-char title is accepted (the boundary is inclusive)', () {
      final title = 'a' * 100;
      expect(validateTripTitle(title), isNull);
    });

    test('a 101-char title is rejected', () {
      final title = 'a' * 101;
      expect(validateTripTitle(title), 'Trip title must be 100 characters or fewer.');
    });

    test('a normal title is accepted', () {
      expect(validateTripTitle('Kyoto Trip'), isNull);
    });
  });

  group('validateTripDateRange', () {
    test('end before start is rejected', () {
      final error = validateTripDateRange(DateTime(2026, 4, 10), DateTime(2026, 4, 9));
      expect(error, 'End date must be on or after the start date.');
    });

    test('end equal to start is accepted (single-day trip)', () {
      expect(validateTripDateRange(DateTime(2026, 4, 10), DateTime(2026, 4, 10)), isNull);
    });

    test('end after start is accepted', () {
      expect(validateTripDateRange(DateTime(2026, 4, 10), DateTime(2026, 4, 15)), isNull);
    });
  });
}
