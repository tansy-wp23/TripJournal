import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'trip_map_model.dart';
import 'trip_map_view.dart';

const int tripMapClusterThreshold = 20;

/// The small controller boundary used by the surface once the platform map is
/// ready. Keeps camera failures testable without a real [FlutterMap].
abstract interface class TripMapCameraController {
  void moveTo(ll.LatLng target, double zoom);
  void fitBounds(LatLngBounds bounds, {double padding});
}

/// One rendered entry-group marker plus the tap handler that selects it.
/// `flutter_map`'s own [Marker] carries no tap callback (unlike Google's), so
/// this is the equivalent of what `googleTripMapMarkers` used to return.
@immutable
class TripMapMarkerSpec {
  const TripMapMarkerSpec({
    required this.key,
    required this.point,
    required this.dayLabel,
    required this.onTap,
  });

  final String key;
  final ll.LatLng point;
  final String dayLabel;
  final VoidCallback onTap;
}

/// One rendered direction-arrow marker.
@immutable
class TripMapArrowSpec {
  const TripMapArrowSpec({
    required this.key,
    required this.point,
    required this.bearingDegrees,
  });

  final String key;
  final ll.LatLng point;
  final double bearingDegrees;
}

/// Either a single-point zoom or a bounds fit - the two camera moves the
/// surface ever makes.
sealed class TripMapCameraTarget {
  const TripMapCameraTarget();
}

class TripMapCameraZoom extends TripMapCameraTarget {
  const TripMapCameraZoom(this.center, this.zoom);
  final ll.LatLng center;
  final double zoom;
}

class TripMapCameraBounds extends TripMapCameraTarget {
  const TripMapCameraBounds(this.bounds, this.padding);
  final LatLngBounds bounds;
  final double padding;
}

/// Builds the underlying platform map widget.
typedef OsmTripMapPlatformBuilder =
    Widget Function({
      required ll.LatLng initialCenter,
      required double initialZoom,
      required List<Marker> markers,
      required List<Marker> arrowMarkers,
      required List<Polyline> polylines,
      required bool clustered,
      required MapController mapController,
      required ValueChanged<TripMapCameraController> onMapReady,
    });

/// OSM tiles need no API key, so this always renders the real map - the
/// `_ConfiguredTripMapSurface` gate that used to check for a Google Maps key
/// is gone. [TripMapUnavailableSurface] stays reachable only through a
/// genuine camera failure inside [OsmTripMapSurface].
Widget buildConfiguredTripMapSurface({
  required TripMapModel model,
  required ValueChanged<TripMapMarkerGroup> onSelected,
}) => OsmTripMapSurface(model: model, onSelected: onSelected);

/// Builds the marker specs for every visible map group.
@visibleForTesting
List<TripMapMarkerSpec> osmTripMapMarkers({
  required TripMapModel model,
  required ValueChanged<TripMapMarkerGroup> onSelected,
}) => [
  for (final group in model.groups)
    TripMapMarkerSpec(
      key: group.key,
      point: ll.LatLng(group.latitude, group.longitude),
      dayLabel: 'D${group.dayNumber}',
      onTap: () => onSelected(group),
    ),
];

/// Builds one plain line for every entry-ordered route segment. Direction is
/// drawn separately by [osmTripMapArrowMarkers].
///
/// ponytail: flutter_map draws polyline points as straight Web Mercator
/// segments, not the true geodesic Google Maps drew. Invisible at city scale;
/// upgrade to a geodesic-interpolated point list if a trip ever spans a
/// genuinely long (intercontinental) leg.
@visibleForTesting
List<Polyline> osmTripMapPolylines(TripMapModel model) => [
  for (final segment in model.routeSegments)
    Polyline(
      points: [
        ll.LatLng(segment.fromLatitude, segment.fromLongitude),
        ll.LatLng(segment.toLatitude, segment.toLongitude),
      ],
      color: const Color(0xFF5E6AD2),
      strokeWidth: 4,
    ),
];

/// Builds one direction-arrow spec near each route segment's destination.
@visibleForTesting
List<TripMapArrowSpec> osmTripMapArrowMarkers(TripMapModel model) => [
  for (final segment in model.routeSegments) _arrowSpecFor(segment),
];

TripMapArrowSpec _arrowSpecFor(TripMapRouteSegment segment) {
  final position = _arrowPosition(segment);
  return TripMapArrowSpec(
    key: '${segment.id}-arrow',
    point: position,
    bearingDegrees: _bearingDegrees(
      from: position,
      toLatitude: segment.toLatitude,
      toLongitude: segment.toLongitude,
    ),
  );
}

ll.LatLng _arrowPosition(TripMapRouteSegment segment) {
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
    return ll.LatLng(segment.toLatitude, segment.toLongitude);
  }
  final angleSin = math.sin(angle);
  final fromWeight = math.sin((1 - progress) * angle) / angleSin;
  final toWeight = math.sin(progress * angle) / angleSin;
  final x = fromWeight * from.$1 + toWeight * to.$1;
  final y = fromWeight * from.$2 + toWeight * to.$2;
  final z = fromWeight * from.$3 + toWeight * to.$3;
  return ll.LatLng(
    math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi,
    math.atan2(y, x) * 180 / math.pi,
  );
}

double _bearingDegrees({
  required ll.LatLng from,
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

/// Returns the camera move applied once the platform map is ready.
@visibleForTesting
TripMapCameraTarget osmTripMapCameraTarget(TripMapModel model) {
  assert(model.groups.isNotEmpty);
  final bounds = model.bounds;
  if (bounds != null) {
    return TripMapCameraBounds(
      LatLngBounds(
        ll.LatLng(bounds.southWestLatitude, bounds.southWestLongitude),
        ll.LatLng(bounds.northEastLatitude, bounds.northEastLongitude),
      ),
      48,
    );
  }

  final group = model.groups.first;
  return TripMapCameraZoom(
    ll.LatLng(group.latitude, group.longitude),
    // 12 (city-level) was too far out to reliably show street-level detail
    // at a single stop - 15 is street-level.
    15,
  );
}

(ll.LatLng, double) _initialCamera(TripMapModel model) {
  final group = model.groups.first;
  return (ll.LatLng(group.latitude, group.longitude), 15);
}

Marker _markerFromSpec(TripMapMarkerSpec spec) => Marker(
  key: ValueKey(spec.key),
  point: spec.point,
  width: 40,
  height: 40,
  child: GestureDetector(
    key: Key('trip-map-marker-${spec.key}'),
    onTap: spec.onTap,
    child: Tooltip(
      message: spec.dayLabel,
      child: const Icon(Icons.location_pin, color: Color(0xFF5E6AD2), size: 36),
    ),
  ),
);

Marker _arrowMarkerFromSpec(TripMapArrowSpec spec) => Marker(
  key: ValueKey(spec.key),
  point: spec.point,
  width: 24,
  height: 24,
  child: Transform.rotate(
    angle: spec.bearingDegrees * math.pi / 180,
    child: const DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF5E6AD2),
      ),
      child: Icon(Icons.navigation, color: Colors.white, size: 16),
    ),
  ),
);

class _ClusterBadge extends StatelessWidget {
  const _ClusterBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0xFF5E6AD2),
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

/// Creates the real flutter_map widget while keeping GPS/current-location
/// features off (this surface never needs them).
@visibleForTesting
Widget buildOsmTripMapPlatform({
  required ll.LatLng initialCenter,
  required double initialZoom,
  required List<Marker> markers,
  required List<Marker> arrowMarkers,
  required List<Polyline> polylines,
  required bool clustered,
  required MapController mapController,
  required ValueChanged<TripMapCameraController> onMapReady,
}) {
  return FlutterMap(
    mapController: mapController,
    options: MapOptions(
      initialCenter: initialCenter,
      initialZoom: initialZoom,
      onMapReady: () => onMapReady(_OsmTripMapCameraController(mapController)),
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.tripjournal.tripjournal',
      ),
      PolylineLayer(polylines: polylines),
      MarkerLayer(markers: arrowMarkers),
      if (clustered)
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            size: const Size(40, 40),
            markers: markers,
            builder: (context, clusterMarkers) =>
                _ClusterBadge(count: clusterMarkers.length),
          ),
        )
      else
        MarkerLayer(markers: markers),
      const RichAttributionWidget(
        attributions: [TextSourceAttribution('OpenStreetMap contributors')],
      ),
    ],
  );
}

class _OsmTripMapCameraController implements TripMapCameraController {
  _OsmTripMapCameraController(this._controller);

  final MapController _controller;

  @override
  void moveTo(ll.LatLng target, double zoom) => _controller.move(target, zoom);

  @override
  void fitBounds(LatLngBounds bounds, {double padding = 48}) {
    _controller.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: EdgeInsets.all(padding)),
    );
  }
}

/// Renders the trip marker groups with OpenStreetMap tiles.
///
/// `flutter_map`'s controller calls are synchronous local widget-tree
/// operations, not native platform-channel calls, so they don't fail the way
/// Google Maps' SDK calls occasionally did. The try/catch below is defensive
/// (a controller call before the map has attached) rather than a real
/// "provider unavailable" path - but it keeps [TripMapUnavailableSurface]
/// genuinely reachable rather than dead code.
class OsmTripMapSurface extends StatefulWidget {
  const OsmTripMapSurface({
    super.key,
    required this.model,
    required this.onSelected,
    this.platformBuilder = buildOsmTripMapPlatform,
  });

  final TripMapModel model;
  final ValueChanged<TripMapMarkerGroup> onSelected;
  final OsmTripMapPlatformBuilder platformBuilder;

  @override
  State<OsmTripMapSurface> createState() => _OsmTripMapSurfaceState();
}

class _OsmTripMapSurfaceState extends State<OsmTripMapSurface> {
  // Owned here, not inside buildOsmTripMapPlatform, and reused across every
  // rebuild (a day-filter toggle rebuilds this widget with a new model).
  // flutter_map treats a changed MapController identity as a real controller
  // swap - it detaches/reattaches internally, which was silently breaking
  // the tile pipeline (tiles stopped loading) on every model change when a
  // fresh MapController was handed to FlutterMap each time.
  var _mapController = MapController();
  TripMapCameraController? _controller;
  bool _cameraFailed = false;
  int _retryGeneration = 0;

  @override
  void didUpdateWidget(OsmTripMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cameraFailed ||
        _controller == null ||
        _sameCameraTargets(oldWidget.model, widget.model)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _controller;
      if (mounted && controller != null && !_cameraFailed) {
        _applyCamera(controller);
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

    final (initialCenter, initialZoom) = _initialCamera(widget.model);
    return KeyedSubtree(
      key: ValueKey(_retryGeneration),
      child: widget.platformBuilder(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        markers: osmTripMapMarkers(
          model: widget.model,
          onSelected: widget.onSelected,
        ).map(_markerFromSpec).toList(),
        arrowMarkers: osmTripMapArrowMarkers(
          widget.model,
        ).map(_arrowMarkerFromSpec).toList(),
        polylines: osmTripMapPolylines(widget.model),
        clustered: widget.model.groups.length > tripMapClusterThreshold,
        mapController: _mapController,
        onMapReady: _onMapReady,
      ),
    );
  }

  void _onMapReady(TripMapCameraController controller) {
    _controller = controller;
    if (widget.model.bounds != null) {
      _applyCameraAfterLayout(controller);
      return;
    }
    _applyCamera(controller);
  }

  void _applyCameraAfterLayout(TripMapCameraController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(controller, _controller) && !_cameraFailed) {
        _applyCamera(controller);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _applyCamera(TripMapCameraController controller) {
    try {
      final target = osmTripMapCameraTarget(widget.model);
      switch (target) {
        case TripMapCameraZoom(:final center, :final zoom):
          controller.moveTo(center, zoom);
        case TripMapCameraBounds(:final bounds, :final padding):
          controller.fitBounds(bounds, padding: padding);
      }
    } on Object {
      if (mounted && identical(controller, _controller)) {
        setState(() => _cameraFailed = true);
      }
    }
  }

  void _retry() {
    setState(() {
      _mapController.dispose();
      _mapController = MapController();
      _controller = null;
      _cameraFailed = false;
      _retryGeneration++;
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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
