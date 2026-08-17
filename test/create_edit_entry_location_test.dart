import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/journal_repository.dart';
import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/features/health/health_data_source.dart';
import 'package:tripjournal/features/journal/ai/daily_advice_service.dart';
import 'package:tripjournal/features/journal/controller/journal_controller.dart';
import 'package:tripjournal/features/journal/screens/create_edit_entry_screen.dart';
import 'package:tripjournal/features/location/place_search_service.dart';
import 'package:tripjournal/models/geo_tag.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/mood.dart';

void main() {
  const originalLocation = GeoTag(
    latitude: 35.0116,
    longitude: 135.7681,
    placeName: 'Gion',
    formattedAddress: 'Gion, Kyoto, Japan',
    placeId: 'gion',
  );
  const pickedLocation = GeoTag(
    latitude: 34.994856,
    longitude: 135.785046,
    placeName: 'Kiyomizu-dera',
    formattedAddress: '1 Chome-294 Kiyomizu, Kyoto, Japan',
    placeId: 'kiyomizu',
  );

  testWidgets('Add changes the draft only after the picker is confirmed', (
    tester,
  ) async {
    _useLargeView(tester);
    final service = _FakePlaceSearchService(reverseResult: pickedLocation);

    await _pumpEditor(tester, service: service);

    expect(find.text('No location added.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-location-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake-location-pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-picker-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('No location added.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-location-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake-location-pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-picker-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Kiyomizu-dera'), findsOneWidget);
    expect(find.text('1 Chome-294 Kiyomizu, Kyoto, Japan'), findsOneWidget);
    expect(find.byKey(const Key('change-location-button')), findsOneWidget);
    expect(find.byKey(const Key('remove-location-button')), findsOneWidget);
  });

  testWidgets('Change starts from the current place and applies confirmation', (
    tester,
  ) async {
    _useLargeView(tester);
    final service = _FakePlaceSearchService(reverseResult: pickedLocation);

    await _pumpEditor(
      tester,
      service: service,
      existingEntry: _entry(location: originalLocation),
    );

    await tester.tap(find.byKey(const Key('change-location-button')));
    await tester.pumpAndSettle();

    expect(find.text('Map selection: Gion'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fake-location-pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-picker-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Kiyomizu-dera'), findsOneWidget);
    expect(find.text('Gion'), findsNothing);
  });

  testWidgets('Remove then Save persists an edited entry without a location', (
    tester,
  ) async {
    _useLargeView(tester);
    final existing = _entry(location: originalLocation);
    final repository = _RecordingJournalRepository(entries: [existing]);

    await _pumpEditor(
      tester,
      service: _FakePlaceSearchService(reverseResult: pickedLocation),
      existingEntry: existing,
      repository: repository,
    );

    await tester.tap(find.byKey(const Key('remove-location-button')));
    await tester.pump();
    expect(find.text('No location added.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-confirm-confirm')));
    await tester.pumpAndSettle();

    expect(repository.updates, isNotEmpty);
    expect(repository.updates.first.id, existing.id);
    expect(repository.updates.first.createdAt, existing.createdAt);
    expect(repository.updates.first.location, isNull);
  });

  testWidgets('Save persists a confirmed location on a new entry', (
    tester,
  ) async {
    _useLargeView(tester);
    final repository = _RecordingJournalRepository();

    await _pumpEditor(
      tester,
      service: _FakePlaceSearchService(reverseResult: pickedLocation),
      repository: repository,
    );
    await tester.enterText(
      find.byKey(const Key('entry-title-field')),
      'Located day',
    );
    await tester.tap(find.byKey(const Key('add-location-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake-location-pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-picker-confirm')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-confirm-confirm')));
    await tester.pumpAndSettle();

    expect(repository.adds, hasLength(1));
    final saved = repository.adds.single;
    expect(saved.location?.placeId, 'kiyomizu');
    expect(saved.location?.placeName, 'Kiyomizu-dera');
    expect(saved.location?.formattedAddress, contains('Kyoto'));
    expect(saved.location?.latitude, 34.994856);
    expect(saved.location?.longitude, 135.785046);
  });

  testWidgets('rapid Save taps issue one create with one stable UUID pair', (
    tester,
  ) async {
    _useLargeView(tester);
    final repository = _GatedJournalRepository();

    await _pumpEditor(
      tester,
      service: _FakePlaceSearchService(reverseResult: pickedLocation),
      repository: repository,
    );
    await tester.enterText(
      find.byKey(const Key('entry-title-field')),
      'One save only',
    );

    final saveButton = find.byKey(const Key('save-entry-button'));
    final pressSave = tester.widget<FilledButton>(saveButton).onPressed!;
    pressSave();
    pressSave();
    await tester.pumpAndSettle();

    expect(find.text('Save changes to this entry?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-confirm-confirm')));
    await tester.pump();

    expect(repository.addCalls, 1);
    expect(repository.adds, hasLength(1));
    final draft = repository.adds.single;
    expect(draft.id, matches(_uuidPattern));
    expect(draft.healthLog?.id, matches(_uuidPattern));
    expect(draft.healthLog?.entryId, draft.id);
    expect(
      tester.widget<FilledButton>(saveButton).onPressed,
      isNull,
      reason: 'Save stays disabled for the whole confirmation/write window.',
    );

    repository.addGate.complete();
    await tester.pumpAndSettle();

    expect(repository.addCalls, 1);
    expect(repository.updates.every((entry) => entry.id == draft.id), isTrue);
  });

  testWidgets(
    'confirmed save blocks draft mutation and back until write ends',
    (tester) async {
      _useLargeView(tester);
      final repository = _GatedJournalRepository();
      final service = _FakePlaceSearchService(reverseResult: pickedLocation);

      await _pumpEditorRoute(tester, service: service, repository: repository);
      await tester.enterText(
        find.byKey(const Key('entry-title-field')),
        'Blocked write',
      );
      await tester.tap(find.byKey(const Key('add-location-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fake-location-pin')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('place-picker-confirm')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-confirm-confirm')));
      await tester.pump();
      expect(repository.addCalls, 1);

      await tester.tap(
        find.byKey(const Key('remove-location-button')),
        warnIfMissed: false,
      );
      await tester.pageBack();
      await tester.pump();

      repository.addGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Kiyomizu-dera'), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit entry'), findsOneWidget);
      expect(repository.addCalls, 1);
    },
  );

  test(
    'MockJournalRepository retains location through existing CRUD',
    () async {
      final repository = MockJournalRepository();
      final added = _entry(id: 'location-crud', location: originalLocation);

      await repository.addEntry(added);
      expect((await repository.getEntry(added.id))?.location?.placeId, 'gion');

      await repository.updateEntry(added.copyWith(location: pickedLocation));
      final updated = await repository.getEntry(added.id);
      expect(updated?.location?.placeName, 'Kiyomizu-dera');
      expect(updated?.location?.latitude, 34.994856);
    },
  );
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

void _useLargeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required PlaceSearchService service,
  JournalEntry? existingEntry,
  JournalRepository? repository,
}) async {
  final controller = JournalController(
    repository ?? _RecordingJournalRepository(),
    _FakeDailyAdviceService(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [journalControllerProvider.overrideWith((ref) => controller)],
      child: MaterialApp(
        home: CreateEditEntryScreen(
          existingEntry: existingEntry,
          tripId: 'trip-001',
          healthDataSource: _FakeHealthDataSource(),
          placeSearchService: service,
          placePickerMapBuilder: _fakeLocationMap,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpEditorRoute(
  WidgetTester tester, {
  required PlaceSearchService service,
  required JournalRepository repository,
}) async {
  final controller = JournalController(repository, _FakeDailyAdviceService());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [journalControllerProvider.overrideWith((ref) => controller)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-editor'),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateEditEntryScreen(
                    tripId: 'trip-001',
                    healthDataSource: _FakeHealthDataSource(),
                    placeSearchService: service,
                    placePickerMapBuilder: _fakeLocationMap,
                  ),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-editor')));
  await tester.pumpAndSettle();
}

Widget _fakeLocationMap({
  required GeoTag? selectedLocation,
  required ValueChanged<GeoTag> onPinDragged,
}) => Center(
  child: TextButton(
    key: const Key('fake-location-pin'),
    onPressed: () =>
        onPinDragged(const GeoTag(latitude: 34.994856, longitude: 135.785046)),
    child: Text('Map selection: ${selectedLocation?.placeName ?? 'none'}'),
  ),
);

JournalEntry _entry({String id = 'entry-location-test', GeoTag? location}) =>
    JournalEntry(
      id: id,
      tripId: 'trip-001',
      title: 'A located entry',
      body: 'Body',
      mood: Mood.happy,
      photoPaths: const [],
      location: location,
      createdAt: DateTime(2026, 4, 10, 12),
      updatedAt: DateTime(2026, 4, 10, 12),
      healthLog: HealthLog(
        id: 'health-$id',
        entryId: id,
        steps: 1200,
        caloriesEaten: 0,
        meals: const [],
      ),
    );

class _FakePlaceSearchService implements PlaceSearchService {
  _FakePlaceSearchService({required this.reverseResult});

  final GeoTag reverseResult;

  @override
  Future<List<PlaceSuggestion>> search(String query) async => const [];

  @override
  Future<GeoTag> resolvePlace(String placeId) async => reverseResult;

  @override
  Future<GeoTag> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async => reverseResult;
}

class _FakeHealthDataSource implements HealthDataSource {
  @override
  Future<int?> getCaloriesBurnedForDate(DateTime date) async => null;

  @override
  Future<int?> getStepsForDate(DateTime date) async => null;

  @override
  Future<bool> hasPermissions() async => false;

  @override
  Future<bool> requestPermissions() async => false;
}

class _FakeDailyAdviceService implements DailyAdviceService {
  @override
  Future<String> adviceFor({
    required List<Meal> meals,
    required int? steps,
    required Mood mood,
    int? caloriesEaten,
    int? caloriesBurned,
  }) async => 'A gentle suggestion.';
}

class _RecordingJournalRepository implements JournalRepository {
  _RecordingJournalRepository({List<JournalEntry> entries = const []})
    : entries = List.of(entries);

  final List<JournalEntry> entries;
  final List<JournalEntry> adds = [];
  final List<JournalEntry> updates = [];

  @override
  Future<void> addEntry(JournalEntry entry) async {
    adds.add(entry);
    entries.add(entry);
  }

  @override
  Future<void> deleteEntry(String id) async {
    entries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<List<JournalEntry>> getEntries(String tripId) async =>
      entries.where((entry) => entry.tripId == tripId).toList();

  @override
  Future<JournalEntry?> getEntry(String id) async {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Future<void> updateEntry(JournalEntry entry) async {
    updates.add(entry);
    final index = entries.indexWhere((existing) => existing.id == entry.id);
    if (index >= 0) entries[index] = entry;
  }
}

class _GatedJournalRepository extends _RecordingJournalRepository {
  final addGate = Completer<void>();
  int addCalls = 0;

  @override
  Future<void> addEntry(JournalEntry entry) async {
    addCalls++;
    adds.add(entry);
    await addGate.future;
    entries.add(entry);
  }
}
