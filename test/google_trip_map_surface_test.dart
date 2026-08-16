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

  JournalEntry entry({
    required String id,
    required DateTime createdAt,
    required double latitude,
    required double longitude,
  }) => JournalEntry(
    id: id,
    tripId: 'trip-1',
    title: id,
    body: '',
    mood: Mood.happy,
    photoPaths: const [],
    location: GeoTag(latitude: latitude, longitude: longitude),
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  TripMapModel modelFor(List<JournalEntry> entries) =>
      buildTripMapModel(entries: entries, tripStartDate: tripStart);

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
    final map = buildGoogleTripMapPlatform(
      initialCameraPosition: const CameraPosition(
        target: LatLng(1, 2),
        zoom: 12,
      ),
      markers: const <Marker>{},
      onMapCreated: (_) {},
    );

    expect(map, isA<GoogleMap>());
    expect((map as GoogleMap).myLocationEnabled, isFalse);
    expect(map.myLocationButtonEnabled, isFalse);
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
