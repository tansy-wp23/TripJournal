import 'dart:async';

import '../../models/geo_tag.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    this.secondaryText,
  });

  final String placeId;
  final String primaryText;
  final String? secondaryText;
}

class PlaceSearchException implements Exception {
  const PlaceSearchException(this.message, {this.code = 'provider_error'});

  final String message;
  final String code;

  @override
  String toString() => message;
}

abstract interface class PlaceSearchService {
  Future<List<PlaceSuggestion>> search(String query);

  Future<GeoTag> resolvePlace(String placeId);

  Future<GeoTag> reverseGeocode({
    required double latitude,
    required double longitude,
  });
}

typedef PlaceFunctionInvoker =
    Future<Map<String, dynamic>> Function(
      String action,
      Map<String, dynamic> body,
    );

class SupabasePlaceSearchService implements PlaceSearchService {
  factory SupabasePlaceSearchService({required PlaceFunctionInvoker invoke}) =>
      SupabasePlaceSearchService._(invoke);

  const SupabasePlaceSearchService._(this._invoke);

  static const _invalidRequest = PlaceSearchException(
    'The place request is invalid.',
    code: 'invalid_request',
  );
  static const _invalidResponse = PlaceSearchException(
    'The place service returned an invalid response.',
    code: 'invalid_response',
  );
  static const _providerFailure = PlaceSearchException(
    'Place search is temporarily unavailable. Please try again.',
    code: 'provider_error',
  );
  static const _timeout = PlaceSearchException(
    'Place lookup timed out. Please try again.',
    code: 'timeout',
  );

  final PlaceFunctionInvoker _invoke;

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.length < 2 || trimmed.length > 120) throw _invalidRequest;

    final payload = await _call('search', {'query': trimmed});
    final rows = payload['suggestions'];
    if (rows is! List) throw _invalidResponse;

    final suggestions = <PlaceSuggestion>[];
    for (final row in rows.take(5)) {
      if (row is! Map) throw _invalidResponse;
      final placeId = row['placeId'];
      final primaryText = row['primaryText'];
      final secondaryText = row['secondaryText'];
      if (placeId is! String ||
          placeId.trim().isEmpty ||
          primaryText is! String ||
          primaryText.trim().isEmpty ||
          !(secondaryText == null || secondaryText is String)) {
        throw _invalidResponse;
      }
      suggestions.add(
        PlaceSuggestion(
          placeId: placeId,
          primaryText: primaryText,
          secondaryText: secondaryText as String?,
        ),
      );
    }
    return List.unmodifiable(suggestions);
  }

  @override
  Future<GeoTag> resolvePlace(String placeId) async {
    final trimmed = placeId.trim();
    if (trimmed.isEmpty || trimmed.length > 300) throw _invalidRequest;
    return _locationFrom(await _call('resolve', {'placeId': trimmed}));
  }

  @override
  Future<GeoTag> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (!_validCoordinates(latitude, longitude)) throw _invalidRequest;
    return _locationFrom(
      await _call('reverse', {'latitude': latitude, 'longitude': longitude}),
    );
  }

  Future<Map<String, dynamic>> _call(
    String action,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _invoke(action, body);
    } on PlaceSearchException {
      rethrow;
    } on TimeoutException {
      throw _timeout;
    } catch (_) {
      throw _providerFailure;
    }
  }

  GeoTag _locationFrom(Map<String, dynamic> payload) {
    final raw = payload['location'];
    if (raw is! Map) throw _invalidResponse;

    final latitudeValue = raw['latitude'];
    final longitudeValue = raw['longitude'];
    final placeName = raw['placeName'];
    final formattedAddress = raw['formattedAddress'];
    final placeId = raw['placeId'];
    if (latitudeValue is! num ||
        longitudeValue is! num ||
        !(placeName == null || placeName is String) ||
        !(formattedAddress == null || formattedAddress is String) ||
        !(placeId == null || placeId is String)) {
      throw _invalidResponse;
    }

    final latitude = latitudeValue.toDouble();
    final longitude = longitudeValue.toDouble();
    if (!_validCoordinates(latitude, longitude)) throw _invalidResponse;

    return GeoTag(
      latitude: latitude,
      longitude: longitude,
      placeName: placeName as String?,
      formattedAddress: formattedAddress as String?,
      placeId: placeId as String?,
    );
  }

  static bool _validCoordinates(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
