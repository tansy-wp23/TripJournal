import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

enum CurrentLocationFailure {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  unavailable,
  unsupportedPlatform,
  insecureOrigin,
}

class CurrentLocationException implements Exception {
  const CurrentLocationException(this.failure);

  final CurrentLocationFailure failure;
}

class CurrentLocation {
  const CurrentLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

enum CurrentLocationPermission { denied, deniedForever, whileInUse, always }

abstract interface class CurrentLocationService {
  Future<CurrentLocation> locate();

  bool get supportsAppSettings;

  bool get supportsLocationSettings;

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

/// A narrow wrapper around the platform plugin, kept injectable for tests.
abstract interface class CurrentLocationGateway {
  Future<bool> isLocationServiceEnabled();

  Future<CurrentLocationPermission> checkPermission();

  Future<CurrentLocationPermission> requestPermission();

  Future<CurrentLocation> getCurrentPosition();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class GeolocatorCurrentLocationService implements CurrentLocationService {
  GeolocatorCurrentLocationService({CurrentLocationGateway? gateway})
    : _gateway = gateway ?? _GeolocatorGateway();

  final CurrentLocationGateway _gateway;

  @override
  bool get supportsAppSettings => _supportsNativeSettings;

  @override
  bool get supportsLocationSettings => _supportsNativeSettings;

  @override
  Future<CurrentLocation> locate() async {
    try {
      if (!await _gateway.isLocationServiceEnabled()) {
        throw const CurrentLocationException(
          CurrentLocationFailure.serviceDisabled,
        );
      }

      var permission = await _gateway.checkPermission();
      if (permission == CurrentLocationPermission.denied) {
        permission = await _gateway.requestPermission();
      }

      switch (permission) {
        case CurrentLocationPermission.denied:
          throw const CurrentLocationException(
            CurrentLocationFailure.permissionDenied,
          );
        case CurrentLocationPermission.deniedForever:
          throw const CurrentLocationException(
            CurrentLocationFailure.permissionDeniedForever,
          );
        case CurrentLocationPermission.whileInUse ||
            CurrentLocationPermission.always:
          return await _gateway.getCurrentPosition();
      }
    } on CurrentLocationException {
      rethrow;
    } catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<bool> openAppSettings() => _open(_gateway.openAppSettings);

  @override
  Future<bool> openLocationSettings() => _open(_gateway.openLocationSettings);

  Future<bool> _open(Future<bool> Function() action) async {
    if (!_supportsNativeSettings) return false;
    try {
      return await action();
    } catch (_) {
      return false;
    }
  }
}

bool get _supportsNativeSettings =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class _GeolocatorGateway implements CurrentLocationGateway {
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<CurrentLocationPermission> checkPermission() async =>
      _permissionFor(await Geolocator.checkPermission());

  @override
  Future<CurrentLocationPermission> requestPermission() async =>
      _permissionFor(await Geolocator.requestPermission());

  @override
  Future<CurrentLocation> getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return CurrentLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      throw const CurrentLocationException(CurrentLocationFailure.unavailable);
    } catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

CurrentLocationPermission _permissionFor(LocationPermission permission) =>
    switch (permission) {
      LocationPermission.denied => CurrentLocationPermission.denied,
      LocationPermission.deniedForever =>
        CurrentLocationPermission.deniedForever,
      LocationPermission.whileInUse => CurrentLocationPermission.whileInUse,
      LocationPermission.always => CurrentLocationPermission.always,
      LocationPermission.unableToDetermine => CurrentLocationPermission.denied,
    };

CurrentLocationException _failureFor(Object error) {
  if (error is CurrentLocationException) return error;
  if (error is MissingPluginException || error is UnsupportedError) {
    return const CurrentLocationException(
      CurrentLocationFailure.unsupportedPlatform,
    );
  }
  final detail = error.toString().toLowerCase();
  if (detail.contains('insecure') ||
      detail.contains('secure context') ||
      detail.contains('https')) {
    return const CurrentLocationException(
      CurrentLocationFailure.insecureOrigin,
    );
  }
  if (detail.contains('unsupported') || detail.contains('not supported')) {
    return const CurrentLocationException(
      CurrentLocationFailure.unsupportedPlatform,
    );
  }
  if (detail.contains('service') && detail.contains('disabled')) {
    return const CurrentLocationException(
      CurrentLocationFailure.serviceDisabled,
    );
  }
  return const CurrentLocationException(CurrentLocationFailure.unavailable);
}
