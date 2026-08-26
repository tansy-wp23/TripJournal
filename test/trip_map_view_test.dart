import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripjournal/features/trip/map/trip_map_model.dart';
import 'package:tripjournal/features/trip/map/trip_map_view.dart';
import 'package:tripjournal/models/geo_tag.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

void main() {
  final tripStart = DateTime(2026, 8, 15);
  final tripEnd = tripStart.add(const Duration(days: 30));

  JournalEntry entry({
    required String id,
    required DateTime createdAt,
    GeoTag? location,
    String title = '',
    List<String> photos = const [],
  }) => JournalEntry(
    id: id,
    tripId: 'trip-1',
    title: title,
    body: '',
    mood: Mood.excited,
    photoPaths: photos,
    location: location,
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  Widget view({
    required List<JournalEntry> entries,
    ValueChanged<JournalEntry>? onOpenEntry,
    VoidCallback? onAddLocation,
    TripMapBuilder? mapBuilder,
    double textScale = 1,
  }) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: TripMapView(
        entries: entries,
        tripStartDate: tripStart,
        tripEndDate: tripEnd,
        mapBuilder: mapBuilder ?? _fakeMapSurface,
        onOpenEntry: onOpenEntry ?? (_) {},
        onAddLocation: onAddLocation ?? () {},
      ),
    ),
  );

  testWidgets('empty state offers an action to add a location', (tester) async {
    var addLocationCalls = 0;

    await tester.pumpWidget(
      view(
        entries: [entry(id: 'without-location', createdAt: tripStart)],
        onAddLocation: () => addLocationCalls++,
      ),
    );

    expect(find.text('0 mapped · 1 without location'), findsOneWidget);
    expect(find.text('No locations yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('trip-map-add-location')));
    expect(addLocationCalls, 1);
  });

  testWidgets('shows map counts and filters visible markers by day', (
    tester,
  ) async {
    await tester.pumpWidget(
      view(
        entries: [
          entry(
            id: 'day-1',
            title: 'Day one',
            createdAt: tripStart,
            location: const GeoTag(latitude: 1, longitude: 2, placeId: 'one'),
          ),
          entry(
            id: 'day-2',
            title: 'Day two',
            createdAt: tripStart.add(const Duration(days: 1)),
            location: const GeoTag(latitude: 3, longitude: 4, placeId: 'two'),
          ),
          entry(id: 'unmapped', createdAt: tripStart),
        ],
      ),
    );

    expect(find.text('2 mapped · 1 without location'), findsOneWidget);
    expect(
      find.text('Lines show journal order only — not roads or navigation.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('trip-map-day-all')), findsOneWidget);
    expect(find.byKey(const Key('trip-map-day-1')), findsOneWidget);
    expect(find.byKey(const Key('trip-map-day-2')), findsOneWidget);
    expect(
      find.byKey(const Key('fake-map-place:one:1.000000,2.000000')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('fake-map-place:two:3.000000,4.000000')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('trip-map-day-2')));
    await tester.pump();

    expect(
      find.byKey(const Key('fake-map-place:one:1.000000,2.000000')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('fake-map-place:two:3.000000,4.000000')),
      findsOneWidget,
    );
  });

  testWidgets(
    'selecting a duplicate marker previews and opens every related entry',
    (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        view(
          entries: [
            entry(
              id: 'first',
              title: 'First visit',
              createdAt: tripStart,
              photos: const ['assets/mock/gion_evening.jpg'],
              location: const GeoTag(
                latitude: 35,
                longitude: 135,
                placeId: 'shrine',
                placeName: 'Fushimi Inari',
              ),
            ),
            entry(
              id: 'second',
              title: 'Second visit',
              createdAt: tripStart.add(const Duration(hours: 2)),
              location: const GeoTag(
                latitude: 35,
                longitude: 135,
                placeId: 'shrine',
                placeName: 'Fushimi Inari',
              ),
            ),
          ],
          onOpenEntry: (entry) => opened.add(entry.id),
        ),
      );

      await tester.tap(
        find.byKey(const Key('fake-map-place:shrine:35.000000,135.000000')),
      );
      await tester.pumpAndSettle();

      expect(find.text('First visit'), findsOneWidget);
      expect(find.text('Second visit'), findsOneWidget);
      expect(find.text('Fushimi Inari · Excited'), findsNWidgets(2));
      expect(find.byKey(const Key('trip-map-preview-first')), findsOneWidget);
      expect(find.byKey(const Key('trip-map-preview-second')), findsOneWidget);

      await tester.tap(find.byKey(const Key('trip-map-preview-second')));
      expect(opened, ['second']);
    },
  );

  testWidgets('fallback lists visible groups and opens selected entries', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      view(
        entries: [
          entry(
            id: 'mapped',
            title: 'Map fallback',
            createdAt: tripStart,
            location: const GeoTag(
              latitude: 1,
              longitude: 2,
              placeName: 'Fallback place',
            ),
          ),
        ],
        onOpenEntry: (entry) => opened.add(entry.id),
        mapBuilder: ({required model, required onSelected}) =>
            TripMapUnavailableSurface(model: model, onSelected: onSelected),
      ),
    );

    expect(find.text('Map unavailable'), findsOneWidget);
    expect(
      find.text('Lines show journal order only — not roads or navigation.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('trip-map-fallback-coord:1.000000,2.000000')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('trip-map-preview-mapped')));
    expect(opened, ['mapped']);
  });

  testWidgets(
    'selected day keeps cumulative markers without a previous-day warning',
    (tester) async {
      await tester.pumpWidget(
        view(
          entries: [
            entry(
              id: 'day-1',
              createdAt: tripStart,
              location: const GeoTag(latitude: 1, longitude: 2),
            ),
            entry(
              id: 'day-3',
              createdAt: tripStart.add(const Duration(days: 2)),
              location: const GeoTag(latitude: 3, longitude: 4),
            ),
          ],
        ),
      );

      expect(find.text('Previous day has no mapped entry'), findsNothing);

      await tester.tap(find.byKey(const Key('trip-map-day-3')));
      await tester.pump();

      expect(find.text('Previous day has no mapped entry'), findsNothing);
      expect(
        find.byKey(const Key('fake-map-coord:3.000000,4.000000')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('fake-map-coord:1.000000,2.000000')),
        findsOneWidget,
      );
    },
  );

  testWidgets('removing a selected day location returns to all mapped days', (
    tester,
  ) async {
    final dayOne = entry(
      id: 'day-1',
      createdAt: tripStart,
      location: const GeoTag(latitude: 1, longitude: 2),
    );
    final dayTwo = entry(
      id: 'day-2',
      createdAt: tripStart.add(const Duration(days: 1)),
      location: const GeoTag(latitude: 3, longitude: 4),
    );
    await tester.pumpWidget(view(entries: [dayOne, dayTwo]));

    await tester.tap(find.byKey(const Key('trip-map-day-2')));
    await tester.pump();
    expect(
      find.byKey(const Key('fake-map-coord:3.000000,4.000000')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      view(entries: [dayOne, dayTwo.copyWith(clearLocation: true)]),
    );
    await tester.pump();

    expect(find.text('No locations yet'), findsNothing);
    expect(find.byKey(const Key('trip-map-day-all')), findsOneWidget);
    expect(
      find.byKey(const Key('fake-map-coord:1.000000,2.000000')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('trip-map-day-all')))
          .selected,
      isTrue,
    );
  });

  testWidgets('fallback lists adjacent-day connectors with endpoint labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      view(
        entries: [
          entry(
            id: 'day-1',
            createdAt: tripStart,
            location: const GeoTag(
              latitude: 1,
              longitude: 2,
              placeName: 'Trailhead',
            ),
          ),
          entry(
            id: 'day-2',
            createdAt: tripStart.add(const Duration(days: 1)),
            location: const GeoTag(latitude: 3, longitude: 4),
          ),
        ],
        mapBuilder: ({required model, required onSelected}) =>
            TripMapUnavailableSurface(model: model, onSelected: onSelected),
      ),
    );

    expect(find.text('Day 1 last stop → Day 2 first stop'), findsOneWidget);
    expect(find.text('Trailhead → 3.00000, 4.00000'), findsOneWidget);
    expect(
      find.byKey(const Key('trip-map-fallback-connector-day-1-to-day-2')),
      findsOneWidget,
    );
  });

  testWidgets('remains usable at narrow width with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      view(
        entries: [
          entry(
            id: 'scaled',
            title: 'A long journal title that can wrap at larger text sizes',
            createdAt: tripStart,
            location: const GeoTag(
              latitude: 1,
              longitude: 2,
              placeName: 'A location name that can also wrap when needed',
            ),
          ),
        ],
        textScale: 1.3,
      ),
    );
    await tester.tap(find.byKey(const Key('fake-map-coord:1.000000,2.000000')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-map-preview-scaled')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      view(
        entries: [entry(id: 'empty', createdAt: tripStart)],
        textScale: 1.3,
      ),
    );

    expect(find.byKey(const Key('trip-map-add-location')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _fakeMapSurface({
  required TripMapModel model,
  required ValueChanged<TripMapMarkerGroup> onSelected,
}) => ListView(
  key: const Key('fake-map-surface'),
  children: [
    for (final group in model.groups)
      TextButton(
        key: Key('fake-map-${group.key}'),
        onPressed: () => onSelected(group),
        child: Text(group.key),
      ),
  ],
);
