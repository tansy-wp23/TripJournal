import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_photos.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/mood.dart';
import 'package:tripjournal/models/trip.dart';

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

Meal _meal({required String id, String? photoPath}) {
  return Meal(
    id: id,
    name: 'meal-$id',
    calories: 500,
    mealType: MealType.lunch,
    photoPath: photoPath,
  );
}

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  List<String> photoPaths = const [],
  List<Meal> meals = const [],
  String title = '',
}) {
  return JournalEntry(
    id: id,
    tripId: 't',
    title: title.isEmpty ? 'title-$id' : title,
    body: 'body',
    mood: Mood.neutral,
    photoPaths: photoPaths,
    createdAt: createdAt,
    updatedAt: createdAt,
    healthLog: meals.isEmpty
        ? null
        : HealthLog(
            id: 'hl-$id',
            entryId: id,
            steps: 0,
            caloriesEaten: 0,
            meals: meals,
          ),
  );
}

void main() {
  group('buildTripPhotos', () {
    test('orders by day, then entry, then entry photos before meal photos', () {
      final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 11));
      final entries = [
        _entry(
          id: 'day2',
          createdAt: DateTime(2026, 4, 11, 9),
          photoPaths: const ['d2-a.jpg'],
        ),
        _entry(
          id: 'day1',
          createdAt: DateTime(2026, 4, 10, 9),
          photoPaths: const ['d1-a.jpg', 'd1-b.jpg'],
          meals: [_meal(id: 'm1', photoPath: 'd1-meal.jpg')],
        ),
      ];

      final photos = buildTripPhotos(trip, entries);

      expect(
        photos.map((p) => p.path),
        ['d1-a.jpg', 'd1-b.jpg', 'd1-meal.jpg', 'd2-a.jpg'],
      );
      expect(
        photos.map((p) => p.kind),
        [
          TripPhotoKind.entry,
          TripPhotoKind.entry,
          TripPhotoKind.meal,
          TripPhotoKind.entry,
        ],
      );
      expect(photos.map((p) => p.dayNumber), [1, 1, 1, 2]);
      expect(photos.first.date, DateTime(2026, 4, 10));
      expect(photos.last.date, DateTime(2026, 4, 11));
    });

    test('tags each photo with the entry that owns it', () {
      final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 10));
      final entries = [
        _entry(
          id: 'e1',
          createdAt: DateTime(2026, 4, 10, 9),
          photoPaths: const ['a.jpg'],
          meals: [_meal(id: 'm1', photoPath: 'meal.jpg')],
        ),
      ];

      final photos = buildTripPhotos(trip, entries);

      // A meal photo points at the *entry*, not the meal — the meal has no
      // screen of its own to navigate back to.
      expect(photos.every((p) => p.entryId == 'e1'), isTrue);
    });

    test('captions entry photos with the entry title and meal photos with the meal name', () {
      final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 10));
      final entries = [
        _entry(
          id: 'e1',
          createdAt: DateTime(2026, 4, 10, 9),
          title: 'Arrival in Kyoto',
          photoPaths: const ['a.jpg'],
          meals: [_meal(id: 'm1', photoPath: 'meal.jpg')],
        ),
      ];

      final photos = buildTripPhotos(trip, entries);

      expect(photos[0].caption, 'Arrival in Kyoto');
      expect(photos[1].caption, 'meal-m1');
    });

    test('skips meals with no photo', () {
      final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 10));
      final entries = [
        _entry(
          id: 'e1',
          createdAt: DateTime(2026, 4, 10, 9),
          meals: [
            _meal(id: 'typed-by-hand'),
            _meal(id: 'photographed', photoPath: 'meal.jpg'),
          ],
        ),
      ];

      final photos = buildTripPhotos(trip, entries);

      expect(photos.map((p) => p.path), ['meal.jpg']);
    });

    test('drops entries outside the trip date range, matching the timeline', () {
      final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 11));
      final entries = [
        _entry(
          id: 'outside',
          createdAt: DateTime(2026, 5, 1),
          photoPaths: const ['stray.jpg'],
        ),
      ];

      expect(buildTripPhotos(trip, entries), isEmpty);
    });

    test('a trip with no photos produces an empty list', () {
      final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 12));
      final entries = [_entry(id: 'e1', createdAt: DateTime(2026, 4, 10, 9))];

      expect(buildTripPhotos(trip, entries), isEmpty);
    });

    test('same-timestamp entries order identically no matter how the input is arranged', () {
      final trip = _trip(start: DateTime(2026, 4, 10), end: DateTime(2026, 4, 10));
      // deriveEntryTimestamp stamps every backfilled past day at exactly noon,
      // so identical createdAt values are routine rather than hypothetical.
      final noon = DateTime(2026, 4, 10, 12);
      final entries = [
        _entry(id: 'c', createdAt: noon, photoPaths: const ['c.jpg']),
        _entry(id: 'a', createdAt: noon, photoPaths: const ['a.jpg']),
        _entry(id: 'b', createdAt: noon, photoPaths: const ['b.jpg']),
      ];

      final expected = ['a.jpg', 'b.jpg', 'c.jpg'];
      expect(buildTripPhotos(trip, entries).map((p) => p.path), expected);
      expect(
        buildTripPhotos(trip, entries.reversed.toList()).map((p) => p.path),
        expected,
      );
      expect(
        buildTripPhotos(trip, [entries[1], entries[2], entries[0]]).map((p) => p.path),
        expected,
      );
    });
  });

  group('firstIndexForDay', () {
    List<TripPhoto> photosFor(List<int> dayNumbers) {
      return [
        for (var i = 0; i < dayNumbers.length; i++)
          TripPhoto(
            path: 'p$i.jpg',
            kind: TripPhotoKind.entry,
            entryId: 'e',
            date: DateTime(2026, 4, 9 + dayNumbers[i]),
            dayNumber: dayNumbers[i],
          ),
      ];
    }

    test('returns the first photo of the requested day', () {
      final photos = photosFor([1, 1, 2, 3, 3]);
      expect(firstIndexForDay(photos, 1), 0);
      expect(firstIndexForDay(photos, 2), 2);
      expect(firstIndexForDay(photos, 3), 3);
    });

    test('falls forward to the next day that has photos', () {
      // Day 2 has none — land on day 3 rather than failing.
      final photos = photosFor([1, 3]);
      expect(firstIndexForDay(photos, 2), 1);
    });

    test('clamps to the last photo when the day is past everything', () {
      final photos = photosFor([1, 2]);
      expect(firstIndexForDay(photos, 9), 1);
    });

    test('returns 0 for an empty list so callers never see -1', () {
      expect(firstIndexForDay(const [], 3), 0);
    });
  });
}
