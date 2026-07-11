import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/models/trip.dart';
import 'package:tripjournal/validation/journal_entry_validation.dart';

Trip _trip({required DateTime start, required DateTime end}) {
  return Trip(
    id: 't',
    userId: 'u',
    title: 'Test Trip',
    startDate: start,
    endDate: end,
    createdAt: start,
    updatedAt: start,
  );
}

void main() {
  group('validateEntryContent', () {
    test('no title and no body is rejected', () {
      expect(
        validateEntryContent('', ''),
        'Please add a title or write something in your entry.',
      );
      expect(validateEntryContent('   ', '   '), isNotNull); // whitespace-only counts as empty
    });

    test('title only is accepted', () {
      expect(validateEntryContent('A title', ''), isNull);
    });

    test('body only is accepted', () {
      expect(validateEntryContent('', 'Some body text.'), isNull);
    });

    test('both present is accepted', () {
      expect(validateEntryContent('A title', 'Some body text.'), isNull);
    });
  });

  group('validateEntryTitleLength', () {
    test('100 chars is accepted, 101 is rejected', () {
      expect(validateEntryTitleLength('a' * 100), isNull);
      expect(validateEntryTitleLength('a' * 101), 'Title must be 100 characters or fewer.');
    });
  });

  group('validateEntryBodyLength', () {
    test('5000 chars is accepted, 5001 is rejected', () {
      expect(validateEntryBodyLength('a' * 5000), isNull);
      expect(validateEntryBodyLength('a' * 5001), 'Entry body must be 5,000 characters or fewer.');
    });
  });

  group('validateEntryTotalTextLength', () {
    test('combined title+body over 50,000 chars is rejected', () {
      final error = validateEntryTotalTextLength('a' * 100, 'b' * 49901);
      expect(error, 'This entry is too long. Please shorten it.');
    });

    test('combined title+body at or under 50,000 chars is accepted', () {
      expect(validateEntryTotalTextLength('a' * 100, 'b' * 49900), isNull);
    });
  });

  group('validateEntryDate', () {
    final now = DateTime(2026, 6, 15, 10, 30);

    test('a future day is rejected', () {
      final error = validateEntryDate(DateTime(2026, 6, 16), now: now);
      expect(error, "You can't add an entry for a future day.");
    });

    test('today and past days are accepted when there is no trip to check against', () {
      expect(validateEntryDate(DateTime(2026, 6, 15), now: now), isNull);
      expect(validateEntryDate(DateTime(2026, 6, 1), now: now), isNull);
    });

    test('a past day outside the given trip range is rejected', () {
      final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 15));
      final error = validateEntryDate(DateTime(2026, 6, 1), now: now, trip: trip);
      expect(error, 'This date is outside your trip dates.');
    });

    test('a day within the given trip range is accepted', () {
      final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 15));
      expect(validateEntryDate(DateTime(2026, 4, 12), now: now, trip: trip), isNull);
    });

    test('future-day rejection takes priority even when a trip is given', () {
      final trip = _trip(start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 31));
      final error = validateEntryDate(DateTime(2026, 6, 16), now: now, trip: trip);
      expect(error, "You can't add an entry for a future day.");
    });
  });
}
