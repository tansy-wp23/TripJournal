import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'google_maps_web_sdk_state_stub.dart'
    if (dart.library.js_interop) 'google_maps_web_sdk_state_web.dart';
import 'trip_map_model.dart';
import 'trip_map_view.dart';

const String _googleMapsAndroidKey = String.fromEnvironment(
  'GOOGLE_MAPS_ANDROID_KEY',
);
const String _googleMapsIosKey = String.fromEnvironment('GOOGLE_MAPS_IOS_KEY');
const String _googleMapsWebKey = String.fromEnvironment('GOOGLE_MAPS_WEB_KEY');

/// The small controller boundary used by the surface after a platform map is
/// ready. It also keeps controller failures testable without a native map.
abstract interface class TripMapCameraController {
  Future<void> animateCamera(CameraUpdate update);
}

/// Builds the underlying platform map widget.
typedef GoogleTripMapPlatformBuilder =
    Widget Function({
      required CameraPosition initialCameraPosition,
      required Set<Marker> markers,
      required ValueChanged<TripMapCameraController> onMapCreated,
    });

/// Returns whether Google Maps can render on the selected platform.
///
/// Rendering keys are platform-restricted and intentionally checked
/// independently: an Android key must never enable the iOS or web surface. Web
/// also requires the bootstrap loader to have exposed a ready Maps SDK.
@visibleForTesting
bool googleMapsRenderingConfiguredForPlatform({
  required bool isWeb,
  required TargetPlatform platform,
  required String androidKey,
  required String iosKey,
  required String webKey,
  required bool webSdkReady,
}) {
  if (isWeb) return webKey.trim().isNotEmpty && webSdkReady;
  return switch (platform) {
    TargetPlatform.android => androidKey.trim().isNotEmpty,
    TargetPlatform.iOS => iosKey.trim().isNotEmpty,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => false,
  };
}

bool get isGoogleMapsRenderingConfigured =>
    googleMapsRenderingConfiguredForPlatform(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
      androidKey: _googleMapsAndroidKey,
      iosKey: _googleMapsIosKey,
      webKey: _googleMapsWebKey,
      webSdkReady: isGoogleMapsWebSdkReady,
    );

/// The builder consumed by [TripMapView]. Missing platform configuration is a
/// supported state, so it deterministically returns the navigable fallback.
Widget buildConfiguredTripMapSurface({
  required TripMapModel model,
  required ValueChanged<TripMapMarkerGroup> onSelected,
}) => _ConfiguredTripMapSurface(model: model, onSelected: onSelected);

class _ConfiguredTripMapSurface extends StatefulWidget {
  const _ConfiguredTripMapSurface({
    required this.model,
    required this.onSelected,
  });

  final TripMapModel model;
  final ValueChanged<TripMapMarkerGroup> onSelected;

  @override
  State<_ConfiguredTripMapSurface> createState() =>
      _ConfiguredTripMapSurfaceState();
}

class _ConfiguredTripMapSurfaceState extends State<_ConfiguredTripMapSurface> {
  @override
  Widget build(BuildContext context) {
    if (!isGoogleMapsRenderingConfigured) {
      return TripMapUnavailableSurface(
        model: widget.model,
        onSelected: widget.onSelected,
        onRetry: _retryConfiguration,
      );
    }
    return GoogleTripMapSurface(
      model: widget.model,
      onSelected: widget.onSelected,
    );
  }

  void _retryConfiguration() {
    // Build-time keys do not change within a release process. Re-evaluate the
    // platform gate anyway so Retry stays honest: the fallback remains until
    // the host is rebuilt/restarted with the current platform key.
    setState(() {});
  }
}

/// Builds Google markers for every visible map group.
@visibleForTesting
Set<Marker> googleTripMapMarkers({
  required TripMapModel model,
  required ValueChanged<TripMapMarkerGroup> onSelected,
}) => {
  for (final group in model.groups)
    Marker(
      markerId: MarkerId(group.key),
      position: LatLng(group.latitude, group.longitude),
      infoWindow: InfoWindow(title: 'D${group.dayNumber}'),
      onTap: () => onSelected(group),
    ),
};

/// Returns the camera update applied once the platform map is ready.
@visibleForTesting
CameraUpdate googleTripMapCameraUpdate(TripMapModel model) {
  assert(model.groups.isNotEmpty);
  final bounds = model.bounds;
  if (model.groups.length > 1 && bounds != null) {
    return CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(bounds.southWestLatitude, bounds.southWestLongitude),
        northeast: LatLng(bounds.northEastLatitude, bounds.northEastLongitude),
      ),
      48,
    );
  }

  final group = model.groups.first;
  return CameraUpdate.newLatLngZoom(
    LatLng(group.latitude, group.longitude),
    12,
  );
}

CameraPosition _initialCameraPosition(TripMapModel model) {
  final group = model.groups.first;
  return CameraPosition(
    target: LatLng(group.latitude, group.longitude),
    zoom: 12,
  );
}

/// Creates the real Google Maps widget while explicitly keeping GPS/current
/// location features disabled.
@visibleForTesting
Widget buildGoogleTripMapPlatform({
  required CameraPosition initialCameraPosition,
  required Set<Marker> markers,
  required ValueChanged<TripMapCameraController> onMapCreated,
}) => GoogleMap(
  initialCameraPosition: initialCameraPosition,
  markers: markers,
  myLocationEnabled: false,
  myLocationButtonEnabled: false,
  onMapCreated: (controller) =>
      onMapCreated(_GoogleTripMapCameraController(controller)),
);

class _GoogleTripMapCameraController implements TripMapCameraController {
  const _GoogleTripMapCameraController(this._controller);

  final GoogleMapController _controller;

  @override
  Future<void> animateCamera(CameraUpdate update) =>
      _controller.animateCamera(update);
}

/// Renders the trip marker groups with Google Maps.
///
/// Only errors returned by controller operations can be observed here. Google
/// tile authentication failures are reported by the native/web SDK and do not
/// surface as catchable Dart exceptions.
class GoogleTripMapSurface extends StatefulWidget {
  const GoogleTripMapSurface({
    super.key,
    required this.model,
    required this.onSelected,
    this.platformBuilder = buildGoogleTripMapPlatform,
  });

  final TripMapModel model;
  final ValueChanged<TripMapMarkerGroup> onSelected;
  final GoogleTripMapPlatformBuilder platformBuilder;

  @override
  State<GoogleTripMapSurface> createState() => _GoogleTripMapSurfaceState();
}

class _GoogleTripMapSurfaceState extends State<GoogleTripMapSurface> {
  TripMapCameraController? _controller;
  bool _cameraFailed = false;
  int _retryGeneration = 0;

  @override
  void didUpdateWidget(GoogleTripMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cameraFailed ||
        _controller == null ||
        _sameCameraTargets(oldWidget.model, widget.model)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _controller;
      if (mounted && controller != null && !_cameraFailed) {
        unawaited(_applyCamera(controller));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraFailed) {
      return TripMapUnavailableSurface(
        model: widget.model,
        onSelected: widget.onSelected,
        onRetry: _retry,
      );
    }

    return KeyedSubtree(
      key: ValueKey(_retryGeneration),
      child: widget.platformBuilder(
        initialCameraPosition: _initialCameraPosition(widget.model),
        markers: googleTripMapMarkers(
          model: widget.model,
          onSelected: widget.onSelected,
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }

  void _onMapCreated(TripMapCameraController controller) {
    _controller = controller;
    if (widget.model.groups.length > 1) {
      _applyCameraAfterLayout(controller);
      return;
    }
    unawaited(_applyCamera(controller));
  }

  void _applyCameraAfterLayout(TripMapCameraController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(controller, _controller) && !_cameraFailed) {
        unawaited(_applyCamera(controller));
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _applyCamera(TripMapCameraController controller) async {
    try {
      await controller.animateCamera(googleTripMapCameraUpdate(widget.model));
    } on Object {
      if (mounted && identical(controller, _controller)) {
        setState(() => _cameraFailed = true);
      }
    }
  }

  void _retry() {
    setState(() {
      _controller = null;
      _cameraFailed = false;
      _retryGeneration++;
    });
  }
}

bool _sameCameraTargets(TripMapModel a, TripMapModel b) {
  if (a.groups.length != b.groups.length) return false;
  for (var index = 0; index < a.groups.length; index++) {
    final left = a.groups[index];
    final right = b.groups[index];
    if (left.key != right.key ||
        left.latitude != right.latitude ||
        left.longitude != right.longitude) {
      return false;
    }
  }
  return true;
}
