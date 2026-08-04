import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/models/trip.dart';

Trip _trip({
  required DateTime start,
  required DateTime end,
  DateTime? deletedAt,
}) {
  return Trip(
    id: 't',
    userId: 'u',
    title: 'Test Trip',
    startDate: start,
    endDate: end,
    deletedAt: deletedAt,
    createdAt: start,
    updatedAt: start,
  );
}

void main() {
  group('durationDays', () {
    test('single-day trip (start == end) is 1', () {
      final trip = _trip(
        start: DateTime(2026, 4, 10),
        end: DateTime(2026, 4, 10),
      );
      expect(trip.durationDays, 1);
    });

    test('multi-day trip within one month', () {
      final trip = _trip(
        start: DateTime(2026, 4, 10),
        end: DateTime(2026, 4, 14),
      );
      expect(trip.durationDays, 5);
    });

    test('multi-month trip spans the boundary correctly', () {
      final trip = _trip(
        start: DateTime(2026, 4, 30),
        end: DateTime(2026, 5, 2),
      );
      expect(trip.durationDays, 3);
    });

    test('normalises time-of-day components before computing', () {
      final trip = _trip(
        start: DateTime(2026, 4, 10, 23, 59),
        end: DateTime(2026, 4, 11, 0, 1),
      );
      expect(trip.durationDays, 2);
    });
  });

  group('isActiveOn', () {
    final trip = _trip(
      start: DateTime(2026, 4, 10),
      end: DateTime(2026, 4, 12),
    );

    test(
      'true on the start date',
      () => expect(trip.isActiveOn(DateTime(2026, 4, 10)), isTrue),
    );
    test(
      'true on the end date',
      () => expect(trip.isActiveOn(DateTime(2026, 4, 12)), isTrue),
    );
    test(
      'true in the middle',
      () => expect(trip.isActiveOn(DateTime(2026, 4, 11)), isTrue),
    );
    test(
      'false the day before start',
      () => expect(trip.isActiveOn(DateTime(2026, 4, 9)), isFalse),
    );
    test(
      'false the day after end',
      () => expect(trip.isActiveOn(DateTime(2026, 4, 13)), isFalse),
    );

    test('ignores time-of-day when comparing', () {
      expect(trip.isActiveOn(DateTime(2026, 4, 10, 23, 59)), isTrue);
      expect(trip.isActiveOn(DateTime(2026, 4, 12, 0, 1)), isTrue);
    });

    test('single-day trip is active only on that day', () {
      final single = _trip(
        start: DateTime(2026, 4, 10),
        end: DateTime(2026, 4, 10),
      );
      expect(single.isActiveOn(DateTime(2026, 4, 10)), isTrue);
      expect(single.isActiveOn(DateTime(2026, 4, 9)), isFalse);
      expect(single.isActiveOn(DateTime(2026, 4, 11)), isFalse);
    });
  });

  group('dayList', () {
    test('single-day trip has exactly one day', () {
      final trip = _trip(
        start: DateTime(2026, 4, 10),
        end: DateTime(2026, 4, 10),
      );
      expect(trip.dayList, [DateTime(2026, 4, 10)]);
    });

    test('multi-day trip lists every day inclusive, in order', () {
      final trip = _trip(
        start: DateTime(2026, 4, 10),
        end: DateTime(2026, 4, 13),
      );
      expect(trip.dayList, [
        DateTime(2026, 4, 10),
        DateTime(2026, 4, 11),
        DateTime(2026, 4, 12),
        DateTime(2026, 4, 13),
      ]);
    });

    test('multi-month trip crosses the month boundary correctly', () {
      final trip = _trip(
        start: DateTime(2026, 4, 29),
        end: DateTime(2026, 5, 1),
      );
      expect(trip.dayList, [
        DateTime(2026, 4, 29),
        DateTime(2026, 4, 30),
        DateTime(2026, 5, 1),
      ]);
    });

    test('length always matches durationDays', () {
      final trip = _trip(
        start: DateTime(2026, 1, 15),
        end: DateTime(2026, 3, 3),
      );
      expect(trip.dayList.length, trip.durationDays);
    });
  });

  group('toJson/fromJson/copyWith', () {
    test('round-trips through JSON', () {
      final trip = Trip(
        id: 'trip-1',
        userId: 'user-1',
        title: 'Kyoto Trip',
        coverPhotoPath: 'assets/mock/cover.jpg',
        startDate: DateTime(2026, 4, 10),
        endDate: DateTime(2026, 4, 12),
        notes: 'Pack rain jacket',
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
        deletedAt: DateTime.utc(2026, 4, 2, 6),
      );
      final restored = Trip.fromJson(trip.toJson());
      expect(restored.id, trip.id);
      expect(restored.userId, trip.userId);
      expect(restored.title, trip.title);
      expect(restored.coverPhotoPath, trip.coverPhotoPath);
      expect(restored.startDate, trip.startDate);
      expect(restored.endDate, trip.endDate);
      expect(restored.notes, trip.notes);
      expect(restored.deletedAt, trip.deletedAt);
    });

    test('round-trips with null coverPhotoPath and null notes', () {
      final trip = Trip(
        id: 'trip-1',
        userId: 'user-1',
        title: 'Kyoto Trip',
        startDate: DateTime(2026, 4, 10),
        endDate: DateTime(2026, 4, 12),
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );
      final restored = Trip.fromJson(trip.toJson());
      expect(restored.coverPhotoPath, isNull);
      expect(restored.notes, isNull);
    });

    test('copyWith overrides only given fields', () {
      final trip = Trip(
        id: 'trip-1',
        userId: 'user-1',
        title: 'Kyoto Trip',
        startDate: DateTime(2026, 4, 10),
        endDate: DateTime(2026, 4, 12),
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      );
      final updated = trip.copyWith(title: 'Renamed');
      expect(updated.title, 'Renamed');
      expect(updated.startDate, trip.startDate);
      expect(updated.id, trip.id);
    });
  });

  group('trash lifecycle', () {
    test('keeps a trip recoverable until its 30-day expiry', () {
      final deletedAt = DateTime.utc(2026, 8, 5, 2, 15);
      final trip = _trip(
        start: DateTime.utc(2026, 8, 1),
        end: DateTime.utc(2026, 8, 3),
        deletedAt: deletedAt,
      );

      expect(trip.trashExpiresAt, DateTime.utc(2026, 9, 4, 2, 15));
      expect(trip.isRecoverableAt(DateTime.utc(2026, 9, 4, 2, 14, 59)), isTrue);
      expect(trip.isRecoverableAt(DateTime.utc(2026, 9, 4, 2, 15)), isFalse);
      expect(
        trip.remainingRecoveryDaysAt(DateTime.utc(2026, 8, 5, 14, 15)),
        30,
      );
    });

    test('clears deletedAt when requested through copyWith', () {
      final trip = _trip(
        start: DateTime.utc(2026, 8, 1),
        end: DateTime.utc(2026, 8, 3),
        deletedAt: DateTime.utc(2026, 8, 5, 2, 15),
      );

      expect(trip.copyWith(clearDeletedAt: true).deletedAt, isNull);
    });

    test('reports one remaining day during the final positive microsecond', () {
      final deletedAt = DateTime.utc(2026, 8, 5, 2, 15);
      final trip = _trip(
        start: DateTime.utc(2026, 8, 1),
        end: DateTime.utc(2026, 8, 3),
        deletedAt: deletedAt,
      );
      final expiry = deletedAt.add(const Duration(days: 30));

      expect(
        trip.isRecoverableAt(expiry.subtract(const Duration(microseconds: 1))),
        isTrue,
      );
      expect(
        trip.remainingRecoveryDaysAt(
          expiry.subtract(const Duration(microseconds: 1)),
        ),
        1,
      );
      expect(trip.remainingRecoveryDaysAt(expiry), 0);
    });

    test('handles an extreme positive remaining duration without overflow', () {
      const expectedDays = 106751991;
      const expiryMicros = 8640000000000000000;
      const remainingMicros = expectedDays * Duration.microsecondsPerDay;
      final expiry = DateTime.fromMicrosecondsSinceEpoch(
        expiryMicros,
        isUtc: true,
      );
      final deletedAt = expiry.subtract(const Duration(days: 30));
      final now = DateTime.fromMicrosecondsSinceEpoch(
        expiryMicros - remainingMicros,
        isUtc: true,
      );
      final trip = _trip(
        start: DateTime.utc(2026, 8, 1),
        end: DateTime.utc(2026, 8, 3),
        deletedAt: deletedAt,
      );

      expect(trip.trashExpiresAt, expiry);
      expect(trip.remainingRecoveryDaysAt(now), expectedDays);
    });
  });
}
