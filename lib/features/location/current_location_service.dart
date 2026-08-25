import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'web_secure_context.dart' as web_secure_context;

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

class CurrentLocationReading {
  const CurrentLocationReading({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
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

  Future<CurrentLocationReading> getCurrentPosition();

  Stream<CurrentLocationReading> getPositionStream();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class GeolocatorCurrentLocationService implements CurrentLocationService {
  GeolocatorCurrentLocationService({
    CurrentLocationGateway? gateway,
    bool? isWeb,
    bool Function()? isWebSecureContext,
    Duration webTimeout = const Duration(seconds: 15),
    Duration? nativeTimeout,
    DateTime Function()? now,
  }) : _gateway = gateway ?? _GeolocatorGateway(),
       _isWeb = isWeb ?? kIsWeb,
       _isWebSecureContext =
           isWebSecureContext ?? web_secure_context.isWebSecureContext,
       _nativeTimeout = nativeTimeout ?? const Duration(seconds: 15),
       _now = now ?? DateTime.now {
    _webTimeout = webTimeout;
  }

  final CurrentLocationGateway _gateway;
  final bool _isWeb;
  final bool Function() _isWebSecureContext;
  final Duration _nativeTimeout;
  final DateTime Function() _now;
  late final Duration _webTimeout;

  @override
  bool get supportsAppSettings => _supportsNativeSettings(_isWeb);

  @override
  bool get supportsLocationSettings => _supportsNativeSettings(_isWeb);

  @override
  Future<CurrentLocation> locate() async {
    if (!_supportsLocationRequests(_isWeb)) {
      throw const CurrentLocationException(
        CurrentLocationFailure.unsupportedPlatform,
      );
    }
    if (_isWeb && !_isWebSecureContext()) {
      throw const CurrentLocationException(
        CurrentLocationFailure.insecureOrigin,
      );
    }
    try {
      final operation = _locateSupported();
      return _isWeb ? await operation.timeout(_webTimeout) : await operation;
    } on CurrentLocationException {
      rethrow;
    } catch (error) {
      throw _failureFor(error);
    }
  }

  Future<CurrentLocation> _locateSupported() async {
    try {
      if (!await _gateway.isLocationServiceEnabled()) {
        throw const CurrentLocationException(
          CurrentLocationFailure.serviceDisabled,
        );
      }

      var permission = await _gateway.checkPermission();
      if (_isWeb) {
        if (permission == CurrentLocationPermission.deniedForever) {
          throw const CurrentLocationException(
            CurrentLocationFailure.permissionDeniedForever,
          );
        }
        return _toCurrentLocation(await _gateway.getCurrentPosition());
      }

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
          return await _getFreshNativePosition();
      }
    } on CurrentLocationException {
      rethrow;
    } catch (error) {
      throw _failureFor(error);
    }
  }

  Future<CurrentLocation> _getFreshNativePosition() async {
    final requestedAt = _now().toUtc();
    final reading = await _gateway
        .getPositionStream()
        .where((position) => !position.timestamp.toUtc().isBefore(requestedAt))
        .first
        .timeout(_nativeTimeout);
    return _toCurrentLocation(reading);
  }

  @override
  Future<bool> openAppSettings() => _open(_gateway.openAppSettings);

  @override
  Future<bool> openLocationSettings() => _open(_gateway.openLocationSettings);

  Future<bool> _open(Future<bool> Function() action) async {
    if (!_supportsNativeSettings(_isWeb)) return false;
    try {
      return await action();
    } catch (_) {
      return false;
    }
  }
}

bool _supportsNativeSettings(bool isWeb) =>
    !isWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool _supportsLocationRequests(bool isWeb) =>
    isWeb || _supportsNativeSettings(isWeb);

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
  Future<CurrentLocationReading> getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return _toCurrentLocationReading(position);
    } on TimeoutException {
      throw const CurrentLocationException(CurrentLocationFailure.unavailable);
    } catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Stream<CurrentLocationReading> getPositionStream() =>
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).map(_toCurrentLocationReading);

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

CurrentLocation _toCurrentLocation(CurrentLocationReading reading) =>
    CurrentLocation(latitude: reading.latitude, longitude: reading.longitude);

CurrentLocationReading _toCurrentLocationReading(Position position) =>
    CurrentLocationReading(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
    );

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
  if (error is PermissionDeniedException) {
    return const CurrentLocationException(
      CurrentLocationFailure.permissionDenied,
    );
  }
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
