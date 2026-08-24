import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:tripjournal/features/location/current_location_service.dart';

void main() {
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
      final gateway = _FakeCurrentLocationGateway()
        ..permission = CurrentLocationPermission.denied
        ..requestedPermission = CurrentLocationPermission.whileInUse
        ..position = const CurrentLocation(
          latitude: 3.139,
          longitude: 101.6869,
        );
      final service = GeolocatorCurrentLocationService(gateway: gateway);

      final location = await service.locate();

      expect(gateway.requestPermissionCalls, 1);
      expect(gateway.positionCalls, 1);
      expect(location.latitude, 3.139);
      expect(location.longitude, 101.6869);
    },
  );

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
}

class _FakeCurrentLocationGateway implements CurrentLocationGateway {
  bool serviceEnabled = true;
  CurrentLocationPermission permission = CurrentLocationPermission.whileInUse;
  CurrentLocationPermission requestedPermission =
      CurrentLocationPermission.whileInUse;
  CurrentLocation? position;
  Object? positionError;
  var requestPermissionCalls = 0;
  var positionCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<CurrentLocation> getCurrentPosition() async {
    positionCalls++;
    final error = positionError;
    if (error != null) throw error;
    return position!;
  }

  @override
  Future<CurrentLocationPermission> checkPermission() async => permission;

  @override
  Future<CurrentLocationPermission> requestPermission() async {
    requestPermissionCalls++;
    return requestedPermission;
  }
}
