import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/current_user_id_provider.dart';
import 'package:tripjournal/data/trip_repository.dart';
import 'package:tripjournal/features/trip/controller/trip_trash_controller.dart';
import 'package:tripjournal/features/trip/mock_user.dart';
import 'package:tripjournal/features/trip/trip_form_screen.dart';
import 'package:tripjournal/models/trip.dart';

void main() {
  final now = DateTime.utc(2026, 8, 5, 12);

  testWidgets(
    'restore mode changes the title and hides permanent trip actions',
    (tester) async {
      final trip = _deletedTrip(now: now);
      final repository = _RestoreRepository()..deletedTrips.add(trip);
      final controller = _controller(repository, now);

      await tester.pumpWidget(_formApp(controller, trip));

      expect(find.text('Restore trip'), findsOneWidget);
      expect(find.byKey(const Key('delete-trip-button')), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Restore'), findsOneWidget);
    },
  );

  testWidgets(
    'restore mode keeps the existing cover read-only and retains its URL',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const coverUrl = 'https://images.example.com/deleted-cover.jpg';
      final trip = _deletedTrip(now: now).copyWith(coverPhotoPath: coverUrl);
      final repository = _RestoreRepository()..deletedTrips.add(trip);
      final controller = _controller(repository, now);

      await tester.pumpWidget(_formApp(controller, trip));

      expect(find.byKey(const Key('add-cover-photo-button')), findsNothing);
      expect(tester.widget<Chip>(find.byType(Chip)).onDeleted, isNull);

      await tester.tap(find.byKey(const Key('save-trip-button')));
      await tester.pumpAndSettle();

      expect(repository.restoreCalls, 1);
      expect(repository.activeTrips.single.coverPhotoPath, coverUrl);
    },
  );

  testWidgets(
    'restore form rejects an invalid date range before repository write',
    (tester) async {
      final trip = _deletedTrip(now: now).copyWith(
        startDate: DateTime(2026, 10, 3),
        endDate: DateTime(2026, 10, 1),
      );
      final repository = _RestoreRepository()..deletedTrips.add(trip);
      final controller = _controller(repository, now);

      await tester.pumpWidget(_formApp(controller, trip));
      await tester.tap(find.byKey(const Key('save-trip-button')));
      await tester.pump();

      expect(
        find.text('End date must be on or after the start date.'),
        findsOneWidget,
      );
      expect(repository.restoreCalls, 0);
    },
  );

  testWidgets(
    'restore form uses atomic restore path and returns true on success',
    (tester) async {
      final trip = _deletedTrip(now: now);
      final repository = _RestoreRepository()..deletedTrips.add(trip);
      final controller = _controller(repository, now);

      await tester.pumpWidget(_launcherApp(controller, trip));
      await tester.tap(find.text('Open restore form'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('trip-title-field')),
        'Recovered and Edited',
      );
      await tester.tap(find.byKey(const Key('save-trip-button')));
      await tester.pumpAndSettle();

      expect(find.text('Form result: true'), findsOneWidget);
      expect(repository.restoreCalls, 1);
      expect(repository.updateCalls, 0);
      expect(repository.activeTrips.single.title, 'Recovered and Edited');
      expect(repository.activeTrips.single.deletedAt, isNull);
    },
  );

  testWidgets(
    'restore conflict stays in the form and identifies the active trip',
    (tester) async {
      final trip = _deletedTrip(now: now);
      final repository = _RestoreRepository()
        ..deletedTrips.add(trip)
        ..activeTrips.add(
          _trip(
            id: 'active',
            title: 'Already Active',
            start: trip.startDate,
            end: trip.endDate,
          ),
        );
      final controller = _controller(repository, now);

      await tester.pumpWidget(_formApp(controller, trip));
      await tester.tap(find.byKey(const Key('save-trip-button')));
      await tester.pumpAndSettle();

      expect(find.text('Restore trip'), findsOneWidget);
      expect(find.textContaining('Already Active'), findsOneWidget);
      expect(repository.restoreCalls, 0);
    },
  );

  testWidgets('double-tapping Restore starts only one atomic restore', (
    tester,
  ) async {
    final trip = _deletedTrip(now: now);
    final repository = _RestoreRepository()
      ..deletedTrips.add(trip)
      ..restoreGate = Completer<void>();
    final controller = _controller(repository, now);

    await tester.pumpWidget(_formApp(controller, trip));
    await tester.tap(find.byKey(const Key('save-trip-button')));
    await tester.tap(find.byKey(const Key('save-trip-button')));
    await tester.pump();
    final restoreButton = tester.widget<FilledButton>(
      find.byKey(const Key('save-trip-button')),
    );

    expect(repository.restoreCalls, 1);
    expect(restoreButton.onPressed, isNull);

    repository.restoreGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a delayed restore failure after disposal does not call setState',
    (tester) async {
      final trip = _deletedTrip(now: now);
      final repository = _RestoreRepository()
        ..deletedTrips.add(trip)
        ..restoreGate = Completer<void>()
        ..failRestore = true;
      final controller = _controller(repository, now);

      await tester.pumpWidget(_launcherApp(controller, trip));
      await tester.tap(find.text('Open restore form'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-trip-button')));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      repository.restoreGate!.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}

TripTrashController _controller(_RestoreRepository repository, DateTime now) {
  return TripTrashController(
    repository,
    const _FixedUserProvider(),
    clock: () => now,
  );
}

Widget _formApp(TripTrashController controller, Trip trip) {
  return ProviderScope(
    overrides: [tripTrashControllerProvider.overrideWith((ref) => controller)],
    child: MaterialApp(
      home: TripFormScreen(existingTrip: trip, restoreOnSave: true),
    ),
  );
}

Widget _launcherApp(TripTrashController controller, Trip trip) {
  return ProviderScope(
    overrides: [tripTrashControllerProvider.overrideWith((ref) => controller)],
    child: MaterialApp(home: _RestoreFormLauncher(trip: trip)),
  );
}

class _RestoreFormLauncher extends StatefulWidget {
  const _RestoreFormLauncher({required this.trip});

  final Trip trip;

  @override
  State<_RestoreFormLauncher> createState() => _RestoreFormLauncherState();
}

class _RestoreFormLauncherState extends State<_RestoreFormLauncher> {
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
                MaterialPageRoute(
                  builder: (_) => TripFormScreen(
                    existingTrip: widget.trip,
                    restoreOnSave: true,
                  ),
                ),
              );
              if (mounted) setState(() => _result = result);
            },
            child: const Text('Open restore form'),
          ),
          Text('Form result: $_result'),
        ],
      ),
    );
  }
}

Trip _deletedTrip({required DateTime now}) {
  return _trip(
    id: 'deleted',
    title: 'Deleted Trip',
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 3),
    deletedAt: now.subtract(const Duration(days: 1)),
  );
}

Trip _trip({
  required String id,
  required String title,
  required DateTime start,
  required DateTime end,
  DateTime? deletedAt,
}) {
  return Trip(
    id: id,
    userId: kMockUserId,
    title: title,
    destination: 'Test destination',
    startDate: start,
    endDate: end,
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

final class _RestoreRepository implements TripRepository {
  final List<Trip> activeTrips = [];
  final List<Trip> deletedTrips = [];
  int restoreCalls = 0;
  int updateCalls = 0;
  bool failRestore = false;
  Completer<void>? restoreGate;

  @override
  Future<List<Trip>> getTrips(String userId) async => activeTrips
      .where((trip) => trip.userId == userId && trip.deletedAt == null)
      .toList();

  @override
  Future<List<Trip>> getDeletedTrips(String userId) async => deletedTrips
      .where((trip) => trip.userId == userId && trip.deletedAt != null)
      .toList();

  @override
  Future<void> restoreTrip(Trip trip) async {
    restoreCalls++;
    await restoreGate?.future;
    if (failRestore) throw StateError('restore failed after delay');
    deletedTrips.removeWhere((candidate) => candidate.id == trip.id);
    activeTrips.add(trip.copyWith(clearDeletedAt: true));
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    updateCalls++;
  }

  @override
  Future<void> addTrip(Trip trip) async {}

  @override
  Future<Trip?> getTrip(String id) async => null;

  @override
  Future<void> moveToTrash(String id) async {}
}
