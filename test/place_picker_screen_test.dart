import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:tripjournal/features/location/google_place_picker_map.dart';
import 'package:tripjournal/features/location/current_location_service.dart';
import 'package:tripjournal/features/location/place_picker_screen.dart';
import 'package:tripjournal/features/location/place_search_service.dart';
import 'package:tripjournal/models/geo_tag.dart';

void main() {
  const initialLocation = GeoTag(
    latitude: 35.0116,
    longitude: 135.7681,
    placeName: 'Gion',
    formattedAddress: 'Gion, Kyoto, Japan',
    placeId: 'gion',
  );

  testWidgets('explains when location is saved and how lookup is processed', (
    tester,
  ) async {
    await tester.pumpWidget(_picker(service: _FakePlaceSearchService()));

    expect(
      find.text(
        'Location is saved only when you confirm. Place lookup is processed '
        'securely through TripJournal.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('search runs only on submit and ignores a blank query', (
    tester,
  ) async {
    final service = _FakePlaceSearchService()
      ..searchResults = const [
        PlaceSuggestion(
          placeId: 'kiyomizu',
          primaryText: 'Kiyomizu-dera',
          secondaryText: 'Kyoto, Japan',
        ),
      ];

    await tester.pumpWidget(_picker(service: service));

    await tester.enterText(
      find.byKey(const Key('place-search-field')),
      'Kiyomizu',
    );
    await tester.pump();
    expect(service.searchQueries, isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(service.searchQueries, ['Kiyomizu']);
    expect(find.byKey(const Key('place-suggestion-kiyomizu')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('place-search-field')), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(service.searchQueries, ['Kiyomizu']);
  });

  testWidgets('resolved search result is returned only after confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const resolved = GeoTag(
      latitude: 34.994856,
      longitude: 135.785046,
      placeName: 'Kiyomizu-dera',
      formattedAddress: '1 Chome-294 Kiyomizu, Kyoto, Japan',
      placeId: 'kiyomizu',
    );
    final service = _FakePlaceSearchService()
      ..searchResults = const [
        PlaceSuggestion(
          placeId: 'kiyomizu',
          primaryText: 'Kiyomizu-dera',
          secondaryText: 'Kyoto, Japan',
        ),
      ]
      ..resolvedPlaces['kiyomizu'] = resolved;
    GeoTag? returned;
    var didReturn = false;

    await _openPicker(
      tester,
      service: service,
      onResult: (result) {
        returned = result;
        didReturn = true;
      },
    );

    await tester.enterText(
      find.byKey(const Key('place-search-field')),
      'Kiyomizu',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-suggestion-kiyomizu')));
    await tester.pumpAndSettle();

    expect(service.resolvedPlaceIds, ['kiyomizu']);
    expect(
      find.descendant(
        of: find.byKey(const Key('place-picker-selection')),
        matching: find.text('Kiyomizu-dera'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 Chome-294 Kiyomizu, Kyoto, Japan'), findsOneWidget);
    expect(didReturn, isFalse);

    await tester.tap(find.byKey(const Key('place-picker-confirm')));
    await tester.pumpAndSettle();

    expect(didReturn, isTrue);
    expect(returned, same(resolved));
  });

  testWidgets('cancel returns null and does not confirm the initial location', (
    tester,
  ) async {
    GeoTag? returned = initialLocation;
    var didReturn = false;

    await _openPicker(
      tester,
      service: _FakePlaceSearchService(),
      initialLocation: initialLocation,
      onResult: (result) {
        returned = result;
        didReturn = true;
      },
    );

    await tester.tap(find.byKey(const Key('place-picker-cancel')));
    await tester.pumpAndSettle();

    expect(didReturn, isTrue);
    expect(returned, isNull);
  });

  testWidgets('failed search keeps selection and retries the same query', (
    tester,
  ) async {
    final service = _FakePlaceSearchService()
      ..searchError = const PlaceSearchException('Search unavailable.');

    await tester.pumpWidget(
      _picker(service: service, initialLocation: initialLocation),
    );
    await tester.enterText(
      find.byKey(const Key('place-search-field')),
      'Arashiyama',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Search unavailable.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('place-picker-selection')),
        matching: find.text('Gion'),
      ),
      findsOneWidget,
    );

    service
      ..searchError = null
      ..searchResults = const [
        PlaceSuggestion(placeId: 'arashiyama', primaryText: 'Arashiyama'),
      ];
    await tester.tap(find.byKey(const Key('place-picker-retry')));
    await tester.pumpAndSettle();

    expect(service.searchQueries, ['Arashiyama', 'Arashiyama']);
    expect(
      find.byKey(const Key('place-suggestion-arashiyama')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('place-picker-selection')),
        matching: find.text('Gion'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('failed result resolution keeps selection and is retryable', (
    tester,
  ) async {
    const resolved = GeoTag(
      latitude: 35.03937,
      longitude: 135.72924,
      placeName: 'Kinkaku-ji',
      formattedAddress: '1 Kinkakujicho, Kyoto, Japan',
      placeId: 'kinkakuji',
    );
    final service = _FakePlaceSearchService()
      ..searchResults = const [
        PlaceSuggestion(placeId: 'kinkakuji', primaryText: 'Kinkaku-ji'),
      ]
      ..resolveError = const PlaceSearchException('Place unavailable.');

    await tester.pumpWidget(
      _picker(service: service, initialLocation: initialLocation),
    );
    await tester.enterText(
      find.byKey(const Key('place-search-field')),
      'Kinkaku-ji',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-suggestion-kinkakuji')));
    await tester.pumpAndSettle();

    expect(find.text('Place unavailable.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('place-picker-selection')),
        matching: find.text('Gion'),
      ),
      findsOneWidget,
    );

    service
      ..resolveError = null
      ..resolvedPlaces['kinkakuji'] = resolved;
    await tester.tap(find.byKey(const Key('place-picker-retry')));
    await tester.pumpAndSettle();

    expect(service.resolvedPlaceIds, ['kinkakuji', 'kinkakuji']);
    expect(find.text('Kinkaku-ji'), findsWidgets);
    expect(find.text('1 Kinkakujicho, Kyoto, Japan'), findsOneWidget);
  });

  testWidgets(
    'reverse failure keeps a six-decimal coordinate selection confirmable',
    (tester) async {
      final service = _FakePlaceSearchService()
        ..reverseError = const PlaceSearchException('Address unavailable.');
      GeoTag? returned;

      await _openPicker(
        tester,
        service: service,
        mapBuilder: _fakeMapBuilder,
        onResult: (result) => returned = result,
      );
      await tester.tap(find.byKey(const Key('fake-drag-pin')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('place-picker-selection')),
          matching: find.text('3.141593, 101.686900'),
        ),
        findsOneWidget,
      );
      expect(find.text('Address unavailable.'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('place-picker-confirm'), skipOffstage: false),
      );
      await tester.pump();
      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('place-picker-confirm')),
      );
      expect(confirm.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('place-picker-confirm')));
      await tester.pumpAndSettle();

      expect(returned?.latitude, closeTo(3.14159265, 0.000000001));
      expect(returned?.longitude, closeTo(101.6869, 0.000000001));
      expect(returned?.placeName, '3.141593, 101.686900');
      expect(returned?.formattedAddress, isNull);
      expect(returned?.placeId, isNull);
    },
  );

  testWidgets('reverse failure retry replaces the coordinate-only label', (
    tester,
  ) async {
    const reverseResult = GeoTag(
      latitude: 3.14159265,
      longitude: 101.6869,
      placeName: 'Central Market',
      formattedAddress: 'Kuala Lumpur City Centre',
      placeId: 'central-market',
    );
    final service = _FakePlaceSearchService()
      ..reverseError = const PlaceSearchException('Address unavailable.');

    await tester.pumpWidget(
      _picker(service: service, mapBuilder: _fakeMapBuilder),
    );
    await tester.tap(find.byKey(const Key('fake-drag-pin')));
    await tester.pumpAndSettle();

    service
      ..reverseError = null
      ..reverseResult = reverseResult;
    await tester.tap(find.byKey(const Key('place-picker-retry')));
    await tester.pumpAndSettle();

    expect(service.reverseCalls, hasLength(2));
    expect(
      find.descendant(
        of: find.byKey(const Key('place-picker-selection')),
        matching: find.text('Central Market'),
      ),
      findsOneWidget,
    );
    expect(find.text('Kuala Lumpur City Centre'), findsOneWidget);
    expect(find.text('Address unavailable.'), findsNothing);
  });

  testWidgets('dragged coordinate label appears before reverse lookup ends', (
    tester,
  ) async {
    final reverseCompleter = Completer<GeoTag>();
    final service = _FakePlaceSearchService()
      ..reverseCompleter = reverseCompleter;

    await tester.pumpWidget(
      _picker(service: service, mapBuilder: _fakeMapBuilder),
    );
    await tester.tap(find.byKey(const Key('fake-drag-pin')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('place-picker-selection')),
        matching: find.text('3.141593, 101.686900'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('place-picker-confirm')))
          .onPressed,
      isNotNull,
    );

    reverseCompleter.complete(
      const GeoTag(
        latitude: 3.14159265,
        longitude: 101.6869,
        placeName: 'Central Market',
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'current location places a coordinate draft before reverse geocoding',
    (tester) async {
      final reverseCompleter = Completer<GeoTag>();
      final placeService = _FakePlaceSearchService()
        ..reverseCompleter = reverseCompleter;
      final locationService = _FakeCurrentLocationService()
        ..location = const CurrentLocation(
          latitude: 3.139,
          longitude: 101.6869,
          accuracyMeters: 35,
        );

      await tester.pumpWidget(
        _picker(
          service: placeService,
          currentLocationService: locationService,
          mapBuilder: _fakeMapBuilder,
        ),
      );

      expect(locationService.locateCalls, 0);
      await tester.ensureVisible(
        find.byKey(const Key('place-picker-current-location')),
      );
      await tester.tap(find.byKey(const Key('place-picker-current-location')));
      await tester.pump();

      expect(locationService.locateCalls, 1);
      expect(find.text('Accuracy: approximately ±35 m'), findsOneWidget);
      expect(
        find.text(
          'Location accuracy is low. You can move the pin before confirming.',
        ),
        findsNothing,
      );
      expect(placeService.reverseCalls, [
        (latitude: 3.139, longitude: 101.6869),
      ]);
      expect(
        find.descendant(
          of: find.byKey(const Key('place-picker-selection')),
          matching: find.text('3.139000, 101.686900'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('place-picker-confirm')))
            .onPressed,
        isNotNull,
      );

      reverseCompleter.complete(
        const GeoTag(
          latitude: 3.139,
          longitude: 101.6869,
          placeName: 'Merdeka Square',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('place-picker-selection')),
          matching: find.text('Merdeka Square'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('current-location request cannot be started twice', (
    tester,
  ) async {
    final locationCompleter = Completer<CurrentLocation>();
    final locationService = _FakeCurrentLocationService()
      ..locationCompleter = locationCompleter;

    await tester.pumpWidget(
      _picker(
        service: _FakePlaceSearchService(),
        currentLocationService: locationService,
      ),
    );

    await tester.ensureVisible(
      find.byKey(const Key('place-picker-current-location')),
    );
    await tester.tap(find.byKey(const Key('place-picker-current-location')));
    await tester.pump();
    final action = tester.widget<TextButton>(
      find.byKey(const Key('place-picker-current-location')),
    );
    expect(action.onPressed, isNull);
    expect(locationService.locateCalls, 1);

    locationCompleter.complete(
      const CurrentLocation(
        latitude: 3.139,
        longitude: 101.6869,
        accuracyMeters: 250,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find
          .byKey(
            const Key('place-picker-location-accuracy-warning'),
            skipOffstage: false,
          )
          .first,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Accuracy: approximately ±250 m'), findsOneWidget);
    expect(
      find.text(
        'Location accuracy is low. You can move the pin before confirming.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const Key('place-picker-confirm'), skipOffstage: false),
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('place-picker-confirm')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'a failed current-location request keeps the previous selection',
    (tester) async {
      final locationService = _FakeCurrentLocationService()
        ..error = const CurrentLocationException(
          CurrentLocationFailure.permissionDenied,
        );

      await tester.pumpWidget(
        _picker(
          service: _FakePlaceSearchService(),
          currentLocationService: locationService,
          initialLocation: initialLocation,
        ),
      );

      await tester.ensureVisible(
        find.byKey(const Key('place-picker-current-location')),
      );
      await tester.tap(find.byKey(const Key('place-picker-current-location')));
      await tester.pumpAndSettle();

      expect(find.text('Location permission was denied.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('place-picker-selection')),
          matching: find.text('Gion'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('permanent denial offers app settings', (tester) async {
    final locationService = _FakeCurrentLocationService()
      ..error = const CurrentLocationException(
        CurrentLocationFailure.permissionDeniedForever,
      );

    await tester.pumpWidget(
      _picker(
        service: _FakePlaceSearchService(),
        currentLocationService: locationService,
      ),
    );
    await tester.ensureVisible(
      find.byKey(const Key('place-picker-current-location')),
    );
    await tester.tap(find.byKey(const Key('place-picker-current-location')));
    await tester.pumpAndSettle();

    expect(
      find.text('Location permission is permanently denied.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('place-picker-open-app-settings')));
    await tester.pumpAndSettle();
    expect(locationService.openAppSettingsCalls, 1);
  });

  testWidgets('disabled location services offer location settings', (
    tester,
  ) async {
    final locationService = _FakeCurrentLocationService()
      ..error = const CurrentLocationException(
        CurrentLocationFailure.serviceDisabled,
      );

    await tester.pumpWidget(
      _picker(
        service: _FakePlaceSearchService(),
        currentLocationService: locationService,
      ),
    );
    await tester.ensureVisible(
      find.byKey(const Key('place-picker-current-location')),
    );
    await tester.tap(find.byKey(const Key('place-picker-current-location')));
    await tester.pumpAndSettle();

    expect(find.text('Location services are turned off.'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('place-picker-open-location-settings')),
    );
    await tester.pumpAndSettle();
    expect(locationService.openLocationSettingsCalls, 1);
  });

  testWidgets('production map has a deterministic no-key fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildConfiguredGooglePlacePickerMap(
            selectedLocation: initialLocation,
            onPinDragged: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('place-picker-map-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Map preview unavailable'), findsOneWidget);
    expect(find.text('35.011600, 135.768100'), findsOneWidget);
  });

  test('Google picker map disables current-location features', () {
    GeoTag? dragged;
    final map = buildGooglePlacePickerPlatform(
      selectedLocation: initialLocation,
      onPinDragged: (location) => dragged = location,
    );

    expect(map, isA<GoogleMap>());
    final googleMap = map as GoogleMap;
    expect(googleMap.myLocationEnabled, isFalse);
    expect(googleMap.myLocationButtonEnabled, isFalse);
    expect(googleMap.markers.single.draggable, isTrue);

    googleMap.markers.single.onDragEnd!(const LatLng(1.25, 2.5));
    expect(dragged?.latitude, 1.25);
    expect(dragged?.longitude, 2.5);
    expect(dragged?.placeName, isNull);
  });

  test('Google picker map diagnostic keys do not contain coordinates', () {
    final map =
        buildGooglePlacePickerPlatform(
              selectedLocation: initialLocation,
              onPinDragged: (_) {},
            )
            as GoogleMap;

    expect(map.key?.toString(), isNot(contains('35.0116')));
    expect(map.key?.toString(), isNot(contains('135.7681')));
  });

  testWidgets('Google picker map recreates its surface for new coordinates', (
    tester,
  ) async {
    var initializations = 0;

    Widget pickerMap(GeoTag location) => MaterialApp(
      home: GooglePlacePickerMap(
        selectedLocation: location,
        onPinDragged: (_) {},
        platformBuilder: ({required selectedLocation, required onPinDragged}) =>
            _MapLifecycleProbe(onInit: () => initializations++),
      ),
    );

    await tester.pumpWidget(pickerMap(initialLocation));
    expect(initializations, 1);

    await tester.pumpWidget(
      pickerMap(
        const GeoTag(
          latitude: 34.994856,
          longitude: 135.785046,
          placeName: 'Kiyomizu-dera',
        ),
      ),
    );
    expect(initializations, 2);
  });
}

Widget _picker({
  required PlaceSearchService service,
  CurrentLocationService? currentLocationService,
  GeoTag? initialLocation,
  PlacePickerMapBuilder mapBuilder = _fakeMapBuilder,
}) => MaterialApp(
  home: PlacePickerScreen(
    service: service,
    currentLocationService: currentLocationService,
    initialLocation: initialLocation,
    mapBuilder: mapBuilder,
  ),
);

Future<void> _openPicker(
  WidgetTester tester, {
  required PlaceSearchService service,
  required ValueChanged<GeoTag?> onResult,
  GeoTag? initialLocation,
  PlacePickerMapBuilder mapBuilder = _fakeMapBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const Key('open-picker'),
            onPressed: () async {
              final result = await Navigator.push<GeoTag>(
                context,
                MaterialPageRoute(
                  builder: (_) => PlacePickerScreen(
                    service: service,
                    initialLocation: initialLocation,
                    mapBuilder: mapBuilder,
                  ),
                ),
              );
              onResult(result);
            },
            child: const Text('Open picker'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-picker')));
  await tester.pumpAndSettle();
}

Widget _fakeMapBuilder({
  required GeoTag? selectedLocation,
  required ValueChanged<GeoTag> onPinDragged,
}) => SizedBox(
  height: 160,
  child: Center(
    child: TextButton(
      key: const Key('fake-drag-pin'),
      onPressed: () =>
          onPinDragged(const GeoTag(latitude: 3.14159265, longitude: 101.6869)),
      child: Text(selectedLocation?.placeName ?? 'Drag pin'),
    ),
  ),
);

class _FakePlaceSearchService implements PlaceSearchService {
  List<PlaceSuggestion> searchResults = const [];
  Object? searchError;
  final Map<String, GeoTag> resolvedPlaces = {};
  Object? resolveError;
  GeoTag? reverseResult;
  Object? reverseError;
  Completer<GeoTag>? reverseCompleter;

  final List<String> searchQueries = [];
  final List<String> resolvedPlaceIds = [];
  final List<({double latitude, double longitude})> reverseCalls = [];

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    searchQueries.add(query);
    final error = searchError;
    if (error != null) throw error;
    return searchResults;
  }

  @override
  Future<GeoTag> resolvePlace(String placeId) async {
    resolvedPlaceIds.add(placeId);
    final error = resolveError;
    if (error != null) throw error;
    return resolvedPlaces[placeId]!;
  }

  @override
  Future<GeoTag> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    reverseCalls.add((latitude: latitude, longitude: longitude));
    final completer = reverseCompleter;
    if (completer != null) return completer.future;
    final error = reverseError;
    if (error != null) throw error;
    return reverseResult!;
  }
}

class _FakeCurrentLocationService implements CurrentLocationService {
  CurrentLocation? location;
  Object? error;
  Completer<CurrentLocation>? locationCompleter;
  var locateCalls = 0;
  var openAppSettingsCalls = 0;
  var openLocationSettingsCalls = 0;

  @override
  bool get supportsAppSettings => true;

  @override
  bool get supportsLocationSettings => true;

  @override
  Future<CurrentLocation> locate() async {
    locateCalls++;
    final completer = locationCompleter;
    if (completer != null) return completer.future;
    final currentError = error;
    if (currentError != null) throw currentError;
    return location!;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls++;
    return true;
  }
}

class _MapLifecycleProbe extends StatefulWidget {
  const _MapLifecycleProbe({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_MapLifecycleProbe> createState() => _MapLifecycleProbeState();
}

class _MapLifecycleProbeState extends State<_MapLifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
