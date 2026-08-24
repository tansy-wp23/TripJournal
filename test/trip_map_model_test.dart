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

  test('model defensively exposes an unmodifiable connector list', () {
    const connector = TripMapDayConnector(
      fromDay: 1,
      toDay: 2,
      fromLatitude: 1,
      fromLongitude: 2,
      toLatitude: 3,
      toLongitude: 4,
      fromLabel: 'From',
      toLabel: 'To',
    );
    final source = <TripMapDayConnector>[connector];
    final model = TripMapModel(
      groups: const [],
      connectors: source,
      availableDays: const [],
      mappedEntryCount: 0,
      unmappedEntryCount: 0,
      bounds: null,
      previousDayHasNoMappedEntry: false,
    );

    source.clear();

    expect(model.connectors, [connector]);
    expect(() => model.connectors.clear(), throwsUnsupportedError);
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
      final selectedDayGroup = model.groups.singleWhere(
        (group) => !group.isPreviousDayContext,
      );
      expect(selectedDayGroup.dayNumber, 2);
      expect(selectedDayGroup.entries.single.id, 'day-2');
    },
  );

  test('converts UTC timestamps before deriving their local calendar day', () {
    final localEntryTime = DateTime(2026, 8, 16, 0, 15);
    final model = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'utc-day-2',
          createdAt: localEntryTime.toUtc(),
          location: const GeoTag(latitude: 3, longitude: 4),
        ),
      ],
      tripStartDate: tripStart,
    );

    expect(model.groups.single.dayNumber, 2);
  });

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

  test(
    'bounds include connector endpoints that differ from grouped markers',
    () {
      final model = buildTripMapModel(
        entries: [
          journalEntry(
            id: 'day-1-first',
            createdAt: tripStart,
            location: const GeoTag(
              latitude: 1,
              longitude: 2,
              placeId: 'day-1-place',
            ),
          ),
          journalEntry(
            id: 'day-1-last',
            createdAt: tripStart.add(const Duration(hours: 2)),
            location: const GeoTag(
              latitude: -10,
              longitude: 120,
              placeId: 'day-1-place',
            ),
          ),
          journalEntry(
            id: 'day-2-first',
            createdAt: tripStart.add(const Duration(days: 1)),
            location: const GeoTag(latitude: 3, longitude: 4),
          ),
        ],
        tripStartDate: tripStart,
      );

      expect(model.bounds?.southWestLatitude, -10);
      expect(model.bounds?.northEastLongitude, 120);
    },
  );

  test('bounds use the short wrapped interval across the antimeridian', () {
    final model = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'west-of-dateline',
          createdAt: tripStart,
          location: const GeoTag(latitude: 10, longitude: 179),
        ),
        journalEntry(
          id: 'east-of-dateline',
          createdAt: tripStart.add(const Duration(hours: 1)),
          location: const GeoTag(latitude: 11, longitude: -179),
        ),
      ],
      tripStartDate: tripStart,
    );

    expect(model.bounds?.southWestLongitude, 179);
    expect(model.bounds?.northEastLongitude, -179);
  });

  test(
    'connects each adjacent day last stop to next day first stop using ID ties',
    () {
      final tiedDayOne = tripStart.add(const Duration(hours: 20));
      final tiedDayTwo = tripStart.add(const Duration(days: 1, hours: 1));
      final model = buildTripMapModel(
        entries: [
          journalEntry(
            id: 'day-2-later-id',
            createdAt: tiedDayTwo,
            location: const GeoTag(
              latitude: 30,
              longitude: 40,
              placeName: 'Not first',
            ),
          ),
          journalEntry(
            id: 'day-1-earlier-id',
            createdAt: tiedDayOne,
            location: const GeoTag(latitude: 1, longitude: 2),
          ),
          journalEntry(
            id: 'day-2-earlier-id',
            createdAt: tiedDayTwo,
            location: const GeoTag(
              latitude: 3,
              longitude: 4,
              placeName: 'Day two first',
            ),
          ),
          journalEntry(
            id: 'day-1-later-id',
            createdAt: tiedDayOne,
            location: const GeoTag(
              latitude: 10,
              longitude: 20,
              placeName: 'Day one last',
            ),
          ),
        ],
        tripStartDate: tripStart,
      );

      expect(model.connectors, hasLength(1));
      final connector = model.connectors.single;
      expect(connector.id, 'day-1-to-day-2');
      expect(connector.fromDay, 1);
      expect(connector.toDay, 2);
      expect(connector.fromLatitude, 10);
      expect(connector.fromLongitude, 20);
      expect(connector.toLatitude, 3);
      expect(connector.toLongitude, 4);
      expect(connector.fromLabel, 'Day one last');
      expect(connector.toLabel, 'Day two first');
      expect(() => model.connectors.add(connector), throwsUnsupportedError);
    },
  );

  test('does not bridge missing days or connect normalized same locations', () {
    final sameCoordinateModel = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'day-1',
          createdAt: tripStart,
          location: const GeoTag(
            latitude: 1.2345671,
            longitude: 2.3456781,
            placeId: 'first-id',
          ),
        ),
        journalEntry(
          id: 'day-2',
          createdAt: tripStart.add(const Duration(days: 1)),
          location: const GeoTag(
            latitude: 1.2345674,
            longitude: 2.3456784,
            placeId: 'second-id',
          ),
        ),
      ],
      tripStartDate: tripStart,
    );
    expect(sameCoordinateModel.connectors, isEmpty);

    final samePlaceModel = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'day-1',
          createdAt: tripStart,
          location: const GeoTag(
            latitude: 1,
            longitude: 2,
            placeId: ' shared-place ',
          ),
        ),
        journalEntry(
          id: 'day-2',
          createdAt: tripStart.add(const Duration(days: 1)),
          location: const GeoTag(
            latitude: 9,
            longitude: 10,
            placeId: 'shared-place',
          ),
        ),
      ],
      tripStartDate: tripStart,
    );
    expect(samePlaceModel.connectors, isEmpty);

    final missingDayModel = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'day-1',
          createdAt: tripStart,
          location: const GeoTag(latitude: 1, longitude: 2),
        ),
        journalEntry(
          id: 'day-3',
          createdAt: tripStart.add(const Duration(days: 2)),
          location: const GeoTag(latitude: 3, longitude: 4),
        ),
      ],
      tripStartDate: tripStart,
    );
    expect(missingDayModel.connectors, isEmpty);
  });

  test('treats positive and negative 180 longitude as one location', () {
    final model = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'day-1',
          createdAt: tripStart,
          location: const GeoTag(latitude: 10, longitude: 180),
        ),
        journalEntry(
          id: 'day-2',
          createdAt: tripStart.add(const Duration(days: 1)),
          location: const GeoTag(latitude: 10, longitude: -180),
        ),
      ],
      tripStartDate: tripStart,
    );

    expect(model.connectors, isEmpty);
  });

  test(
    'selected day includes the previous final stop as muted context only',
    () {
      final model = buildTripMapModel(
        entries: [
          journalEntry(
            id: 'day-1-first',
            createdAt: tripStart,
            location: const GeoTag(latitude: 1, longitude: 2),
          ),
          journalEntry(
            id: 'day-1-last',
            createdAt: tripStart.add(const Duration(hours: 2)),
            location: const GeoTag(latitude: -8, longitude: 120),
          ),
          journalEntry(
            id: 'day-2-first',
            createdAt: tripStart.add(const Duration(days: 1)),
            location: const GeoTag(latitude: 3, longitude: 4),
          ),
          journalEntry(
            id: 'day-2-last',
            createdAt: tripStart.add(const Duration(days: 1, hours: 2)),
            location: const GeoTag(latitude: 5, longitude: 6),
          ),
          journalEntry(
            id: 'day-3',
            createdAt: tripStart.add(const Duration(days: 2)),
            location: const GeoTag(latitude: 7, longitude: 8),
          ),
        ],
        tripStartDate: tripStart,
        selectedDay: 2,
      );

      expect(model.groups, hasLength(3));
      final context = model.groups.singleWhere(
        (group) => group.isPreviousDayContext,
      );
      expect(context.dayNumber, 1);
      expect(context.entries.map((entry) => entry.id), ['day-1-last']);
      expect(
        model.groups
            .where((group) => !group.isPreviousDayContext)
            .expand((group) => group.entries)
            .map((entry) => entry.id),
        ['day-2-first', 'day-2-last'],
      );
      expect(model.connectors.map((connector) => connector.id), [
        'day-1-to-day-2',
      ]);
      expect(model.previousDayHasNoMappedEntry, isFalse);
      expect(model.bounds?.southWestLatitude, -8);
      expect(model.bounds?.northEastLongitude, 120);
    },
  );

  test(
    'selected mapped day reports a missing previous stop without showing context',
    () {
      final model = buildTripMapModel(
        entries: [
          journalEntry(
            id: 'day-3',
            createdAt: tripStart.add(const Duration(days: 2)),
            location: const GeoTag(latitude: 7, longitude: 8),
          ),
        ],
        tripStartDate: tripStart,
        selectedDay: 3,
      );

      expect(model.groups.map((group) => group.entries.single.id), ['day-3']);
      expect(model.groups.single.isPreviousDayContext, isFalse);
      expect(model.connectors, isEmpty);
      expect(model.previousDayHasNoMappedEntry, isTrue);
    },
  );

  test(
    'missing selected day stays empty instead of borrowing previous context',
    () {
      final model = buildTripMapModel(
        entries: [
          journalEntry(
            id: 'day-1',
            createdAt: tripStart,
            location: const GeoTag(latitude: 1, longitude: 2),
          ),
        ],
        tripStartDate: tripStart,
        selectedDay: 2,
      );

      expect(model.groups, isEmpty);
      expect(model.connectors, isEmpty);
      expect(model.previousDayHasNoMappedEntry, isFalse);
      expect(model.bounds, isNull);
    },
  );

  test('pre-trip day zero never connects to day one in selected or All', () {
    final entries = [
      journalEntry(
        id: 'day-0',
        createdAt: tripStart.subtract(const Duration(days: 1)),
        location: const GeoTag(latitude: -10, longitude: -20),
      ),
      journalEntry(
        id: 'day-1',
        createdAt: tripStart,
        location: const GeoTag(latitude: 10, longitude: 20),
      ),
    ];

    final selectedDayOne = buildTripMapModel(
      entries: entries,
      tripStartDate: tripStart,
      selectedDay: 1,
    );
    expect(selectedDayOne.connectors, isEmpty);
    expect(selectedDayOne.groups.map((group) => group.dayNumber), [1]);
    expect(selectedDayOne.bounds, isNull);

    final allDays = buildTripMapModel(
      entries: entries,
      tripStartDate: tripStart,
    );
    expect(allDays.connectors, isEmpty);
  });
}
