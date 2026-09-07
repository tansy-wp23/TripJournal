import 'package:flutter_test/flutter_test.dart';
import 'package:tripjournal/features/trip/trip_entry_date_range.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';
import 'package:tripjournal/models/trip.dart';

JournalEntry _entry(String id, DateTime createdAt, {DateTime? entryDate}) =>
    JournalEntry(
      id: id,
      tripId: 'trip-1',
      title: id,
      body: '',
      mood: Mood.neutral,
      photoPaths: const [],
      entryDate: entryDate,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

void main() {
  final trip = Trip(
    id: 'trip-1',
    userId: 'user-1',
    title: 'Eight day trip',
    startDate: DateTime(2026, 8, 11),
    endDate: DateTime(2026, 8, 18),
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );

  test(
    'keeps only entries on inclusive trip calendar dates in input order',
    () {
      final before = _entry('before', DateTime(2026, 8, 10, 23, 59));
      final day1 = _entry('day-1', DateTime(2026, 8, 11, 0, 1));
      final day8 = _entry('day-8', DateTime(2026, 8, 18, 23, 59));
      final after = _entry('after', DateTime(2026, 8, 25, 12));

      expect(entriesWithinTrip(trip, [before, day1, day8, after]), [
        day1,
        day8,
      ]);
      expect(isEntryWithinTrip(trip, before), isFalse);
      expect(isEntryWithinTrip(trip, day1), isTrue);
      expect(isEntryWithinTrip(trip, day8), isTrue);
      expect(isEntryWithinTrip(trip, after), isFalse);
    },
  );

  test('checks the logical entry date instead of the UTC timestamp date', () {
    final boundaryTrip = Trip(
      id: 'trip-1',
      userId: 'user-1',
      title: 'Boundary trip',
      startDate: DateTime(2026, 9, 7),
      endDate: DateTime(2026, 9, 8),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );
    final entry = _entry(
      'utc-boundary',
      DateTime.utc(2026, 9, 6, 10, 2, 38),
      entryDate: DateTime(2026, 9, 7),
    );

    expect(isEntryWithinTrip(boundaryTrip, entry), isTrue);
  });
}
