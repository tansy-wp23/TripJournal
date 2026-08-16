import 'package:flutter_test/flutter_test.dart';
import 'package:tripjournal/features/trip/map/trip_map_model.dart';
import 'package:tripjournal/models/geo_tag.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

JournalEntry journalEntry({
  required String id,
  required DateTime createdAt,
  GeoTag? location,
}) {
  return JournalEntry(
    id: id,
    tripId: 'trip-1',
    title: id,
    body: '',
    mood: Mood.happy,
    photoPaths: const [],
    location: location,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  final tripStart = DateTime(2026, 8, 15);

  test('returns an empty model for entries without coordinates', () {
    final model = buildTripMapModel(
      entries: [journalEntry(id: 'unmapped', createdAt: tripStart)],
      tripStartDate: tripStart,
    );

    expect(model.groups, isEmpty);
    expect(model.availableDays, isEmpty);
    expect(model.mappedEntryCount, 0);
    expect(model.unmappedEntryCount, 1);
    expect(model.bounds, isNull);
  });

  test(
    'groups identical trimmed place IDs and orders entries chronologically',
    () {
      final model = buildTripMapModel(
        entries: [
          journalEntry(
            id: 'later',
            createdAt: tripStart.add(const Duration(hours: 2)),
            location: const GeoTag(
              latitude: 35.0001,
              longitude: 135.0001,
              placeId: '  shrine-1  ',
            ),
          ),
          journalEntry(
            id: 'earlier',
            createdAt: tripStart,
            location: const GeoTag(
              latitude: 35,
              longitude: 135,
              placeId: 'shrine-1',
            ),
          ),
        ],
        tripStartDate: tripStart,
      );

      expect(model.groups, hasLength(1));
      expect(model.groups.single.key, 'place:shrine-1');
      expect(model.groups.single.entries.map((entry) => entry.id), [
        'earlier',
        'later',
      ]);
      expect(model.groups.single.latitude, 35);
      expect(model.groups.single.longitude, 135);
      expect(model.mappedEntryCount, 2);
    },
  );

  test('groups no-ID coordinates by six-decimal rounded coordinates', () {
    final model = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'a',
          createdAt: tripStart,
          location: const GeoTag(latitude: 1.2345671, longitude: 2.3456781),
        ),
        journalEntry(
          id: 'b',
          createdAt: tripStart.add(const Duration(minutes: 1)),
          location: const GeoTag(latitude: 1.2345674, longitude: 2.3456784),
        ),
      ],
      tripStartDate: tripStart,
    );

    expect(model.groups, hasLength(1));
    expect(model.groups.single.key, 'coord:1.234567,2.345678');
  });

  test(
    'uses local calendar days at midnight and preserves all available days',
    () {
      final midnight = DateTime(2026, 8, 16, 0, 15);
      final model = buildTripMapModel(
        entries: [
          journalEntry(
            id: 'day-1',
            createdAt: tripStart,
            location: const GeoTag(latitude: 1, longitude: 2),
          ),
          journalEntry(
            id: 'day-2',
            createdAt: midnight,
            location: const GeoTag(latitude: 3, longitude: 4),
          ),
        ],
        tripStartDate: tripStart,
        selectedDay: 2,
      );

      expect(model.availableDays, [1, 2]);
      expect(model.groups, hasLength(1));
      expect(model.groups.single.dayNumber, 2);
      expect(model.groups.single.entries.single.id, 'day-2');
    },
  );

  test(
    'sorts marker groups chronologically with deterministic tie ordering',
    () {
      final sameTime = tripStart.add(const Duration(hours: 1));
      final model = buildTripMapModel(
        entries: [
          journalEntry(
            id: 'z',
            createdAt: sameTime,
            location: const GeoTag(latitude: 9, longitude: 9),
          ),
          journalEntry(
            id: 'a',
            createdAt: sameTime,
            location: const GeoTag(latitude: 8, longitude: 8),
          ),
          journalEntry(
            id: 'first',
            createdAt: tripStart,
            location: const GeoTag(latitude: 7, longitude: 7),
          ),
        ],
        tripStartDate: tripStart,
      );

      expect(model.groups.map((group) => group.entries.first.id), [
        'first',
        'a',
        'z',
      ]);
    },
  );

  test('returns bounds only when there are at least two marker groups', () {
    final model = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'south',
          createdAt: tripStart,
          location: const GeoTag(latitude: -2, longitude: 5),
        ),
        journalEntry(
          id: 'north',
          createdAt: tripStart.add(const Duration(hours: 1)),
          location: const GeoTag(latitude: 4, longitude: -3),
        ),
      ],
      tripStartDate: tripStart,
    );

    expect(model.bounds?.southWestLatitude, -2);
    expect(model.bounds?.southWestLongitude, -3);
    expect(model.bounds?.northEastLatitude, 4);
    expect(model.bounds?.northEastLongitude, 5);

    final selected = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'one',
          createdAt: tripStart,
          location: const GeoTag(latitude: 1, longitude: 2),
        ),
      ],
      tripStartDate: tripStart,
    );
    expect(selected.bounds, isNull);
  });
}
