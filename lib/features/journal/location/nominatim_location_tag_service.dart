import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/geo_tag.dart';
import 'location_tag_service.dart';

class NominatimLocationTagService implements LocationTagService {
  NominatimLocationTagService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<GeoTag> enrich(GeoTag location) async {
    if (location.locationTag != null && location.placeName != null) {
      return location;
    }

    if (location.placeName != null) {
      return location.copyWith(
        locationTag: locationTagForPlaceName(location.placeName!),
      );
    }

    final response = await _client.get(
      Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': location.latitude.toString(),
        'lon': location.longitude.toString(),
        'zoom': '10',
        'addressdetails': '1',
      }),
      headers: const {'User-Agent': 'TripJournal/1.0'},
    );

    if (response.statusCode != 200) {
      throw Exception('Reverse geocoding failed (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final address = json['address'] as Map<String, dynamic>?;
    final placeName = _placeName(address) ?? json['display_name'] as String?;
    if (placeName == null || placeName.trim().isEmpty) {
      throw Exception('Reverse geocoding returned no place name.');
    }

    return location.copyWith(
      placeName: placeName,
      locationTag: locationTagForPlaceName(placeName),
    );
  }

  String? _placeName(Map<String, dynamic>? address) {
    if (address == null) return null;
    for (final key in const [
      'city',
      'town',
      'village',
      'municipality',
      'county',
      'state',
    ]) {
      final value = address[key] as String?;
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }
}
