import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/geo_tag.dart';
import 'google_place_picker_map.dart';
import 'place_search_service.dart';

class PlacePickerScreen extends StatefulWidget {
  const PlacePickerScreen({
    super.key,
    required this.service,
    this.mapBuilder = buildConfiguredGooglePlacePickerMap,
    this.initialLocation,
  });

  final PlaceSearchService service;
  final PlacePickerMapBuilder mapBuilder;
  final GeoTag? initialLocation;

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  final _searchController = TextEditingController();
  List<PlaceSuggestion> _suggestions = const [];
  late GeoTag? _selected;
  bool _busy = false;
  String? _error;
  Future<void> Function()? _retry;
  int _operationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    final generation = ++_operationGeneration;
    setState(() {
      _busy = true;
      _error = null;
      _retry = null;
    });
    try {
      final suggestions = await widget.service.search(query);
      if (!mounted || generation != _operationGeneration) return;
      setState(() {
        _suggestions = suggestions;
        _busy = false;
      });
    } catch (error) {
      if (!mounted || generation != _operationGeneration) return;
      setState(() {
        _busy = false;
        _error = _errorMessage(error);
        _retry = () => _search(query);
      });
    }
  }

  Future<void> _resolve(PlaceSuggestion suggestion) async {
    final generation = ++_operationGeneration;
    setState(() {
      _busy = true;
      _error = null;
      _retry = null;
    });
    try {
      final location = await widget.service.resolvePlace(suggestion.placeId);
      if (!mounted || generation != _operationGeneration) return;
      setState(() {
        _selected = location;
        _busy = false;
      });
    } catch (error) {
      if (!mounted || generation != _operationGeneration) return;
      setState(() {
        _busy = false;
        _error = _errorMessage(error);
        _retry = () => _resolve(suggestion);
      });
    }
  }

  void _onPinDragged(GeoTag dragged) {
    final latitude = dragged.latitude;
    final longitude = dragged.longitude;
    final coordinate = GeoTag(
      latitude: latitude,
      longitude: longitude,
      placeName: _coordinateLabel(latitude, longitude),
    );
    setState(() => _selected = coordinate);
    unawaited(_reverseGeocode(latitude: latitude, longitude: longitude));
  }

  Future<void> _reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final generation = ++_operationGeneration;
    setState(() {
      _busy = true;
      _error = null;
      _retry = null;
    });
    try {
      final location = await widget.service.reverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );
      if (!mounted || generation != _operationGeneration) return;
      setState(() {
        _selected = location;
        _busy = false;
      });
    } catch (error) {
      if (!mounted || generation != _operationGeneration) return;
      setState(() {
        _busy = false;
        _error = _errorMessage(error);
        _retry = () =>
            _reverseGeocode(latitude: latitude, longitude: longitude);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('place-picker-cancel'),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Choose location'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('place-search-field'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (query) => unawaited(_search(query)),
              decoration: InputDecoration(
                labelText: 'Search for a place',
                suffixIcon: IconButton(
                  key: const Key('place-search-submit'),
                  tooltip: 'Search',
                  onPressed: () => unawaited(_search(_searchController.text)),
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(key: Key('place-picker-loading')),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Material(
                key: const Key('place-picker-error'),
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(_error!)),
                      TextButton(
                        key: const Key('place-picker-retry'),
                        onPressed: _busy || _retry == null
                            ? null
                            : () => unawaited(_retry!()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final suggestion in _suggestions)
                      ListTile(
                        key: Key('place-suggestion-${suggestion.placeId}'),
                        title: Text(suggestion.primaryText),
                        subtitle: _nonEmpty(suggestion.secondaryText) == null
                            ? null
                            : Text(suggestion.secondaryText!),
                        onTap: _busy
                            ? null
                            : () => unawaited(_resolve(suggestion)),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: widget.mapBuilder(
                selectedLocation: selected,
                onPinDragged: _onPinDragged,
              ),
            ),
            const SizedBox(height: 12),
            _SelectionCard(selected: selected),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('place-picker-confirm'),
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(context, selected),
              icon: const Icon(Icons.check),
              label: const Text('Use this location'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({required this.selected});

  final GeoTag? selected;

  @override
  Widget build(BuildContext context) {
    final location = selected;
    if (location == null) {
      return const Text(
        'Search for a place, then confirm it here. You can also tap the map '
        'or drag its pin.',
      );
    }

    final coordinate = _coordinateLabel(location.latitude, location.longitude);
    final name =
        _nonEmpty(location.placeName) ??
        _nonEmpty(location.formattedAddress) ??
        coordinate;
    final address = _nonEmpty(location.formattedAddress);
    return Card(
      key: const Key('place-picker-selection'),
      child: ListTile(
        leading: const Icon(Icons.place),
        title: Text(name, key: const Key('place-picker-selected-name')),
        subtitle: address == null || address == name
            ? null
            : Text(address, key: const Key('place-picker-selected-address')),
      ),
    );
  }
}

String _coordinateLabel(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _errorMessage(Object error) {
  if (error is PlaceSearchException) return error.message;
  return 'Place search is temporarily unavailable. Please try again.';
}
