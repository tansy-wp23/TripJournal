import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/current_user_id_provider.dart';
import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/data/mock_trip_cover_storage.dart';
import 'package:tripjournal/data/mock_trip_repository.dart';
import 'package:tripjournal/features/trip/controller/trip_controller.dart';
import 'package:tripjournal/features/trip/trip_form_screen.dart';
import 'package:tripjournal/models/trip.dart';

void main() {
  testWidgets(
    'cover photo picker offers camera and gallery, matching the journal entry photo flow',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pump the trip form directly rather than the full app: this test is
      // about the cover photo picker, not auth routing or Home's
      // "Create Trip" button.
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripFormScreen())));
      await tester.pumpAndSettle();

      expect(find.text('No cover photo added.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-cover-photo-button')));
      await tester.pumpAndSettle();

      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);

      // Under `flutter test` there's no interactive file dialog to complete,
      // so the real picker resolves with nothing picked — same behaviour as
      // a user backing out on a real device. Must not crash or get stuck.
      await tester.tap(find.byKey(const Key('pick-cover-photo-gallery')));
      await tester.pumpAndSettle();

      expect(find.text('No cover photo added.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new trips use a UUID and the current-user provider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MockTripRepository();
    final controller = TripController(
      repository,
      MockJournalRepository(),
      MockTripCoverStorage(),
    );
    const userId = '11111111-1111-4111-8111-111111111111';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripControllerProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: TripFormScreen(
            userIdProvider: _FixedCurrentUserIdProvider(userId),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('trip-title-field')),
      'Provider identity trip',
    );
    await tester.tap(find.byKey(const Key('save-trip-button')));
    await tester.pumpAndSettle();

    final created = (await repository.getTrips(userId)).single;
    expect(created.userId, userId);
    expect(
      created.id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  testWidgets('unauthenticated current-user errors are shown in the form', (
    tester,
  ) async {
    final controller = TripController(
      MockTripRepository(),
      MockJournalRepository(),
      MockTripCoverStorage(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripControllerProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: TripFormScreen(
            userIdProvider: _UnauthenticatedCurrentUserIdProvider(),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('trip-title-field')),
      'Requires sign in',
    );
    await tester.tap(find.byKey(const Key('save-trip-button')));
    await tester.pump();

    expect(find.text('Please sign in to manage trips.'), findsOneWidget);
  });

  testWidgets('unexpected current-user errors are shown and Save re-enables', (
    tester,
  ) async {
    final controller = TripController(
      MockTripRepository(),
      MockJournalRepository(),
      MockTripCoverStorage(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripControllerProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: TripFormScreen(
            userIdProvider: _UnexpectedErrorCurrentUserIdProvider(),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('trip-title-field')),
      'Provider failure',
    );

    await tester.tap(find.byKey(const Key('save-trip-button')));
    await tester.pump();

    expect(find.textContaining('identity provider failed'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('save-trip-button')),
    );
    expect(saveButton.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing preserves the existing trip identity', (tester) async {
    final repository = MockTripRepository();
    final existing = Trip(
      id: 'existing-trip-id',
      userId: '22222222-2222-4222-8222-222222222222',
      title: 'Original title',
      startDate: DateTime(2042, 1, 1),
      endDate: DateTime(2042, 1, 2),
      createdAt: DateTime.utc(2041, 12, 1),
      updatedAt: DateTime.utc(2041, 12, 1),
    );
    await repository.addTrip(existing);
    final controller = TripController(
      repository,
      MockJournalRepository(),
      MockTripCoverStorage(),
    );
    await controller.loadTrips(existing.userId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          home: TripFormScreen(
            existingTrip: existing,
            userIdProvider: const _UnauthenticatedCurrentUserIdProvider(),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('trip-title-field')),
      'Updated title',
    );
    await tester.tap(find.byKey(const Key('save-trip-button')));
    await tester.pumpAndSettle();

    final updated = await repository.getTrip(existing.id);
    expect(updated?.id, existing.id);
    expect(updated?.userId, existing.userId);
    expect(updated?.title, 'Updated title');
  });

  testWidgets('double-tapping Save starts only one create operation', (
    tester,
  ) async {
    final repository = _DelayedAddTripRepository();
    final controller = TripController(
      repository,
      MockJournalRepository(),
      MockTripCoverStorage(),
    );
    final userProvider = _RecordingCurrentUserIdProvider();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(home: TripFormScreen(userIdProvider: userProvider)),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('trip-title-field')),
      'Only one trip',
    );

    await tester.tap(find.byKey(const Key('save-trip-button')));
    await tester.tap(find.byKey(const Key('save-trip-button')));
    await tester.pump();
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('save-trip-button')),
    );
    final providerCallsBeforeCompletion = userProvider.requireCalls;
    final addCallsBeforeCompletion = repository.addCalls;
    final saveWasDisabled = saveButton.onPressed == null;
    repository.gate.complete();
    await tester.pumpAndSettle();

    expect(providerCallsBeforeCompletion, 1);
    expect(addCallsBeforeCompletion, 1);
    expect(saveWasDisabled, isTrue);
  });

  testWidgets('a delayed save failure does not setState after form disposal', (
    tester,
  ) async {
    final repository = _DelayedAddTripRepository(failAfterDelay: true);
    final controller = TripController(
      repository,
      MockJournalRepository(),
      MockTripCoverStorage(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const TripFormScreen(
                    userIdProvider: _FixedCurrentUserIdProvider(
                      '11111111-1111-4111-8111-111111111111',
                    ),
                  ),
                ),
              ),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('trip-title-field')),
      'Disposed save',
    );
    await tester.tap(find.byKey(const Key('save-trip-button')));
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    repository.gate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

final class _FixedCurrentUserIdProvider implements CurrentUserIdProvider {
  const _FixedCurrentUserIdProvider(this.userId);

  final String userId;

  @override
  String requireUserId() => userId;
}

final class _UnauthenticatedCurrentUserIdProvider
    implements CurrentUserIdProvider {
  const _UnauthenticatedCurrentUserIdProvider();

  @override
  String requireUserId() => throw const UnauthenticatedTripUserException();
}

final class _UnexpectedErrorCurrentUserIdProvider
    implements CurrentUserIdProvider {
  const _UnexpectedErrorCurrentUserIdProvider();

  @override
  String requireUserId() => throw StateError('identity provider failed');
}

final class _RecordingCurrentUserIdProvider implements CurrentUserIdProvider {
  int requireCalls = 0;

  @override
  String requireUserId() {
    requireCalls++;
    return '11111111-1111-4111-8111-111111111111';
  }
}

final class _DelayedAddTripRepository extends MockTripRepository {
  _DelayedAddTripRepository({this.failAfterDelay = false});

  final bool failAfterDelay;
  final Completer<void> gate = Completer<void>();
  int addCalls = 0;

  @override
  Future<void> addTrip(Trip trip) async {
    addCalls++;
    await gate.future;
    if (failAfterDelay) throw StateError('delayed add failed');
    await super.addTrip(trip);
  }
}
