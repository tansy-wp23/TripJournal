import 'package:flutter_test/flutter_test.dart';
import 'package:tripjournal/features/trip/map/trip_map_model.dart';
import 'package:tripjournal/models/geo_tag.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

JournalEntry journalEntry({
  required String id,
  required DateTime createdAt,
  DateTime? creationOrderAt,
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
    creationOrderAt: creationOrderAt,
  );
}

void main() {
  final tripStart = DateTime(2026, 8, 15);
  final tripEnd = DateTime(2026, 9, 30);

  test('excludes mapped entries outside the inclusive trip dates', () {
    final day1 = journalEntry(
      id: 'day-1',
      createdAt: DateTime(2026, 8, 11, 9),
      location: const GeoTag(latitude: 1, longitude: 1),
    );
    final day2 = journalEntry(
      id: 'day-2',
      createdAt: DateTime(2026, 8, 12, 9),
      location: const GeoTag(latitude: 2, longitude: 2),
    );
    final day15 = journalEntry(
      id: 'day-15',
      createdAt: DateTime(2026, 8, 25, 9),
      location: const GeoTag(latitude: 15, longitude: 15),
    );

    final model = buildTripMapModel(
      entries: [day1, day2, day15],
      tripStartDate: DateTime(2026, 8, 11),
      tripEndDate: DateTime(2026, 8, 18),
    );

    expect(model.availableDays, [1, 2]);
    expect(model.mappedEntryCount, 2);
    expect(
      model.groups.expand((group) => group.entries),
      isNot(contains(day15)),
    );
  });

  test('returns an empty model for entries without coordinates', () {
    final model = buildTripMapModel(
      entries: [journalEntry(id: 'unmapped', createdAt: tripStart)],
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
    );

    expect(model.groups, isEmpty);
    expect(model.availableDays, isEmpty);
    expect(model.mappedEntryCount, 0);
    expect(model.unmappedEntryCount, 1);
    expect(model.bounds, isNull);
  });

  test('model defensively exposes an unmodifiable route segment list', () {
    const segment = TripMapRouteSegment(
      fromEntryId: 'from',
      toEntryId: 'to',
      fromDay: 1,
      toDay: 2,
      fromLatitude: 1,
      fromLongitude: 2,
      toLatitude: 3,
      toLongitude: 4,
      fromLabel: 'From',
      toLabel: 'To',
    );
    final source = <TripMapRouteSegment>[segment];
    final model = TripMapModel(
      groups: const [],
      routeSegments: source,
      availableDays: const [],
      mappedEntryCount: 0,
      unmappedEntryCount: 0,
      bounds: null,
    );

    source.clear();

    expect(model.routeSegments, [segment]);
    expect(() => model.routeSegments.clear(), throwsUnsupportedError);
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
              latitude: 35.0000001,
              longitude: 135.0000001,
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
        tripEndDate: tripEnd,
      );

      expect(model.groups, hasLength(1));
      expect(model.groups.single.key, 'place:shrine-1:35.000000,135.000000');
      expect(model.groups.single.entries.map((entry) => entry.id), [
        'earlier',
        'later',
      ]);
      expect(model.groups.single.latitude, 35);
      expect(model.groups.single.longitude, 135);
      expect(model.mappedEntryCount, 2);
    },
  );

  test('keeps different coordinates separate when Place IDs match', () {
    final model = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'day-2-second',
          createdAt: tripStart.add(const Duration(days: 1, hours: 2)),
          location: const GeoTag(
            latitude: 3.1579,
            longitude: 101.7123,
            placeId: 'broad-place-id',
          ),
        ),
        journalEntry(
          id: 'day-3',
          createdAt: tripStart.add(const Duration(days: 2)),
          location: const GeoTag(
            latitude: 3.1390,
            longitude: 101.6869,
            placeId: 'broad-place-id',
          ),
        ),
      ],
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
    );

    expect(model.groups, hasLength(2));
    expect(model.groups.map((group) => group.entries.single.id), [
      'day-2-second',
      'day-3',
    ]);
    expect(model.groups.map((group) => group.key).toSet(), hasLength(2));
  });

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
      tripEndDate: tripEnd,
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
        tripEndDate: tripEnd,
        selectedDay: 2,
      );

      expect(model.availableDays, [1, 2]);
      final selectedDayGroup = model.groups.singleWhere(
        (group) => group.dayNumber == 2,
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
      tripEndDate: tripEnd,
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
        tripEndDate: tripEnd,
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
      tripEndDate: tripEnd,
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
      tripEndDate: tripEnd,
    );
    expect(selected.bounds, isNull);
  });

  test('bounds include route endpoints that differ from grouped markers', () {
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
      tripEndDate: tripEnd,
    );

    expect(model.bounds?.southWestLatitude, -10);
    expect(model.bounds?.northEastLongitude, 120);
  });

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
      tripEndDate: tripEnd,
    );

    expect(model.bounds?.southWestLongitude, 179);
    expect(model.bounds?.northEastLongitude, -179);
  });

  test(
    'routes by trip day then immutable creation order despite input and edits',
    () {
      final sameDayTwoTime = tripStart.add(const Duration(days: 1, hours: 1));
      final nice = journalEntry(
        id: 'nice',
        createdAt: sameDayTwoTime,
        creationOrderAt: tripStart.add(const Duration(minutes: 3)),
        location: const GeoTag(latitude: 3, longitude: 4, placeName: 'Nice'),
      );
      final ur = journalEntry(
        id: 'ur',
        createdAt: sameDayTwoTime,
        creationOrderAt: tripStart.add(const Duration(minutes: 4)),
        location: const GeoTag(latitude: 5, longitude: 6, placeName: 'UR'),
      );
      final entries = [
        journalEntry(
          id: 'day-3-a',
          createdAt: tripStart.add(const Duration(days: 2)),
          creationOrderAt: tripStart.add(const Duration(minutes: 1)),
          location: const GeoTag(latitude: 7, longitude: 8),
        ),
        ur,
        journalEntry(
          id: 'day-1-b',
          createdAt: tripStart.add(const Duration(hours: 20)),
          creationOrderAt: tripStart.add(const Duration(minutes: 2)),
          location: const GeoTag(latitude: 2, longitude: 3),
        ),
        nice,
        journalEntry(
          id: 'day-1-a',
          createdAt: tripStart.add(const Duration(hours: 22)),
          creationOrderAt: tripStart.add(const Duration(minutes: 1)),
          location: const GeoTag(latitude: 1, longitude: 2),
        ),
      ];

      final model = buildTripMapModel(
        entries: entries,
        tripStartDate: tripStart,
        tripEndDate: tripEnd,
      );

      const expectedIds = [
        'entry-day-1-a-to-day-1-b',
        'entry-day-1-b-to-nice',
        'entry-nice-to-ur',
        'entry-ur-to-day-3-a',
      ];
      expect(model.routeSegments.map((segment) => segment.id), expectedIds);

      final afterEdit = buildTripMapModel(
        entries: [
          for (final entry in entries)
            if (entry.id == 'ur')
              ur.copyWith(updatedAt: tripStart.add(const Duration(days: 10)))
            else
              entry,
        ],
        tripStartDate: tripStart,
        tripEndDate: tripEnd,
      );
      expect(afterEdit.routeSegments.map((segment) => segment.id), expectedIds);

      final niceToUr = model.routeSegments.singleWhere(
        (segment) => segment.id == 'entry-nice-to-ur',
      );
      expect(niceToUr.fromDay, 2);
      expect(niceToUr.toDay, 2);
      expect(niceToUr.fromLatitude, 3);
      expect(niceToUr.fromLongitude, 4);
      expect(niceToUr.toLatitude, 5);
      expect(niceToUr.toLongitude, 6);
      expect(niceToUr.fromLabel, 'Nice');
      expect(niceToUr.toLabel, 'UR');
    },
  );

  test('routes directly across a day without a mapped Entry', () {
    final model = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'day-1',
          createdAt: tripStart,
          location: const GeoTag(latitude: 1, longitude: 2),
        ),
        journalEntry(
          id: 'day-2-unmapped',
          createdAt: tripStart.add(const Duration(days: 1)),
        ),
        journalEntry(
          id: 'day-3',
          createdAt: tripStart.add(const Duration(days: 2)),
          location: const GeoTag(latitude: 3, longitude: 4),
        ),
      ],
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
    );

    expect(model.routeSegments, hasLength(1));
    final segment = model.routeSegments.single;
    expect(segment.fromDay, 1);
    expect(segment.toDay, 3);
  });

  test('omits only a zero-length pair and continues from the later Entry', () {
    final model = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'same-location-first',
          createdAt: tripStart,
          location: const GeoTag(
            latitude: 1.2345671,
            longitude: 2.3456781,
            placeId: 'first-id',
          ),
        ),
        journalEntry(
          id: 'same-location-later',
          createdAt: tripStart.add(const Duration(minutes: 1)),
          location: const GeoTag(
            latitude: 1.2345674,
            longitude: 2.3456784,
            placeId: 'second-id',
          ),
        ),
        journalEntry(
          id: 'next-different',
          createdAt: tripStart.add(const Duration(minutes: 2)),
          location: const GeoTag(latitude: 3, longitude: 4),
        ),
      ],
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
    );

    expect(model.routeSegments.map((segment) => segment.id), [
      'entry-same-location-later-to-next-different',
    ]);
  });

  test('does not route between normalized equal Place ID locations', () {
    final model = buildTripMapModel(
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
            latitude: 1,
            longitude: 2,
            placeId: 'shared-place',
          ),
        ),
      ],
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
    );
    expect(model.routeSegments, isEmpty);
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
      tripEndDate: tripEnd,
    );

    expect(model.routeSegments, isEmpty);
  });

  test('Day N includes the cumulative route through that day', () {
    final entries = [
      journalEntry(
        id: 'day-1-first',
        createdAt: tripStart,
        location: const GeoTag(latitude: 1, longitude: 2),
      ),
      journalEntry(
        id: 'day-1-last',
        createdAt: tripStart.add(const Duration(hours: 2)),
        location: const GeoTag(latitude: 2, longitude: 3),
      ),
      journalEntry(
        id: 'day-2-first',
        createdAt: tripStart.add(const Duration(days: 1)),
        location: const GeoTag(latitude: 3, longitude: 4),
      ),
      journalEntry(
        id: 'day-2-second',
        createdAt: tripStart.add(const Duration(days: 1, hours: 2)),
        location: const GeoTag(latitude: 4, longitude: 5),
      ),
      journalEntry(
        id: 'day-3',
        createdAt: tripStart.add(const Duration(days: 2)),
        location: const GeoTag(latitude: 5, longitude: 6),
      ),
    ];

    final day2 = buildTripMapModel(
      entries: entries,
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
      selectedDay: 2,
    );
    expect(
      day2.groups.expand((group) => group.entries).map((entry) => entry.id),
      ['day-1-first', 'day-1-last', 'day-2-first', 'day-2-second'],
    );
    expect(day2.routeSegments.map((segment) => segment.id), [
      'entry-day-1-first-to-day-1-last',
      'entry-day-1-last-to-day-2-first',
      'entry-day-2-first-to-day-2-second',
    ]);
    expect(
      day2.routeSegments.map((segment) => segment.toDay),
      everyElement(lessThanOrEqualTo(2)),
    );

    final day3 = buildTripMapModel(
      entries: entries,
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
      selectedDay: 3,
    );
    final all = buildTripMapModel(
      entries: entries,
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
    );
    expect(
      day3.groups.map((group) => group.key),
      all.groups.map((group) => group.key),
    );
    expect(day3.routeSegments.map((segment) => segment.id), [
      'entry-day-1-first-to-day-1-last',
      'entry-day-1-last-to-day-2-first',
      'entry-day-2-first-to-day-2-second',
      'entry-day-2-second-to-day-3',
    ]);
  });

  test('deleting a middle Entry reconnects its neighbors and keeps Day 3', () {
    final before = journalEntry(
      id: 'before',
      createdAt: tripStart,
      location: const GeoTag(latitude: 1, longitude: 2),
    );
    final middle = journalEntry(
      id: 'middle',
      createdAt: tripStart.add(const Duration(days: 1)),
      location: const GeoTag(latitude: 3, longitude: 4),
    );
    final after = journalEntry(
      id: 'after',
      createdAt: tripStart.add(const Duration(days: 2)),
      location: const GeoTag(latitude: 5, longitude: 6),
    );
    final beforeDelete = buildTripMapModel(
      entries: [before, middle, after],
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
      selectedDay: 3,
    );
    expect(beforeDelete.routeSegments, hasLength(2));

    final afterDelete = buildTripMapModel(
      entries: [before, after],
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
      selectedDay: 3,
    );

    expect(
      afterDelete.groups
          .expand((group) => group.entries)
          .map((entry) => entry.id),
      contains('after'),
    );
    expect(afterDelete.routeSegments.single.id, 'entry-before-to-after');
    expect(afterDelete.routeSegments.single.toDay, 3);
  });

  test(
    'selected Day 3 keeps the target after another Day 2 Entry is removed',
    () {
      final remaining = [
        journalEntry(
          id: 'day-1',
          createdAt: tripStart,
          location: const GeoTag(latitude: 1, longitude: 2),
        ),
        journalEntry(
          id: 'day-2-first',
          createdAt: tripStart.add(const Duration(days: 1)),
          location: const GeoTag(latitude: 3, longitude: 4),
        ),
        journalEntry(
          id: 'day-3',
          createdAt: tripStart.add(const Duration(days: 2)),
          location: const GeoTag(latitude: 5, longitude: 6),
        ),
      ];

      final model = buildTripMapModel(
        entries: remaining,
        tripStartDate: tripStart,
        tripEndDate: tripEnd,
        selectedDay: 3,
      );

      expect(
        model.groups.expand((group) => group.entries).map((entry) => entry.id),
        contains('day-3'),
      );
      final segment = model.routeSegments.singleWhere(
        (candidate) => candidate.id == 'entry-day-2-first-to-day-3',
      );
      expect((segment.toLatitude, segment.toLongitude), (5, 6));
    },
  );

  test('selected day does not bridge a missing previous day', () {
    final model = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'day-3',
          createdAt: tripStart.add(const Duration(days: 2)),
          location: const GeoTag(latitude: 7, longitude: 8),
        ),
      ],
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
      selectedDay: 3,
    );

    expect(model.groups.map((group) => group.entries.single.id), ['day-3']);
    expect(model.routeSegments, isEmpty);
  });

  test('missing selected day keeps earlier cumulative route history', () {
    final model = buildTripMapModel(
      entries: [
        journalEntry(
          id: 'day-1',
          createdAt: tripStart,
          location: const GeoTag(latitude: 1, longitude: 2),
        ),
      ],
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
      selectedDay: 2,
    );

    expect(model.groups.map((group) => group.entries.single.id), ['day-1']);
    expect(model.routeSegments, isEmpty);
    expect(model.bounds, isNull);
  });

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
      tripEndDate: tripEnd,
      selectedDay: 1,
    );
    expect(selectedDayOne.routeSegments, isEmpty);
    expect(selectedDayOne.groups.map((group) => group.dayNumber), [1]);
    expect(selectedDayOne.bounds, isNull);

    final allDays = buildTripMapModel(
      entries: entries,
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
    );
    expect(allDays.routeSegments, isEmpty);
  });
}
