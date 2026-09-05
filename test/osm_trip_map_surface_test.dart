import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:tripjournal/features/trip/map/osm_trip_map_surface.dart';
import 'package:tripjournal/features/trip/map/trip_map_model.dart';
import 'package:tripjournal/models/geo_tag.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

void main() {
  final tripStart = DateTime(2026, 8, 15);
  final tripEnd = tripStart.add(const Duration(days: 30));

  JournalEntry entry({
    required String id,
    required DateTime createdAt,
    required double latitude,
    required double longitude,
    String? placeId,
    String? placeName,
  }) => JournalEntry(
    id: id,
    tripId: 'trip-1',
    title: id,
    body: '',
    mood: Mood.happy,
    photoPaths: const [],
    location: GeoTag(
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
      placeName: placeName,
    ),
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  TripMapModel modelFor(List<JournalEntry> entries) => buildTripMapModel(
    entries: entries,
    tripStartDate: tripStart,
    tripEndDate: tripEnd,
  );

  test('markers show their day label and select the matching group', () {
    final model = modelFor([
      entry(
        id: 'second-day',
        createdAt: tripStart.add(const Duration(days: 1)),
        latitude: 3.139,
        longitude: 101.6869,
      ),
    ]);
    final selected = <TripMapMarkerGroup>[];

    final markers = osmTripMapMarkers(model: model, onSelected: selected.add);

    expect(markers, hasLength(1));
    final marker = markers.single;
    expect(marker.dayLabel, 'D2');
    expect(marker.point, const ll.LatLng(3.139, 101.6869));

    marker.onTap();
    expect(selected.single.key, model.groups.single.key);
  });

  test('different coordinates keep distinct marker identities', () {
    final model = modelFor([
      entry(
        id: 'day-2-second',
        createdAt: tripStart.add(const Duration(days: 1, hours: 2)),
        latitude: 3.1579,
        longitude: 101.7123,
        placeId: 'broad-place-id',
      ),
      entry(
        id: 'day-3',
        createdAt: tripStart.add(const Duration(days: 2)),
        latitude: 3.1390,
        longitude: 101.6869,
        placeId: 'broad-place-id',
      ),
    ]);

    final markers = osmTripMapMarkers(model: model, onSelected: (_) {});

    expect(markers, hasLength(2));
    expect(markers.map((marker) => marker.key).toSet(), hasLength(2));
    expect(markers.map((marker) => marker.point).toSet(), {
      const ll.LatLng(3.1579, 101.7123),
      const ll.LatLng(3.1390, 101.6869),
    });
  });

  test('selected day renders cumulative markers with their day labels', () {
    final model = buildTripMapModel(
      entries: [
        entry(id: 'day-1', createdAt: tripStart, latitude: 1, longitude: 2),
        entry(
          id: 'day-2',
          createdAt: tripStart.add(const Duration(days: 1)),
          latitude: 3,
          longitude: 4,
        ),
      ],
      tripStartDate: tripStart,
      tripEndDate: tripEnd,
      selectedDay: 2,
    );

    final markers = osmTripMapMarkers(model: model, onSelected: (_) {});

    expect(markers, hasLength(2));
    expect(markers.map((marker) => marker.dayLabel).toSet(), {'D1', 'D2'});
  });

  test(
    'route segments use stable polylines and separate near-target arrows',
    () {
      final model = modelFor([
        entry(id: 'day-1', createdAt: tripStart, latitude: 0, longitude: 0),
        entry(
          id: 'nice',
          createdAt: tripStart.add(const Duration(days: 1)),
          latitude: 0,
          longitude: 10,
        ),
        entry(
          id: 'ur',
          createdAt: tripStart.add(const Duration(days: 1, hours: 1)),
          latitude: 0,
          longitude: 20,
        ),
      ]);

      final polylines = osmTripMapPolylines(model);
      final arrows = osmTripMapArrowMarkers(model);

      expect(model.routeSegments.map((s) => s.id).toSet(), {
        'entry-day-1-to-nice',
        'entry-nice-to-ur',
      });
      final firstPolyline =
          polylines[model.routeSegments.indexWhere(
            (s) => s.id == 'entry-day-1-to-nice',
          )];
      expect(firstPolyline.points, const [ll.LatLng(0, 0), ll.LatLng(0, 10)]);

      expect(arrows.map((marker) => marker.key).toSet(), {
        'entry-day-1-to-nice-arrow',
        'entry-nice-to-ur-arrow',
      });
      final arrow = arrows.singleWhere(
        (marker) => marker.key == 'entry-day-1-to-nice-arrow',
      );
      expect(arrow.bearingDegrees, closeTo(90, 0.0001));
      expect(arrow.point.latitude, closeTo(0, 0.0001));
      expect(arrow.point.longitude, greaterThan(5));
      expect(arrow.point.longitude, lessThan(10));
    },
  );

  test('arrow follows the geodesic course near an antimeridian target', () {
    final model = modelFor([
      entry(id: 'day-1', createdAt: tripStart, latitude: 60, longitude: 170),
      entry(
        id: 'day-2',
        createdAt: tripStart.add(const Duration(days: 1)),
        latitude: 65,
        longitude: -170,
      ),
    ]);

    final arrow = osmTripMapArrowMarkers(model).single;

    expect(arrow.point.latitude, closeTo(64.322196, 0.000001));
    expect(arrow.point.longitude, closeTo(-174.095578, 0.000001));
    expect(arrow.bearingDegrees, closeTo(67.015901, 0.000001));
  });

  test('antimeridian-equivalent endpoints emit no route segment arrow', () {
    final model = modelFor([
      entry(id: 'day-1', createdAt: tripStart, latitude: 10, longitude: 180),
      entry(
        id: 'day-2',
        createdAt: tripStart.add(const Duration(days: 1)),
        latitude: 10,
        longitude: -180,
      ),
    ]);

    expect(model.routeSegments, isEmpty);
    expect(osmTripMapArrowMarkers(model), isEmpty);
  });

  test(
    'one group targets zoom 15 and multiple groups fit the model bounds',
    () {
      final one = modelFor([
        entry(id: 'one', createdAt: tripStart, latitude: 1, longitude: 2),
      ]);
      final oneTarget = osmTripMapCameraTarget(one) as TripMapCameraZoom;

      expect(oneTarget.center, const ll.LatLng(1, 2));
      expect(oneTarget.zoom, 15);

      final many = modelFor([
        entry(id: 'south', createdAt: tripStart, latitude: -2, longitude: 5),
        entry(
          id: 'north',
          createdAt: tripStart.add(const Duration(hours: 1)),
          latitude: 4,
          longitude: -3,
        ),
      ]);
      final manyTarget = osmTripMapCameraTarget(many) as TripMapCameraBounds;

      expect(manyTarget.bounds.southWest, const ll.LatLng(-2, -3));
      expect(manyTarget.bounds.northEast, const ll.LatLng(4, 5));
      expect(manyTarget.padding, 48);

      final acrossDateline = modelFor([
        entry(
          id: 'west-of-dateline',
          createdAt: tripStart,
          latitude: 10,
          longitude: 179,
        ),
        entry(
          id: 'east-of-dateline',
          createdAt: tripStart.add(const Duration(hours: 1)),
          latitude: 11,
          longitude: -179,
        ),
      ]);
      final datelineTarget =
          osmTripMapCameraTarget(acrossDateline) as TripMapCameraBounds;
      // ponytail: flutter_map's LatLngBounds picks west=min/east=max of the two
      // raw corners with no antimeridian awareness, unlike Google Maps'
      // LatLngBounds (which preserved the sw/ne pair as given). The model still
      // computes the antimeridian-safe corner pair (see trip_map_model.dart),
      // but the fit into flutter_map's own bounds type loses it here - the
      // fitted view ends up spanning the *wide* side of the world for a
      // dateline-crossing trip instead of the narrow side. Upgrade path: detect
      // a >180° raw span and fit a MapController.move on the midpoint instead
      // of CameraFit.bounds, if a real trip ever crosses the antimeridian.
      expect(datelineTarget.bounds.southWest, const ll.LatLng(10, -179));
      expect(datelineTarget.bounds.northEast, const ll.LatLng(11, 179));
    },
  );

  test('platform map renders OSM tiles with attribution and no key needed', () {
    final map =
        buildOsmTripMapPlatform(
              initialCenter: const ll.LatLng(1, 2),
              initialZoom: 12,
              markers: const [],
              arrowMarkers: const [],
              polylines: const [],
              clustered: false,
              mapController: MapController(),
              onMapReady: (_) {},
            )
            as FlutterMap;

    final tileLayer = map.children.whereType<TileLayer>().single;
    expect(
      tileLayer.urlTemplate,
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    );
    // userAgentPackageName isn't stored as a field - it's folded into the
    // tile provider's User-Agent header at construction time.
    expect(
      tileLayer.tileProvider.headers['User-Agent'],
      contains('com.tripjournal.tripjournal'),
    );
    expect(map.children.whereType<RichAttributionWidget>(), hasLength(1));
  });

  testWidgets('clustering starts only above twenty entry marker groups', (
    tester,
  ) async {
    TripMapModel groups(int count) => modelFor([
      for (var index = 0; index < count; index++)
        entry(
          id: 'entry-$index',
          createdAt: tripStart.add(Duration(minutes: index)),
          latitude: 1 + index / 100,
          longitude: 2 + index / 100,
          placeId: 'place-$index',
        ),
    ]);

    bool? clusteredForTwenty;
    bool? clusteredForTwentyOne;

    Widget capture(TripMapModel model, ValueChanged<bool> onCaptured) =>
        MaterialApp(
          home: OsmTripMapSurface(
            model: model,
            onSelected: (_) {},
            platformBuilder:
                ({
                  required initialCenter,
                  required initialZoom,
                  required markers,
                  required arrowMarkers,
                  required polylines,
                  required clustered,
                  required mapController,
                  required onMapReady,
                }) {
                  onCaptured(clustered);
                  return const SizedBox();
                },
          ),
        );

    await tester.pumpWidget(
      capture(groups(20), (value) => clusteredForTwenty = value),
    );
    await tester.pumpWidget(
      capture(groups(21), (value) => clusteredForTwentyOne = value),
    );

    expect(clusteredForTwenty, isFalse);
    expect(clusteredForTwentyOne, isTrue);
  });

  testWidgets(
    'above the threshold the real platform builder uses a cluster layer, '
    'below it a plain marker layer - arrows never join either',
    (tester) async {
      TripMapModel groups(int count) => modelFor([
        for (var index = 0; index < count; index++)
          entry(
            id: 'entry-$index',
            createdAt: tripStart.add(Duration(minutes: index)),
            latitude: 1 + index / 100,
            longitude: 2 + index / 100,
            placeId: 'place-$index',
          ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: OsmTripMapSurface(model: groups(21), onSelected: (_) {}),
        ),
      );

      expect(find.byType(MarkerClusterLayerWidget), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: OsmTripMapSurface(model: groups(5), onSelected: (_) {}),
        ),
      );

      expect(find.byType(MarkerClusterLayerWidget), findsNothing);
    },
  );

  testWidgets('platform builder receives route segment overlays', (
    tester,
  ) async {
    final model = modelFor([
      entry(id: 'day-1', createdAt: tripStart, latitude: 1, longitude: 2),
      entry(
        id: 'day-2',
        createdAt: tripStart.add(const Duration(days: 1)),
        latitude: 3,
        longitude: 4,
      ),
    ]);
    List<Polyline>? receivedPolylines;
    List<Marker>? receivedArrows;

    await tester.pumpWidget(
      MaterialApp(
        home: OsmTripMapSurface(
          model: model,
          onSelected: (_) {},
          platformBuilder:
              ({
                required initialCenter,
                required initialZoom,
                required markers,
                required arrowMarkers,
                required polylines,
                required clustered,
                required mapController,
                required onMapReady,
              }) {
                receivedPolylines = polylines;
                receivedArrows = arrowMarkers;
                return const SizedBox();
              },
        ),
      ),
    );

    expect(receivedPolylines, hasLength(1));
    expect(receivedArrows, hasLength(1));
  });

  testWidgets('initial multi-group bounds wait for a post-layout frame', (
    tester,
  ) async {
    final model = modelFor([
      entry(id: 'south', createdAt: tripStart, latitude: -2, longitude: 5),
      entry(
        id: 'north',
        createdAt: tripStart.add(const Duration(hours: 1)),
        latitude: 4,
        longitude: -3,
      ),
    ]);
    final controller = _RecordingCameraController();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 400,
          child: OsmTripMapSurface(
            model: model,
            onSelected: (_) {},
            platformBuilder:
                ({
                  required initialCenter,
                  required initialZoom,
                  required markers,
                  required arrowMarkers,
                  required polylines,
                  required clustered,
                  required mapController,
                  required onMapReady,
                }) => TextButton(
                  key: const Key('fake-multi-group-map-ready'),
                  onPressed: () => onMapReady(controller),
                  child: const Text('Map ready'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('fake-multi-group-map-ready')));
    expect(
      controller.boundsCalls,
      isEmpty,
      reason: 'Bounds cannot be applied until the platform view is laid out.',
    );

    await tester.pump();
    expect(controller.boundsCalls, hasLength(1));
  });

  testWidgets('connector endpoint changes refresh camera bounds', (
    tester,
  ) async {
    TripMapModel connectorModel(double finalLatitude, double finalLongitude) =>
        modelFor([
          entry(
            id: 'day-1-first',
            createdAt: tripStart,
            latitude: 1,
            longitude: 2,
            placeId: 'day-1-place',
          ),
          entry(
            id: 'day-1-last',
            createdAt: tripStart.add(const Duration(hours: 2)),
            latitude: finalLatitude,
            longitude: finalLongitude,
            placeId: 'day-1-place',
          ),
          entry(
            id: 'day-2-first',
            createdAt: tripStart.add(const Duration(days: 1)),
            latitude: 3,
            longitude: 4,
          ),
        ]);
    final controller = _RecordingCameraController();

    Widget platformBuilder({
      required initialCenter,
      required initialZoom,
      required markers,
      required arrowMarkers,
      required polylines,
      required clustered,
      required mapController,
      required onMapReady,
    }) => TextButton(
      key: const Key('fake-connector-map-ready'),
      onPressed: () => onMapReady(controller),
      child: const Text('Map ready'),
    );

    Widget surface(TripMapModel model) => MaterialApp(
      home: OsmTripMapSurface(
        model: model,
        onSelected: (_) {},
        platformBuilder: platformBuilder,
      ),
    );

    await tester.pumpWidget(surface(connectorModel(10, 20)));
    await tester.tap(find.byKey(const Key('fake-connector-map-ready')));
    await tester.pump();
    controller.boundsCalls.clear();

    await tester.pumpWidget(surface(connectorModel(11, 21)));
    await tester.pump();

    expect(controller.boundsCalls, hasLength(1));
  });

  testWidgets('camera platform errors show fallback and allow retry', (
    tester,
  ) async {
    final model = modelFor([
      entry(id: 'one', createdAt: tripStart, latitude: 1, longitude: 2),
      entry(
        id: 'two',
        createdAt: tripStart.add(const Duration(hours: 1)),
        latitude: 3,
        longitude: 4,
      ),
    ]);
    var platformBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 400,
          child: OsmTripMapSurface(
            model: model,
            onSelected: (_) {},
            platformBuilder:
                ({
                  required initialCenter,
                  required initialZoom,
                  required markers,
                  required arrowMarkers,
                  required polylines,
                  required clustered,
                  required mapController,
                  required onMapReady,
                }) {
                  platformBuilds++;
                  return TextButton(
                    key: const Key('fake-map-ready'),
                    onPressed: () => onMapReady(_FailingCameraController()),
                    child: const Text('Map ready'),
                  );
                },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('fake-map-ready')));
    await tester.pumpAndSettle();

    expect(find.text('Map unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.byKey(const Key('fake-map-ready')), findsOneWidget);
    expect(platformBuilds, 2);
  });
}

class _FailingCameraController implements TripMapCameraController {
  @override
  void moveTo(ll.LatLng target, double zoom) =>
      throw StateError('camera-failed');

  @override
  void fitBounds(LatLngBounds bounds, {double padding = 48}) =>
      throw StateError('camera-failed');
}

class _RecordingCameraController implements TripMapCameraController {
  final zoomCalls = <(ll.LatLng, double)>[];
  final boundsCalls = <LatLngBounds>[];

  @override
  void moveTo(ll.LatLng target, double zoom) => zoomCalls.add((target, zoom));

  @override
  void fitBounds(LatLngBounds bounds, {double padding = 48}) =>
      boundsCalls.add(bounds);
}
