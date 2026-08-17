import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/geo_tag.dart';
import '../trip/map/google_trip_map_surface.dart';

typedef PlacePickerMapBuilder =
    Widget Function({
      required GeoTag? selectedLocation,
      required ValueChanged<GeoTag> onPinDragged,
    });

/// Selects the real Google map only when the current platform is configured.
/// Search and confirmation remain available through the fallback surface.
Widget buildConfiguredGooglePlacePickerMap({
  required GeoTag? selectedLocation,
  required ValueChanged<GeoTag> onPinDragged,
}) {
  if (!isGoogleMapsRenderingConfigured) {
    return PlacePickerMapUnavailableSurface(selectedLocation: selectedLocation);
  }
  return GooglePlacePickerMap(
    selectedLocation: selectedLocation,
    onPinDragged: onPinDragged,
  );
}

class PlacePickerMapUnavailableSurface extends StatelessWidget {
  const PlacePickerMapUnavailableSurface({
    super.key,
    required this.selectedLocation,
  });

  final GeoTag? selectedLocation;

  @override
  Widget build(BuildContext context) {
    final selected = selectedLocation;
    return DecoratedBox(
      key: const Key('place-picker-map-unavailable'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined),
              const SizedBox(height: 8),
              Text(
                'Map preview unavailable',
                style: Theme.of(context).textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Search still works, and a selected place can be confirmed.',
                textAlign: TextAlign.center,
              ),
              if (selected != null) ...[
                const SizedBox(height: 8),
                Text(
                  _coordinateLabel(selected.latitude, selected.longitude),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class GooglePlacePickerMap extends StatelessWidget {
  const GooglePlacePickerMap({
    super.key,
    required this.selectedLocation,
    required this.onPinDragged,
    this.platformBuilder = buildGooglePlacePickerPlatform,
  });

  final GeoTag? selectedLocation;
  final ValueChanged<GeoTag> onPinDragged;
  final PlacePickerMapBuilder platformBuilder;

  @override
  Widget build(BuildContext context) => platformBuilder(
    selectedLocation: selectedLocation,
    onPinDragged: onPinDragged,
  );
}

/// Builds the SDK-backed picker without enabling any current-location feature.
@visibleForTesting
Widget buildGooglePlacePickerPlatform({
  required GeoTag? selectedLocation,
  required ValueChanged<GeoTag> onPinDragged,
}) {
  final selected = selectedLocation;
  final target = selected == null
      ? const LatLng(0, 0)
      : LatLng(selected.latitude, selected.longitude);
  final marker = selected == null
      ? const <Marker>{}
      : {
          Marker(
            markerId: const MarkerId('selected-location'),
            position: target,
            draggable: true,
            onDragEnd: (position) => onPinDragged(
              GeoTag(
                latitude: position.latitude,
                longitude: position.longitude,
              ),
            ),
          ),
        };

  return GoogleMap(
    key: ValueKey('place-picker-map-${target.latitude},${target.longitude}'),
    initialCameraPosition: CameraPosition(
      target: target,
      zoom: selected == null ? 1.5 : 14,
    ),
    markers: marker,
    myLocationEnabled: false,
    myLocationButtonEnabled: false,
    onTap: (position) => onPinDragged(
      GeoTag(latitude: position.latitude, longitude: position.longitude),
    ),
  );
}

String _coordinateLabel(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
