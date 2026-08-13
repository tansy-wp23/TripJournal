import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/journal_repository.dart';
import 'package:tripjournal/features/journal/ai/daily_advice_locator.dart';
import 'package:tripjournal/features/journal/controller/journal_controller.dart';
import 'package:tripjournal/features/settings/settings_controller.dart';
import 'package:tripjournal/features/settings/settings_preferences.dart';
import 'package:tripjournal/features/settings/settings_providers.dart';
import 'package:tripjournal/features/trip/screens/trip_photo_slideshow_screen.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/mood.dart';

/// A meal photo on day 1 and an ordinary trip photo on day 2, so the food
/// photo comes *first* in the trip's photo list. Hiding it therefore shifts
/// every later index — which is exactly the case a position-based carousel
/// tap would get wrong.
JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  List<String> photoPaths = const [],
  String? mealPhotoPath,
}) {
  return JournalEntry(
    id: id,
    tripId: 'trip-001',
    title: 'title-$id',
    body: 'body',
    mood: Mood.neutral,
    photoPaths: photoPaths,
    createdAt: createdAt,
    updatedAt: createdAt,
    healthLog: mealPhotoPath == null
        ? null
        : HealthLog(
            id: 'hl-$id',
            entryId: id,
            steps: 1000,
            caloriesEaten: 600,
            meals: [
              Meal(
                id: 'meal-$id',
                name: 'Nasi lemak',
                calories: 600,
                mealType: MealType.breakfast,
                photoPath: mealPhotoPath,
              ),
            ],
          ),
  );
}

class _PhotoSeedJournalRepository implements JournalRepository {
  final _entries = [
    _entry(
      id: 'entry-food',
      createdAt: DateTime(2026, 4, 10, 9),
      mealPhotoPath: 'assets/mock/nasi-lemak.jpg',
    ),
    _entry(
      id: 'entry-trip',
      createdAt: DateTime(2026, 4, 11, 9),
      photoPaths: const ['assets/mock/gion.jpg'],
    ),
  ];

  @override
  Future<List<JournalEntry>> getEntries(String tripId) async => _entries;

  @override
  Future<JournalEntry?> getEntry(String id) async =>
      _entries.where((e) => e.id == id).firstOrNull;

  @override
  Future<void> addEntry(JournalEntry entry) async => _entries.add(entry);

  @override
  Future<void> updateEntry(JournalEntry entry) async {}

  @override
  Future<void> deleteEntry(String id) async {}
}

class _InMemorySettingsStore implements SettingsStore {
  _InMemorySettingsStore(this._preferences);

  SettingsPreferences _preferences;
  int saveCount = 0;

  @override
  Future<SettingsPreferences> load() async => _preferences;

  @override
  Future<void> save(SettingsPreferences preferences) async {
    _preferences = preferences;
    saveCount++;
  }

  SettingsPreferences get saved => _preferences;
}

Future<void> _pumpTripView(
  WidgetTester tester, {
  required SettingsStore settingsStore,
  String tripId = 'trip-001',
}) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(settingsStore),
      journalControllerProvider.overrideWith(
        (ref) => JournalController(_PhotoSeedJournalRepository(), dailyAdviceService),
      ),
    ],
    child: MaterialApp(home: TripViewScreen(tripId: tripId)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the carousel shows food photos by default', (tester) async {
    await _pumpTripView(
      tester,
      settingsStore: _InMemorySettingsStore(SettingsPreferences.defaults),
    );

    expect(find.byKey(const Key('trip-food-photos-toggle')), findsOneWidget);
    expect(find.text('Food photos shown'), findsOneWidget);
    expect(find.byKey(const Key('trip-carousel-dot-0')), findsOneWidget);
    expect(find.byKey(const Key('trip-carousel-dot-1')), findsOneWidget);
  });

  testWidgets('toggling off drops food photos from the carousel only', (tester) async {
    final store = _InMemorySettingsStore(SettingsPreferences.defaults);
    await _pumpTripView(tester, settingsStore: store);

    await tester.tap(find.byKey(const Key('trip-food-photos-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Food photos hidden'), findsOneWidget);
    // One page left in the carousel...
    expect(find.byKey(const Key('trip-carousel-dot-0')), findsOneWidget);
    expect(find.byKey(const Key('trip-carousel-dot-1')), findsNothing);
    // ...but both day strips are untouched, so nothing becomes unreachable.
    expect(find.byKey(const Key('day-photo-1-0')), findsOneWidget);
    expect(find.byKey(const Key('day-photo-2-0')), findsOneWidget);
  });

  testWidgets('with food hidden, the carousel still opens the slideshow on the right photo', (
    tester,
  ) async {
    // The food photo is trip photo #1, so once it is hidden the carousel's
    // first page is trip photo #2. A position-based tap would open #1.
    final store = _InMemorySettingsStore(
      SettingsPreferences.defaults.copyWith(showFoodPhotosInCarousel: false),
    );
    await _pumpTripView(tester, settingsStore: store);

    await tester.tap(find.byKey(const Key('trip-carousel-page-0')));
    await tester.pumpAndSettle();

    final slideshow = tester.widget<TripPhotoSlideshowScreen>(
      find.byType(TripPhotoSlideshowScreen),
    );
    expect(slideshow.initialIndex, 1);
    // The slideshow always carries the whole trip, food photos included, so
    // swiping back reaches the hidden one.
    expect(slideshow.photos.length, 2);
  });

  testWidgets('the day strip and slideshow keep showing food photos when the toggle is off', (
    tester,
  ) async {
    final store = _InMemorySettingsStore(
      SettingsPreferences.defaults.copyWith(showFoodPhotosInCarousel: false),
    );
    await _pumpTripView(tester, settingsStore: store);

    await tester.tap(find.byKey(const Key('day-photo-1-0')));
    await tester.pumpAndSettle();

    final slideshow = tester.widget<TripPhotoSlideshowScreen>(
      find.byType(TripPhotoSlideshowScreen),
    );
    expect(slideshow.initialIndex, 0);
    expect(find.text('Nasi lemak'), findsOneWidget);
  });

  testWidgets('the toggle is hidden for a trip with no food photos', (tester) async {
    // trip-003 is seeded with no entries at all.
    await _pumpTripView(
      tester,
      settingsStore: _InMemorySettingsStore(SettingsPreferences.defaults),
      tripId: 'trip-003',
    );

    expect(find.byKey(const Key('trip-food-photos-toggle')), findsNothing);
  });

  testWidgets('the choice is persisted, not just held in memory', (tester) async {
    final store = _InMemorySettingsStore(SettingsPreferences.defaults);
    await _pumpTripView(tester, settingsStore: store);

    await tester.tap(find.byKey(const Key('trip-food-photos-toggle')));
    await tester.pumpAndSettle();

    expect(store.saveCount, greaterThan(0));
    expect(store.saved.showFoodPhotosInCarousel, isFalse);
  });
}
