import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/geo_tag.dart';

typedef PlacePickerMapBuilder =
    Widget Function({
      required GeoTag? selectedLocation,
      required ValueChanged<GeoTag> onPinMoved,
    });

/// OSM tiles need no API key, so this always renders the real map - there is
/// no more "unconfigured" fallback state to check for.
Widget buildConfiguredPlacePickerMap({
  required GeoTag? selectedLocation,
  required ValueChanged<GeoTag> onPinMoved,
}) => PlacePickerMap(selectedLocation: selectedLocation, onPinMoved: onPinMoved);

/// The interactive pin-picker map. Tap anywhere to move the pin -
/// `flutter_map` has no draggable-marker primitive, and a tap covers the same
/// need in fewer gestures than a drag did. Unlike the old Google platform
/// view, this is a pure Dart widget: it does not need
/// `EagerGestureRecognizer` to win pan/pinch away from the enclosing
/// `ListView`, because there is no platform view swallowing those gestures.
class PlacePickerMap extends StatefulWidget {
  const PlacePickerMap({
    super.key,
    required this.selectedLocation,
    required this.onPinMoved,
  });

  final GeoTag? selectedLocation;
  final ValueChanged<GeoTag> onPinMoved;

  @override
  State<PlacePickerMap> createState() => _PlacePickerMapState();
}

class _PlacePickerMapState extends State<PlacePickerMap> {
  final _controller = MapController();

  @override
  void didUpdateWidget(PlacePickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameCoordinates(oldWidget.selectedLocation, widget.selectedLocation)) {
      return;
    }
    final selected = widget.selectedLocation;
    if (selected == null) return;
    // A plain move() - no remount needed. `flutter_map` isn't a platform
    // view, so there's no "initial camera only applies once" limitation to
    // work around the way the old Google surface's KeyedSubtree hack did.
    _controller.move(
      ll.LatLng(selected.latitude, selected.longitude),
      _controller.camera.zoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedLocation;
    final target = selected == null
        ? const ll.LatLng(0, 0)
        : ll.LatLng(selected.latitude, selected.longitude);

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: target,
        initialZoom: selected == null ? 1.5 : 14,
        onTap: (_, point) => widget.onPinMoved(
          GeoTag(latitude: point.latitude, longitude: point.longitude),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.tripjournal.tripjournal',
        ),
        if (selected != null)
          MarkerLayer(
            markers: [
              Marker(
                point: target,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  color: Color(0xFF5E6AD2),
                  size: 36,
                ),
              ),
            ],
          ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}

bool _sameCoordinates(GeoTag? left, GeoTag? right) =>
    left?.latitude == right?.latitude && left?.longitude == right?.longitude;
