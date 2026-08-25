import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/current_user_id_provider.dart';
import 'package:tripjournal/data/trip_repository.dart';
import 'package:tripjournal/features/trip/controller/trip_trash_controller.dart';
import 'package:tripjournal/features/trip/mock_user.dart';
import 'package:tripjournal/models/trip.dart';

void main() {
  late DateTime now;
  late _MemoryTripRepository repository;
  late TripTrashController controller;

  setUp(() {
    now = DateTime.utc(2026, 8, 5, 12);
    repository = _MemoryTripRepository();
    controller = TripTrashController(
      repository,
      const _FixedUserProvider(),
      clock: () => now,
    );
  });

  tearDown(() => controller.dispose());

  test(
    'load keeps recoverable trips newest first and excludes exact expiry',
    () async {
      repository.deletedTrips.addAll([
        _trip(id: 'older', deletedAt: now.subtract(const Duration(days: 2))),
        _trip(id: 'expired', deletedAt: now.subtract(const Duration(days: 30))),
        _trip(id: 'newer', deletedAt: now.subtract(const Duration(hours: 1))),
      ]);

      await controller.load();

      expect(controller.trips.map((trip) => trip.id), ['newer', 'older']);
      expect(controller.error, isNull);
    },
  );

  test('restore before expiry succeeds and removes the trash item', () async {
    final deleted = _trip(
      id: 'recoverable',
      deletedAt: now.subtract(const Duration(days: 29)),
    );
    repository.deletedTrips.add(deleted);
    await controller.load();

    final result = await controller.restore(deleted);

    expect(result.status, TripRestoreStatus.restored);
    expect(controller.trips, isEmpty);
    expect(repository.activeTrips.single.id, deleted.id);
    expect(repository.activeTrips.single.deletedAt, isNull);
  });

  test(
    'restore at the exact expiry instant returns expired without writing',
    () async {
      final deletedAt = DateTime.utc(2026, 7, 6, 12);
      final deleted = _trip(id: 'expired-now', deletedAt: deletedAt);
      repository.deletedTrips.add(deleted);
      now = deletedAt.add(const Duration(days: 30, microseconds: -1));
      await controller.load();

      now = deletedAt.add(const Duration(days: 30));
      final result = await controller.restore(deleted);

      expect(result.status, TripRestoreStatus.expired);
      expect(result.message, contains('expired'));
      expect(repository.restoreCalls, 0);
      expect(controller.trips.single.id, deleted.id);
    },
  );

  test(
    'overlapping active trip returns conflict and names that trip',
    () async {
      final deleted = _trip(
        id: 'deleted',
        start: DateTime(2026, 9, 10),
        end: DateTime(2026, 9, 12),
        deletedAt: now.subtract(const Duration(days: 1)),
      );
      final active = _trip(
        id: 'active',
        title: 'Penang Weekend',
        start: DateTime(2026, 9, 12),
        end: DateTime(2026, 9, 14),
      );
      repository
        ..deletedTrips.add(deleted)
        ..activeTrips.add(active);
      await controller.load();

      final result = await controller.restore(deleted);

      expect(result.status, TripRestoreStatus.conflict);
      expect(result.conflict, same(active));
      expect(result.message, contains('Penang Weekend'));
      expect(repository.restoreCalls, 0);
      expect(controller.trips.single.id, deleted.id);
    },
  );

  test(
    'restoreWithChanges rejects an invalid range and retains the item',
    () async {
      final deleted = _trip(
        id: 'invalid-edit',
        deletedAt: now.subtract(const Duration(days: 1)),
      );
      repository.deletedTrips.add(deleted);
      await controller.load();

      final result = await controller.restoreWithChanges(
        deleted.copyWith(
          startDate: DateTime(2026, 10, 2),
          endDate: DateTime(2026, 10, 1),
        ),
      );

      expect(result.status, TripRestoreStatus.failed);
      expect(result.message, 'End date must be on or after the start date.');
      expect(repository.restoreCalls, 0);
      expect(controller.trips.single.id, deleted.id);
    },
  );

  test(
    'restoreWithChanges succeeds once edited dates no longer overlap',
    () async {
      final deleted = _trip(
        id: 'edited-restore',
        start: DateTime(2026, 9, 10),
        end: DateTime(2026, 9, 12),
        deletedAt: now.subtract(const Duration(days: 1)),
      );
      repository
        ..deletedTrips.add(deleted)
        ..activeTrips.add(
          _trip(
            id: 'active',
            title: 'Existing Trip',
            start: DateTime(2026, 9, 11),
            end: DateTime(2026, 9, 13),
          ),
        );
      await controller.load();
      final edited = deleted.copyWith(
        title: 'Edited Recovery',
        startDate: DateTime(2026, 9, 20),
        endDate: DateTime(2026, 9, 22),
      );

      final result = await controller.restoreWithChanges(edited);

      expect(result.status, TripRestoreStatus.restored);
      final restored = repository.activeTrips.firstWhere(
        (trip) => trip.id == deleted.id,
      );
      expect(restored.title, 'Edited Recovery');
      expect(restored.startDate, DateTime(2026, 9, 20));
      expect(restored.deletedAt, isNull);
      expect(controller.trips, isEmpty);
    },
  );

  test(
    'repository restore failure returns failed and retains the item',
    () async {
      final deleted = _trip(
        id: 'failed-restore',
        deletedAt: now.subtract(const Duration(days: 1)),
      );
      repository
        ..deletedTrips.add(deleted)
        ..failRestore = true;
      await controller.load();

      final result = await controller.restore(deleted);

      expect(result.status, TripRestoreStatus.failed);
      expect(result.message, contains('restore failed'));
      expect(controller.trips.single.id, deleted.id);
      expect(repository.deletedTrips.single.id, deleted.id);
    },
  );

  test(
    'successful restore stays successful when the follow-up refresh fails',
    () async {
      final deleted = _trip(
        id: 'refresh-fails',
        deletedAt: now.subtract(const Duration(days: 1)),
      );
      repository.deletedTrips.add(deleted);
      await controller.load();
      repository.failNextDeletedLoad = true;

      final result = await controller.restore(deleted);

      expect(result.status, TripRestoreStatus.restored);
      expect(result.message, contains('could not refresh'));
      expect(controller.trips, isEmpty);
      expect(repository.activeTrips.single.id, deleted.id);
    },
  );

  test('repeated restore taps cannot write the same trip twice', () async {
    final deleted = _trip(
      id: 'one-at-a-time',
      deletedAt: now.subtract(const Duration(days: 1)),
    );
    repository
      ..deletedTrips.add(deleted)
      ..restoreGate = Completer<void>();
    await controller.load();

    final first = controller.restore(deleted);
    await Future<void>.delayed(Duration.zero);
    final second = await controller.restore(deleted);
    repository.restoreGate!.complete();
    final firstResult = await first;

    expect(firstResult.status, TripRestoreStatus.restored);
    expect(second.status, TripRestoreStatus.failed);
    expect(second.message, contains('already in progress'));
    expect(repository.restoreCalls, 1);
  });

  test(
    'an older in-flight load cannot reinsert a successfully restored trip',
    () async {
      final deleted = _trip(
        id: 'stale-load',
        deletedAt: now.subtract(const Duration(days: 1)),
      );
      repository.deletedTrips.add(deleted);
      await controller.load();
      repository.deletedLoadGate = Completer<void>();

      final staleLoad = controller.load();
      await Future<void>.delayed(Duration.zero);
      final result = await controller.restore(deleted);
      repository.pendingDeletedLoadGate!.complete();
      await staleLoad;

      expect(result.status, TripRestoreStatus.restored);
      expect(controller.trips, isEmpty);
    },
  );

  test(
    'an older post-restore refresh cannot overwrite a newer restore result',
    () async {
      final tripA = _trip(
        id: 'trip-a',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 2),
        deletedAt: now.subtract(const Duration(days: 1)),
      );
      final tripB = _trip(
        id: 'trip-b',
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 2),
        deletedAt: now.subtract(const Duration(days: 1)),
      );
      repository.deletedTrips.addAll([tripA, tripB]);
      await controller.load();
      repository
        ..deletedLoadGate = Completer<void>()
        ..deletedLoadStarted = Completer<void>();

      final restoreA = controller.restore(tripA);
      await repository.deletedLoadStarted!.future;
      final resultB = await controller.restore(tripB);

      expect(resultB.status, TripRestoreStatus.restored);
      expect(controller.trips, isEmpty);

      repository.pendingDeletedLoadGate!.complete();
      final resultA = await restoreA;

      expect(resultA.status, TripRestoreStatus.restored);
      expect(controller.trips, isEmpty);
      expect(repository.restoreCalls, 2);
    },
  );

  test('a pending load may finish after disposal without notifying', () async {
    repository.deletedLoadGate = Completer<void>();
    final future = controller.load();
    controller.dispose();

    repository.pendingDeletedLoadGate!.complete();

    await expectLater(future, completes);
    controller = TripTrashController(
      repository,
      const _FixedUserProvider(),
      clock: () => now,
    );
  });
}

Trip _trip({
  required String id,
  String title = 'Recoverable Trip',
  DateTime? start,
  DateTime? end,
  DateTime? deletedAt,
}) {
  return Trip(
    id: id,
    userId: kMockUserId,
    title: title,
    startDate: start ?? DateTime(2026, 10, 1),
    endDate: end ?? DateTime(2026, 10, 3),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
    deletedAt: deletedAt,
  );
}

final class _FixedUserProvider implements CurrentUserIdProvider {
  const _FixedUserProvider();

  @override
  String requireUserId() => kMockUserId;
}

final class _MemoryTripRepository implements TripRepository {
  final List<Trip> activeTrips = [];
  final List<Trip> deletedTrips = [];
  bool failRestore = false;
  bool failNextDeletedLoad = false;
  int restoreCalls = 0;
  Completer<void>? restoreGate;
  Completer<void>? deletedLoadGate;
  Completer<void>? pendingDeletedLoadGate;
  Completer<void>? deletedLoadStarted;

  @override
  Future<List<Trip>> getTrips(String userId) async => activeTrips
      .where((trip) => trip.userId == userId && trip.deletedAt == null)
      .toList();

  @override
  Future<List<Trip>> getDeletedTrips(String userId) async {
    final snapshot = deletedTrips
        .where((trip) => trip.userId == userId && trip.deletedAt != null)
        .toList();
    final gate = deletedLoadGate;
    deletedLoadGate = null;
    if (gate != null) pendingDeletedLoadGate = gate;
    if (gate != null && deletedLoadStarted?.isCompleted == false) {
      deletedLoadStarted!.complete();
    }
    await gate?.future;
    if (failNextDeletedLoad) {
      failNextDeletedLoad = false;
      throw StateError('trash refresh failed');
    }
    return snapshot;
  }

  @override
  Future<List<Trip>> getPublicTrips() async => const [];

  @override
  Future<void> restoreTrip(Trip trip) async {
    restoreCalls++;
    await restoreGate?.future;
    if (failRestore) throw StateError('restore failed');
    deletedTrips.removeWhere((candidate) => candidate.id == trip.id);
    activeTrips.add(trip.copyWith(clearDeletedAt: true));
  }

  @override
  Future<void> addTrip(Trip trip) async {}

  @override
  Future<Trip?> getTrip(String id) async => null;

  @override
  Future<void> moveToTrash(String id) async {}

  @override
  Future<void> updateTrip(Trip trip) async {}
}
