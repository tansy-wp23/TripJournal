import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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

// A transparent 48px north-facing arrow, rendered at 24 logical pixels and
// rotated to the route segment's local course by Google Maps.
final BitmapDescriptor _tripMapArrowIcon = BitmapDescriptor.bytes(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAD+SURBVGhD7c9BCsJAFARRT+oBPK4XUlwI8hBtzWQ6gRTUJiH9K6fTwcG2OV+uN5/thkf8U99tntf43f2E4bv6CYPf6TebwdBP+m0dAxPdqGHYL7o1HYP+0c1pGLJEt6dgxBLdXh0DRuiN1fDwSL01HA+uoTeH4aE19fZiPDBDG/7G4Zna8jMONrQpxqGmtn3FgS1o4zA8lOpODcNS3alhWKo7NQxLdaeGYanu1DAs1Z0ahqW6U8OwVHdqGJbqTg3DUt2pYViqOzUMS3WnhmGp7tQwLNWdGoalulPDsFR3ahiW6k4Nw1LdqWFYqjs1DEt1p4Zhqe7UMCzVnYODAncGH/uLcvDJmQAAAABJRU5ErkJggg==',
  ),
  width: 24,
  height: 24,
);

const int tripMapClusterThreshold = 20;
const ClusterManagerId _tripEntryClusterManagerId = ClusterManagerId(
  'trip-entry-markers',
);

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
      required Set<Polyline> polylines,
      required Set<Marker> arrowMarkers,
      required Set<ClusterManager> clusterManagers,
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
}) {
  final clusterManagerId = model.groups.length > tripMapClusterThreshold
      ? _tripEntryClusterManagerId
      : null;
  return {
    for (final group in model.groups)
      Marker(
        markerId: MarkerId(group.key),
        position: LatLng(group.latitude, group.longitude),
        clusterManagerId: clusterManagerId,
        alpha: 1,
        icon: BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(title: 'D${group.dayNumber}'),
        onTap: () => onSelected(group),
      ),
  };
}

@visibleForTesting
Set<ClusterManager> googleTripMapClusterManagers(
  TripMapModel model, {
  required ValueChanged<Cluster> onClusterTap,
}) => model.groups.length > tripMapClusterThreshold
    ? {
        ClusterManager(
          clusterManagerId: _tripEntryClusterManagerId,
          onClusterTap: onClusterTap,
        ),
      }
    : const {};

/// Builds one plain line for every entry-ordered route segment. Direction is drawn
/// separately by [googleTripMapArrowMarkers] so platform-specific caps are not
/// required.
@visibleForTesting
Set<Polyline> googleTripMapPolylines(TripMapModel model) => {
  for (final segment in model.routeSegments)
    Polyline(
      polylineId: PolylineId(segment.id),
      points: [
        LatLng(segment.fromLatitude, segment.fromLongitude),
        LatLng(segment.toLatitude, segment.toLongitude),
      ],
      color: const Color(0xFF5E6AD2),
      geodesic: true,
      width: 4,
      zIndex: 1,
    ),
};

/// Builds an independently rotated marker near each route segment destination.
@visibleForTesting
Set<Marker> googleTripMapArrowMarkers(TripMapModel model) => {
  for (final segment in model.routeSegments) _googleTripMapArrowMarker(segment),
};

Marker _googleTripMapArrowMarker(TripMapRouteSegment segment) {
  final position = _arrowPosition(segment);
  return Marker(
    markerId: MarkerId('${segment.id}-arrow'),
    position: position,
    alpha: 0.9,
    anchor: const Offset(0.5, 0.5),
    flat: true,
    icon: _tripMapArrowIcon,
    rotation: _bearingDegrees(
      from: position,
      toLatitude: segment.toLatitude,
      toLongitude: segment.toLongitude,
    ),
    zIndexInt: 2,
  );
}

LatLng _arrowPosition(TripMapRouteSegment segment) {
  const progress = 0.82;
  final fromLatitude = _radians(segment.fromLatitude);
  final fromLongitude = _radians(segment.fromLongitude);
  final toLatitude = _radians(segment.toLatitude);
  final toLongitude = _radians(segment.toLongitude);
  final from = (
    math.cos(fromLatitude) * math.cos(fromLongitude),
    math.cos(fromLatitude) * math.sin(fromLongitude),
    math.sin(fromLatitude),
  );
  final to = (
    math.cos(toLatitude) * math.cos(toLongitude),
    math.cos(toLatitude) * math.sin(toLongitude),
    math.sin(toLatitude),
  );
  final dot = (from.$1 * to.$1 + from.$2 * to.$2 + from.$3 * to.$3).clamp(
    -1.0,
    1.0,
  );
  final angle = math.acos(dot);
  if (angle == 0) {
    return LatLng(segment.toLatitude, segment.toLongitude);
  }
  final angleSin = math.sin(angle);
  final fromWeight = math.sin((1 - progress) * angle) / angleSin;
  final toWeight = math.sin(progress * angle) / angleSin;
  final x = fromWeight * from.$1 + toWeight * to.$1;
  final y = fromWeight * from.$2 + toWeight * to.$2;
  final z = fromWeight * from.$3 + toWeight * to.$3;
  return LatLng(
    math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi,
    math.atan2(y, x) * 180 / math.pi,
  );
}

double _bearingDegrees({
  required LatLng from,
  required double toLatitude,
  required double toLongitude,
}) {
  final fromLatitude = _radians(from.latitude);
  final targetLatitude = _radians(toLatitude);
  final longitudeDelta = _radians(toLongitude - from.longitude);
  final y = math.sin(longitudeDelta) * math.cos(targetLatitude);
  final x =
      math.cos(fromLatitude) * math.sin(targetLatitude) -
      math.sin(fromLatitude) *
          math.cos(targetLatitude) *
          math.cos(longitudeDelta);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double _radians(double degrees) => degrees * math.pi / 180;

/// Returns the camera update applied once the platform map is ready.
@visibleForTesting
CameraUpdate googleTripMapCameraUpdate(TripMapModel model) {
  assert(model.groups.isNotEmpty);
  final bounds = model.bounds;
  if (bounds != null) {
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
    // 12 (city-level) was too far out for Google's default style to reliably
    // label landmarks/POIs at a single stop — 15 is street-level, where they
    // consistently render.
    15,
  );
}

CameraPosition _initialCameraPosition(TripMapModel model) {
  final group = model.groups.first;
  return CameraPosition(
    target: LatLng(group.latitude, group.longitude),
    zoom: 15,
  );
}

/// Creates the real Google Maps widget while explicitly keeping GPS/current
/// location features disabled.
@visibleForTesting
Widget buildGoogleTripMapPlatform({
  required CameraPosition initialCameraPosition,
  required Set<Marker> markers,
  required Set<Polyline> polylines,
  required Set<Marker> arrowMarkers,
  required Set<ClusterManager> clusterManagers,
  required ValueChanged<TripMapCameraController> onMapCreated,
}) => GoogleMap(
  initialCameraPosition: initialCameraPosition,
  markers: {...markers, ...arrowMarkers},
  polylines: polylines,
  clusterManagers: clusterManagers,
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
        polylines: googleTripMapPolylines(widget.model),
        arrowMarkers: googleTripMapArrowMarkers(widget.model),
        clusterManagers: googleTripMapClusterManagers(
          widget.model,
          onClusterTap: _onClusterTap,
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }

  void _onMapCreated(TripMapCameraController controller) {
    _controller = controller;
    if (widget.model.bounds != null) {
      _applyCameraAfterLayout(controller);
      return;
    }
    unawaited(_applyCamera(controller));
  }

  void _onClusterTap(Cluster cluster) {
    final controller = _controller;
    if (controller == null || _cameraFailed) return;
    unawaited(
      controller
          .animateCamera(CameraUpdate.newLatLngBounds(cluster.bounds, 48))
          .catchError((Object _) {
            if (mounted && identical(controller, _controller)) {
              setState(() => _cameraFailed = true);
            }
          }),
    );
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
  if (a.routeSegments.length != b.routeSegments.length) return false;
  for (var index = 0; index < a.routeSegments.length; index++) {
    final left = a.routeSegments[index];
    final right = b.routeSegments[index];
    if (left.fromLatitude != right.fromLatitude ||
        left.fromLongitude != right.fromLongitude ||
        left.toLatitude != right.toLatitude ||
        left.toLongitude != right.toLongitude) {
      return false;
    }
  }
  return true;
}
