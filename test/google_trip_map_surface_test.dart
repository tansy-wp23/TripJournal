import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tripjournal/features/trip/map/google_trip_map_surface.dart';
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

    final markers = googleTripMapMarkers(
      model: model,
      onSelected: selected.add,
    );

    expect(markers, hasLength(1));
    final marker = markers.single;
    expect(marker.infoWindow.title, 'D2');
    expect(marker.position, const LatLng(3.139, 101.6869));

    marker.onTap!();
    expect(selected.single.key, model.groups.single.key);
  });

  test('clustering starts only above twenty entry marker groups', () {
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

    final twenty = groups(20);
    final twentyOne = groups(21);

    expect(
      googleTripMapMarkers(
        model: twenty,
        onSelected: (_) {},
      ).every((marker) => marker.clusterManagerId == null),
      isTrue,
    );
    expect(googleTripMapClusterManagers(twenty, onClusterTap: (_) {}), isEmpty);

    final clusteredMarkers = googleTripMapMarkers(
      model: twentyOne,
      onSelected: (_) {},
    );
    expect(
      clusteredMarkers.every((marker) => marker.clusterManagerId != null),
      isTrue,
    );
    expect(
      googleTripMapClusterManagers(twentyOne, onClusterTap: (_) {}),
      hasLength(1),
    );
  });

  test('direction arrows never join the entry marker cluster', () {
    final model = modelFor([
      for (var index = 0; index < 21; index++)
        entry(
          id: 'day-${index + 1}',
          createdAt: tripStart.add(Duration(days: index)),
          latitude: index.toDouble(),
          longitude: index.toDouble(),
          placeId: 'day-place-$index',
        ),
    ]);

    expect(model.groups, hasLength(21));
    expect(
      googleTripMapArrowMarkers(
        model,
      ).every((marker) => marker.clusterManagerId == null),
      isTrue,
    );
  });

  test('selected-day previous context marker is visually muted', () {
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

    final markers = googleTripMapMarkers(model: model, onSelected: (_) {});
    final contextMarker = markers.singleWhere(
      (marker) => marker.markerId.value.startsWith('context:'),
    );
    final currentMarker = markers.singleWhere(
      (marker) => !marker.markerId.value.startsWith('context:'),
    );

    expect(contextMarker.alpha, lessThan(currentMarker.alpha));
    expect(contextMarker.infoWindow.title, 'D1 · Previous day');
    expect(currentMarker.infoWindow.title, 'D2');
  });

  test('connectors use stable polylines and separate near-target arrows', () {
    final model = modelFor([
      entry(id: 'day-1', createdAt: tripStart, latitude: 0, longitude: 0),
      entry(
        id: 'day-2',
        createdAt: tripStart.add(const Duration(days: 1)),
        latitude: 0,
        longitude: 10,
      ),
    ]);

    final polylines = googleTripMapPolylines(model);
    final arrows = googleTripMapArrowMarkers(model);

    expect(polylines, hasLength(1));
    final polyline = polylines.single;
    expect(polyline.polylineId.value, 'day-1-to-day-2');
    expect(polyline.points, const [LatLng(0, 0), LatLng(0, 10)]);
    expect(polyline.startCap, Cap.buttCap);
    expect(polyline.endCap, Cap.buttCap);

    expect(arrows, hasLength(1));
    final arrow = arrows.single;
    expect(arrow.markerId.value, 'day-1-to-day-2-arrow');
    expect(arrow.icon, isA<BytesMapBitmap>());
    expect(arrow.flat, isTrue);
    expect(arrow.rotation, closeTo(90, 0.0001));
    expect(arrow.position.latitude, closeTo(0, 0.0001));
    expect(arrow.position.longitude, greaterThan(5));
    expect(arrow.position.longitude, lessThan(10));
  });

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

    final arrow = googleTripMapArrowMarkers(model).single;

    expect(arrow.position.latitude, closeTo(64.322196, 0.000001));
    expect(arrow.position.longitude, closeTo(-174.095578, 0.000001));
    expect(arrow.rotation, closeTo(67.015901, 0.000001));
  });

  test('antimeridian-equivalent endpoints emit no connector arrow', () {
    final model = modelFor([
      entry(id: 'day-1', createdAt: tripStart, latitude: 10, longitude: 180),
      entry(
        id: 'day-2',
        createdAt: tripStart.add(const Duration(days: 1)),
        latitude: 10,
        longitude: -180,
      ),
    ]);

    expect(model.connectors, isEmpty);
    expect(googleTripMapArrowMarkers(model), isEmpty);
  });

  test('one group uses zoom 12 and multiple groups use model bounds', () {
    final one = modelFor([
      entry(id: 'one', createdAt: tripStart, latitude: 1, longitude: 2),
    ]);
    final oneUpdate = googleTripMapCameraUpdate(one);

    expect(oneUpdate.toJson(), [
      'newLatLngZoom',
      [1.0, 2.0],
      12.0,
    ]);

    final many = modelFor([
      entry(id: 'south', createdAt: tripStart, latitude: -2, longitude: 5),
      entry(
        id: 'north',
        createdAt: tripStart.add(const Duration(hours: 1)),
        latitude: 4,
        longitude: -3,
      ),
    ]);
    final manyUpdate = googleTripMapCameraUpdate(many);

    expect(manyUpdate.toJson(), [
      'newLatLngBounds',
      [
        [-2.0, -3.0],
        [4.0, 5.0],
      ],
      48.0,
    ]);

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
    expect(googleTripMapCameraUpdate(acrossDateline).toJson(), [
      'newLatLngBounds',
      [
        [10.0, 179.0],
        [11.0, -179.0],
      ],
      48.0,
    ]);
  });

  test('web rendering stays unavailable when no web key is configured', () {
    expect(
      googleMapsRenderingConfiguredForPlatform(
        isWeb: true,
        platform: TargetPlatform.android,
        androidKey: 'android-key',
        iosKey: 'ios-key',
        webKey: '  ',
        webSdkReady: true,
      ),
      isFalse,
    );
  });

  test('web rendering is available when its key and SDK loader are ready', () {
    expect(
      googleMapsRenderingConfiguredForPlatform(
        isWeb: true,
        platform: TargetPlatform.android,
        androidKey: '',
        iosKey: '',
        webKey: 'web-key',
        webSdkReady: true,
      ),
      isTrue,
    );
  });

  test('web rendering stays unavailable when its SDK loader failed', () {
    expect(
      googleMapsRenderingConfiguredForPlatform(
        isWeb: true,
        platform: TargetPlatform.android,
        androidKey: '',
        iosKey: '',
        webKey: 'web-key',
        webSdkReady: false,
      ),
      isFalse,
    );
  });

  test('native configuration checks only the current platform key', () {
    expect(
      googleMapsRenderingConfiguredForPlatform(
        isWeb: false,
        platform: TargetPlatform.android,
        androidKey: 'android-key',
        iosKey: '',
        webKey: '',
        webSdkReady: false,
      ),
      isTrue,
    );
    expect(
      googleMapsRenderingConfiguredForPlatform(
        isWeb: false,
        platform: TargetPlatform.windows,
        androidKey: 'android-key',
        iosKey: 'ios-key',
        webKey: 'web-key',
        webSdkReady: true,
      ),
      isFalse,
    );
  });

  testWidgets('configured builder falls back with Retry when no key exists', (
    tester,
  ) async {
    final model = modelFor([
      entry(id: 'mapped', createdAt: tripStart, latitude: 1, longitude: 2),
    ]);

    final surface = buildConfiguredTripMapSurface(
      model: model,
      onSelected: (_) {},
    );

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(width: 400, height: 400, child: surface)),
    );

    expect(find.byType(TripMapUnavailableSurface), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(TripMapUnavailableSurface), findsOneWidget);
  });

  test('platform map keeps current-location features disabled', () {
    const groupMarker = Marker(markerId: MarkerId('group'));
    const arrowMarker = Marker(markerId: MarkerId('arrow'));
    const polyline = Polyline(polylineId: PolylineId('connector'));
    final map = buildGoogleTripMapPlatform(
      initialCameraPosition: const CameraPosition(
        target: LatLng(1, 2),
        zoom: 12,
      ),
      markers: <Marker>{groupMarker},
      polylines: <Polyline>{polyline},
      arrowMarkers: <Marker>{arrowMarker},
      clusterManagers: const <ClusterManager>{},
      onMapCreated: (_) {},
    );

    expect(map, isA<GoogleMap>());
    expect((map as GoogleMap).myLocationEnabled, isFalse);
    expect(map.myLocationButtonEnabled, isFalse);
    expect(map.markers.map((marker) => marker.markerId.value).toSet(), {
      'group',
      'arrow',
    });
    expect(map.polylines.single.polylineId.value, 'connector');
  });

  testWidgets('platform builder receives connector overlays', (tester) async {
    final model = modelFor([
      entry(id: 'day-1', createdAt: tripStart, latitude: 1, longitude: 2),
      entry(
        id: 'day-2',
        createdAt: tripStart.add(const Duration(days: 1)),
        latitude: 3,
        longitude: 4,
      ),
    ]);
    Set<Polyline>? receivedPolylines;
    Set<Marker>? receivedArrows;

    await tester.pumpWidget(
      MaterialApp(
        home: GoogleTripMapSurface(
          model: model,
          onSelected: (_) {},
          platformBuilder:
              ({
                required initialCameraPosition,
                required markers,
                required polylines,
                required arrowMarkers,
                required clusterManagers,
                required onMapCreated,
              }) {
                receivedPolylines = polylines;
                receivedArrows = arrowMarkers;
                return const SizedBox();
              },
        ),
      ),
    );

    expect(receivedPolylines?.single.polylineId.value, 'day-1-to-day-2');
    expect(receivedArrows?.single.markerId.value, 'day-1-to-day-2-arrow');
  });

  testWidgets('tapping a native cluster zooms to its bounds', (tester) async {
    final model = modelFor([
      for (var index = 0; index < 21; index++)
        entry(
          id: 'cluster-$index',
          createdAt: tripStart.add(Duration(minutes: index)),
          latitude: 1 + index / 100,
          longitude: 2 + index / 100,
          placeId: 'cluster-place-$index',
        ),
    ]);
    final controller = _RecordingCameraController();
    Set<ClusterManager>? receivedManagers;

    await tester.pumpWidget(
      MaterialApp(
        home: GoogleTripMapSurface(
          model: model,
          onSelected: (_) {},
          platformBuilder:
              ({
                required initialCameraPosition,
                required markers,
                required polylines,
                required arrowMarkers,
                required clusterManagers,
                required onMapCreated,
              }) {
                receivedManagers = clusterManagers;
                return TextButton(
                  key: const Key('cluster-map-ready'),
                  onPressed: () => onMapCreated(controller),
                  child: const Text('Map ready'),
                );
              },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('cluster-map-ready')));
    await tester.pump();
    controller.updates.clear();

    final manager = receivedManagers!.single;
    manager.onClusterTap!(
      Cluster(
        manager.clusterManagerId,
        const [MarkerId('a'), MarkerId('b')],
        position: const LatLng(1.1, 2.1),
        bounds: LatLngBounds(
          southwest: const LatLng(1, 2),
          northeast: const LatLng(1.2, 2.2),
        ),
      ),
    );
    await tester.pump();

    expect(controller.updates, hasLength(1));
    expect(
      (controller.updates.single.toJson() as List<Object?>).first,
      'newLatLngBounds',
    );
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
          child: GoogleTripMapSurface(
            model: model,
            onSelected: (_) {},
            platformBuilder:
                ({
                  required initialCameraPosition,
                  required markers,
                  required polylines,
                  required arrowMarkers,
                  required clusterManagers,
                  required onMapCreated,
                }) => TextButton(
                  key: const Key('fake-multi-group-map-ready'),
                  onPressed: () => onMapCreated(controller),
                  child: const Text('Map ready'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('fake-multi-group-map-ready')));
    expect(
      controller.updates,
      isEmpty,
      reason: 'Bounds cannot be applied until the platform view is laid out.',
    );

    await tester.pump();
    expect(controller.updates, hasLength(1));
    final updateJson = controller.updates.single.toJson() as List<Object?>;
    expect(updateJson.first, 'newLatLngBounds');
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
      required initialCameraPosition,
      required markers,
      required polylines,
      required arrowMarkers,
      required clusterManagers,
      required onMapCreated,
    }) => TextButton(
      key: const Key('fake-connector-map-ready'),
      onPressed: () => onMapCreated(controller),
      child: const Text('Map ready'),
    );

    Widget surface(TripMapModel model) => MaterialApp(
      home: GoogleTripMapSurface(
        model: model,
        onSelected: (_) {},
        platformBuilder: platformBuilder,
      ),
    );

    await tester.pumpWidget(surface(connectorModel(10, 20)));
    await tester.tap(find.byKey(const Key('fake-connector-map-ready')));
    await tester.pump();
    controller.updates.clear();

    await tester.pumpWidget(surface(connectorModel(11, 21)));
    await tester.pump();

    expect(controller.updates, hasLength(1));
    final updateJson = controller.updates.single.toJson() as List<Object?>;
    expect(updateJson.first, 'newLatLngBounds');
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
          child: GoogleTripMapSurface(
            model: model,
            onSelected: (_) {},
            platformBuilder:
                ({
                  required initialCameraPosition,
                  required markers,
                  required polylines,
                  required arrowMarkers,
                  required clusterManagers,
                  required onMapCreated,
                }) {
                  platformBuilds++;
                  return TextButton(
                    key: const Key('fake-google-map-ready'),
                    onPressed: () => onMapCreated(_FailingCameraController()),
                    child: const Text('Map ready'),
                  );
                },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('fake-google-map-ready')));
    await tester.pumpAndSettle();

    expect(find.text('Map unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.byKey(const Key('fake-google-map-ready')), findsOneWidget);
    expect(platformBuilds, 2);
  });
}

class _FailingCameraController implements TripMapCameraController {
  @override
  Future<void> animateCamera(CameraUpdate update) {
    throw PlatformException(code: 'camera-failed');
  }
}

class _RecordingCameraController implements TripMapCameraController {
  final updates = <CameraUpdate>[];

  @override
  Future<void> animateCamera(CameraUpdate update) async {
    updates.add(update);
  }
}
