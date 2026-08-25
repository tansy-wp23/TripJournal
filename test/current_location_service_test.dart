import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show PermissionDeniedException;

import 'package:tripjournal/features/location/current_location_service.dart';

void main() {
  test('fails fast on desktop without touching the location gateway', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final gateway = _FakeCurrentLocationGateway();
    final service = GeolocatorCurrentLocationService(gateway: gateway);

    await expectLater(
      service.locate(),
      throwsA(
        isA<CurrentLocationException>().having(
          (error) => error.failure,
          'failure',
          CurrentLocationFailure.unsupportedPlatform,
        ),
      ),
    );

    expect(gateway.serviceEnabledCalls, 0);
    expect(gateway.checkPermissionCalls, 0);
    expect(gateway.requestPermissionCalls, 0);
    expect(gateway.positionCalls, 0);
  });

  test(
    'does not request permission while location services are disabled',
    () async {
      final gateway = _FakeCurrentLocationGateway()..serviceEnabled = false;
      final service = GeolocatorCurrentLocationService(gateway: gateway);

      await expectLater(
        service.locate(),
        throwsA(
          isA<CurrentLocationException>().having(
            (error) => error.failure,
            'failure',
            CurrentLocationFailure.serviceDisabled,
          ),
        ),
      );

      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.positionCalls, 0);
    },
  );

  test(
    'requests foreground permission after the user starts locating',
    () async {
      final requestedAt = DateTime.utc(2026, 8, 25, 4);
      final gateway = _FakeCurrentLocationGateway()
        ..permission = CurrentLocationPermission.denied
        ..requestedPermission = CurrentLocationPermission.whileInUse
        ..position = CurrentLocationReading(
          latitude: 3.139,
          longitude: 101.6869,
          accuracyMeters: 24,
          timestamp: requestedAt,
        );
      final service = GeolocatorCurrentLocationService(
        gateway: gateway,
        now: () => requestedAt,
      );

      final location = await service.locate();

      expect(gateway.requestPermissionCalls, 1);
      expect(gateway.positionCalls, 1);
      expect(location.latitude, 3.139);
      expect(location.longitude, 101.6869);
      expect(location.accuracyMeters, 24);
    },
  );

  test('native location ignores a reading cached before the request', () async {
    final requestedAt = DateTime.utc(2026, 8, 25, 4);
    final positions = StreamController<CurrentLocationReading>();
    addTearDown(positions.close);
    final gateway = _FakeCurrentLocationGateway()
      ..positionStream = positions.stream;
    final service = GeolocatorCurrentLocationService(
      gateway: gateway,
      now: () => requestedAt,
    );

    final result = service.locate();
    positions.add(
      CurrentLocationReading(
        latitude: 37.421998,
        longitude: -122.084,
        accuracyMeters: 500,
        timestamp: requestedAt.subtract(const Duration(minutes: 30)),
      ),
    );
    positions.add(
      CurrentLocationReading(
        latitude: 3.139,
        longitude: 101.6869,
        accuracyMeters: 20,
        timestamp: requestedAt,
      ),
    );

    await expectLater(
      result,
      completion(
        isA<CurrentLocation>()
            .having((value) => value.latitude, 'latitude', 3.139)
            .having((value) => value.longitude, 'longitude', 101.6869),
      ),
    );
  });

  test('native location times out when no fresh reading arrives', () async {
    final requestedAt = DateTime.utc(2026, 8, 25, 4);
    final positions = StreamController<CurrentLocationReading>();
    addTearDown(positions.close);
    final gateway = _FakeCurrentLocationGateway()
      ..positionStream = positions.stream;
    final service = GeolocatorCurrentLocationService(
      gateway: gateway,
      now: () => requestedAt,
      nativeTimeout: const Duration(milliseconds: 1),
    );

    final result = service.locate();
    positions.add(
      CurrentLocationReading(
        latitude: 37.421998,
        longitude: -122.084,
        accuracyMeters: 500,
        timestamp: requestedAt.subtract(const Duration(minutes: 30)),
      ),
    );

    await expectLater(
      result,
      throwsA(
        isA<CurrentLocationException>().having(
          (error) => error.failure,
          'failure',
          CurrentLocationFailure.unavailable,
        ),
      ),
    );
  });

  test('reports permanently denied permission distinctly', () async {
    final gateway = _FakeCurrentLocationGateway()
      ..permission = CurrentLocationPermission.denied
      ..requestedPermission = CurrentLocationPermission.deniedForever;
    final service = GeolocatorCurrentLocationService(gateway: gateway);

    await expectLater(
      service.locate(),
      throwsA(
        isA<CurrentLocationException>().having(
          (error) => error.failure,
          'failure',
          CurrentLocationFailure.permissionDeniedForever,
        ),
      ),
    );
  });

  test(
    'maps unavailable, unsupported, and insecure-origin failures distinctly',
    () async {
      for (final testCase in [
        (
          error: TimeoutException('position timed out'),
          failure: CurrentLocationFailure.unavailable,
        ),
        (
          error: UnsupportedError('location unsupported'),
          failure: CurrentLocationFailure.unsupportedPlatform,
        ),
        (
          error: StateError('insecure origin'),
          failure: CurrentLocationFailure.insecureOrigin,
        ),
      ]) {
        final gateway = _FakeCurrentLocationGateway()
          ..positionError = testCase.error;
        final service = GeolocatorCurrentLocationService(gateway: gateway);

        await expectLater(
          service.locate(),
          throwsA(
            isA<CurrentLocationException>().having(
              (error) => error.failure,
              'failure',
              testCase.failure,
            ),
          ),
        );
      }
    },
  );

  test('maps a missing platform implementation to unsupported', () async {
    final gateway = _FakeCurrentLocationGateway()
      ..positionError = MissingPluginException('getCurrentPosition');
    final service = GeolocatorCurrentLocationService(gateway: gateway);

    await expectLater(
      service.locate(),
      throwsA(
        isA<CurrentLocationException>().having(
          (error) => error.failure,
          'failure',
          CurrentLocationFailure.unsupportedPlatform,
        ),
      ),
    );
  });

  test(
    'web prompt acquires one position without requesting permission separately',
    () async {
      final gateway = _FakeCurrentLocationGateway()
        ..permission = CurrentLocationPermission.denied
        ..position = CurrentLocationReading(
          latitude: 3.139,
          longitude: 101.6869,
          accuracyMeters: 30,
          timestamp: DateTime.utc(2026, 8, 25, 4),
        );
      final service = GeolocatorCurrentLocationService(
        gateway: gateway,
        isWeb: true,
        isWebSecureContext: () => true,
        now: () => DateTime.utc(2026, 8, 25, 4),
      );

      final location = await service.locate();

      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.positionCalls, 1);
      expect(location.latitude, 3.139);
      expect(location.longitude, 101.6869);
    },
  );

  test('web rejects a stale cached position', () async {
    final requestedAt = DateTime.utc(2026, 8, 25, 4);
    final gateway = _FakeCurrentLocationGateway()
      ..position = CurrentLocationReading(
        latitude: 37.421998,
        longitude: -122.084,
        accuracyMeters: 500,
        timestamp: requestedAt.subtract(const Duration(minutes: 5)),
      );
    final service = GeolocatorCurrentLocationService(
      gateway: gateway,
      isWeb: true,
      isWebSecureContext: () => true,
      now: () => requestedAt,
    );

    await expectLater(
      service.locate(),
      throwsA(
        isA<CurrentLocationException>().having(
          (error) => error.failure,
          'failure',
          CurrentLocationFailure.unavailable,
        ),
      ),
    );
  });

  test('web rejects an insecure context before touching the gateway', () async {
    final gateway = _FakeCurrentLocationGateway();
    final service = GeolocatorCurrentLocationService(
      gateway: gateway,
      isWeb: true,
      isWebSecureContext: () => false,
    );

    await expectLater(
      service.locate(),
      throwsA(
        isA<CurrentLocationException>().having(
          (error) => error.failure,
          'failure',
          CurrentLocationFailure.insecureOrigin,
        ),
      ),
    );

    expect(gateway.serviceEnabledCalls, 0);
    expect(gateway.checkPermissionCalls, 0);
    expect(gateway.requestPermissionCalls, 0);
    expect(gateway.positionCalls, 0);
  });

  test('web bounds a never-completing location operation', () async {
    final gateway = _FakeCurrentLocationGateway()
      ..positionCompleter = Completer<CurrentLocationReading>();
    final service = GeolocatorCurrentLocationService(
      gateway: gateway,
      isWeb: true,
      isWebSecureContext: () => true,
      webTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      service.locate(),
      throwsA(
        isA<CurrentLocationException>().having(
          (error) => error.failure,
          'failure',
          CurrentLocationFailure.unavailable,
        ),
      ),
    );

    expect(gateway.positionCalls, 1);
  });

  test(
    'web maps prompt denial separately from an already-blocked query',
    () async {
      final promptGateway = _FakeCurrentLocationGateway()
        ..permission = CurrentLocationPermission.denied
        ..positionError = const PermissionDeniedException('denied by user');
      final promptService = GeolocatorCurrentLocationService(
        gateway: promptGateway,
        isWeb: true,
        isWebSecureContext: () => true,
      );

      await expectLater(
        promptService.locate(),
        throwsA(
          isA<CurrentLocationException>().having(
            (error) => error.failure,
            'failure',
            CurrentLocationFailure.permissionDenied,
          ),
        ),
      );
      expect(promptGateway.requestPermissionCalls, 0);
      expect(promptGateway.positionCalls, 1);

      final blockedGateway = _FakeCurrentLocationGateway()
        ..permission = CurrentLocationPermission.deniedForever;
      final blockedService = GeolocatorCurrentLocationService(
        gateway: blockedGateway,
        isWeb: true,
        isWebSecureContext: () => true,
      );

      await expectLater(
        blockedService.locate(),
        throwsA(
          isA<CurrentLocationException>().having(
            (error) => error.failure,
            'failure',
            CurrentLocationFailure.permissionDeniedForever,
          ),
        ),
      );
      expect(blockedGateway.requestPermissionCalls, 0);
      expect(blockedGateway.positionCalls, 0);
    },
  );
}

class _FakeCurrentLocationGateway implements CurrentLocationGateway {
  bool serviceEnabled = true;
  CurrentLocationPermission permission = CurrentLocationPermission.whileInUse;
  CurrentLocationPermission requestedPermission =
      CurrentLocationPermission.whileInUse;
  CurrentLocationReading? position;
  Object? positionError;
  Completer<CurrentLocationReading>? positionCompleter;
  Stream<CurrentLocationReading>? positionStream;
  var serviceEnabledCalls = 0;
  var checkPermissionCalls = 0;
  var requestPermissionCalls = 0;
  var positionCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async {
    serviceEnabledCalls++;
    return serviceEnabled;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<CurrentLocationReading> getCurrentPosition() async {
    positionCalls++;
    final completer = positionCompleter;
    if (completer != null) return completer.future;
    final error = positionError;
    if (error != null) throw error;
    return position!;
  }

  @override
  Stream<CurrentLocationReading> getPositionStream() {
    final stream = positionStream;
    if (stream != null) return stream;
    return Stream.fromFuture(getCurrentPosition());
  }

  @override
  Future<CurrentLocationPermission> checkPermission() async {
    checkPermissionCalls++;
    return permission;
  }

  @override
  Future<CurrentLocationPermission> requestPermission() async {
    requestPermissionCalls++;
    return requestedPermission;
  }
}
