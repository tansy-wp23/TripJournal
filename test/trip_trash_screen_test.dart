import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/current_user_id_provider.dart';
import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/data/mock_trip_cover_storage.dart';
import 'package:tripjournal/data/trip_repository.dart';
import 'package:tripjournal/features/home/home_screen.dart';
import 'package:tripjournal/features/trip/controller/trip_controller.dart';
import 'package:tripjournal/features/trip/controller/trip_trash_controller.dart';
import 'package:tripjournal/features/trip/mock_user.dart';
import 'package:tripjournal/features/trip/screens/trip_trash_screen.dart';
import 'package:tripjournal/models/trip.dart';

void main() {
  final now = DateTime.utc(2026, 8, 5, 12);

  testWidgets('shows the Recently Deleted title and empty state', (
    tester,
  ) async {
    final controller = _controller(_TrashRepository(), () => now);

    await tester.pumpWidget(_trashApp(controller));
    await tester.pumpAndSettle();

    expect(find.text('Recently Deleted'), findsOneWidget);
    expect(find.text('No recently deleted trips.'), findsOneWidget);
  });

  testWidgets('shows deletion, expiration, and remaining-day metadata', (
    tester,
  ) async {
    final repository = _TrashRepository()
      ..deletedTrips.add(
        _trip(
          id: 'metadata',
          title: 'Metadata Trip',
          deletedAt: DateTime.utc(2026, 8, 4, 12),
        ),
      );
    final controller = _controller(repository, () => now);

    await tester.pumpWidget(_trashApp(controller));
    await tester.pumpAndSettle();

    expect(find.text('Metadata Trip'), findsOneWidget);
    expect(find.text('Deleted Aug 4, 2026'), findsOneWidget);
    expect(find.text('Expires Sep 3, 2026'), findsOneWidget);
    expect(find.text('29 days remaining'), findsOneWidget);
  });

  testWidgets('asks for confirmation before restoring', (tester) async {
    final repository = _TrashRepository()
      ..deletedTrips.add(
        _trip(
          id: 'confirm',
          title: 'Confirm Trip',
          deletedAt: now.subtract(const Duration(days: 1)),
        ),
      );
    final controller = _controller(repository, () => now);

    await tester.pumpWidget(_trashApp(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-trip-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Restore "Confirm Trip"?'), findsOneWidget);
    expect(
      find.text('Restore this trip and all of its journal entries?'),
      findsOneWidget,
    );
    expect(repository.restoreCalls, 0);

    await tester.tap(find.byKey(const Key('confirm-restore-trip-button')));
    await tester.pumpAndSettle();
    expect(repository.restoreCalls, 1);
  });

  testWidgets('successful direct restore returns true to the caller', (
    tester,
  ) async {
    final repository = _TrashRepository()
      ..deletedTrips.add(
        _trip(
          id: 'success',
          title: 'Successful Trip',
          deletedAt: now.subtract(const Duration(days: 1)),
        ),
      );
    final controller = _controller(repository, () => now);

    await tester.pumpWidget(_launcherApp(controller));
    await tester.tap(find.text('Open trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-trip-success')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-restore-trip-button')));
    await tester.pumpAndSettle();

    expect(find.text('Restore result: true'), findsOneWidget);
  });

  testWidgets('a conflict opens TripFormScreen in restore mode', (
    tester,
  ) async {
    final deleted = _trip(
      id: 'conflict',
      title: 'Conflict Trip',
      start: DateTime(2026, 9, 10),
      end: DateTime(2026, 9, 12),
      deletedAt: now.subtract(const Duration(days: 1)),
    );
    final repository = _TrashRepository()
      ..deletedTrips.add(deleted)
      ..activeTrips.add(
        _trip(
          id: 'active',
          title: 'Active Trip',
          start: DateTime(2026, 9, 11),
          end: DateTime(2026, 9, 13),
        ),
      );
    final controller = _controller(repository, () => now);

    await tester.pumpWidget(_trashApp(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-trip-conflict')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-restore-trip-button')));
    await tester.pumpAndSettle();

    expect(find.text('Restore trip'), findsOneWidget);
    expect(find.byKey(const Key('delete-trip-button')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('trip-title-field')))
          .controller
          ?.text,
      'Conflict Trip',
    );
  });

  testWidgets(
    'an item disables automatically when exact expiry passes while mounted',
    (tester) async {
      final deletedAt = DateTime.utc(2026, 7, 6, 12);
      final exactExpiry = deletedAt.add(const Duration(days: 30));
      var clockNow = exactExpiry.subtract(const Duration(seconds: 1));
      final repository = _TrashRepository()
        ..deletedTrips.add(_trip(id: 'expired', deletedAt: deletedAt));
      final controller = _controller(repository, () => clockNow);

      await tester.pumpWidget(_trashApp(controller));
      await tester.pumpAndSettle();

      var button = tester.widget<FilledButton>(
        find.byKey(const Key('restore-trip-expired')),
      );
      expect(button.onPressed, isNotNull);
      expect(find.text('1 day remaining'), findsOneWidget);

      clockNow = exactExpiry;
      await tester.pump(const Duration(seconds: 1));

      button = tester.widget<FilledButton>(
        find.byKey(const Key('restore-trip-expired')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Recovery period expired'), findsOneWidget);
    },
  );

  testWidgets(
    'a stale enabled action reports expiry instead of silently returning',
    (tester) async {
      final deletedAt = DateTime.utc(2026, 7, 6, 12);
      final exactExpiry = deletedAt.add(const Duration(days: 30));
      var clockNow = exactExpiry.subtract(const Duration(seconds: 1));
      final repository = _TrashRepository()
        ..deletedTrips.add(_trip(id: 'expiry-race', deletedAt: deletedAt));
      final controller = _controller(repository, () => clockNow);

      await tester.pumpWidget(_trashApp(controller));
      await tester.pumpAndSettle();

      clockNow = exactExpiry;
      await tester.tap(find.byKey(const Key('restore-trip-expiry-race')));
      await tester.pump();

      expect(
        find.text('This trip\'s recovery period has expired.'),
        findsOneWidget,
      );
      expect(find.text('Recovery period expired'), findsOneWidget);
      expect(repository.restoreCalls, 0);
    },
  );

  testWidgets('returning true from trash reloads Home and shows the trip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TrashRepository()
      ..deletedTrips.add(
        _trip(
          id: 'home-restored',
          title: 'Restored Home Trip',
          start: DateTime(2045, 1, 1),
          end: DateTime(2045, 1, 2),
          deletedAt: now.subtract(const Duration(days: 1)),
        ),
      );
    final trashController = _controller(repository, () => now);
    final tripController = TripController(
      repository,
      MockJournalRepository(),
      MockTripCoverStorage(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripTrashControllerProvider.overrideWith((ref) => trashController),
          tripControllerProvider.overrideWith((ref) => tripController),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Restored Home Trip'), findsNothing);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recently Deleted'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-trip-home-restored')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-restore-trip-button')));
    await tester.pumpAndSettle();

    expect(find.text('Restored Home Trip'), findsOneWidget);
    expect(repository.getTripsCalls, greaterThanOrEqualTo(3));
  });
}

TripTrashController _controller(
  _TrashRepository repository,
  DateTime Function() clock,
) {
  return TripTrashController(
    repository,
    const _FixedUserProvider(),
    clock: clock,
  );
}

Widget _trashApp(TripTrashController controller) {
  return ProviderScope(
    overrides: [tripTrashControllerProvider.overrideWith((ref) => controller)],
    child: const MaterialApp(home: TripTrashScreen()),
  );
}

Widget _launcherApp(TripTrashController controller) {
  return ProviderScope(
    overrides: [tripTrashControllerProvider.overrideWith((ref) => controller)],
    child: const MaterialApp(home: _TrashLauncher()),
  );
}

class _TrashLauncher extends StatefulWidget {
  const _TrashLauncher();

  @override
  State<_TrashLauncher> createState() => _TrashLauncherState();
}

class _TrashLauncherState extends State<_TrashLauncher> {
  bool? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          FilledButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const TripTrashScreen()),
              );
              if (mounted) setState(() => _result = result);
            },
            child: const Text('Open trash'),
          ),
          Text('Restore result: $_result'),
        ],
      ),
    );
  }
}

Trip _trip({
  required String id,
  String title = 'Deleted Trip',
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

final class _TrashRepository implements TripRepository {
  final List<Trip> activeTrips = [];
  final List<Trip> deletedTrips = [];
  int restoreCalls = 0;
  int getTripsCalls = 0;

  @override
  Future<List<Trip>> getTrips(String userId) async {
    getTripsCalls++;
    return activeTrips.where((trip) => trip.userId == userId).toList();
  }

  @override
  Future<List<Trip>> getDeletedTrips(String userId) async => deletedTrips
      .where((trip) => trip.userId == userId && trip.deletedAt != null)
      .toList();

  @override
  Future<void> restoreTrip(Trip trip) async {
    restoreCalls++;
    deletedTrips.removeWhere((candidate) => candidate.id == trip.id);
    activeTrips.add(trip.copyWith(clearDeletedAt: true));
  }

  @override
  Future<void> addTrip(Trip trip) async => activeTrips.add(trip);

  @override
  Future<Trip?> getTrip(String id) async {
    for (final trip in [...activeTrips, ...deletedTrips]) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  @override
  Future<void> moveToTrash(String id) async {}

  @override
  Future<void> updateTrip(Trip trip) async {
    final index = activeTrips.indexWhere(
      (candidate) => candidate.id == trip.id,
    );
    if (index != -1) activeTrips[index] = trip;
  }
}
