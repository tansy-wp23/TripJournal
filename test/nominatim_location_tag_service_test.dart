import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tripjournal/features/journal/location/nominatim_location_tag_service.dart';
import 'package:tripjournal/models/geo_tag.dart';

void main() {
  test('sends a compliant User-Agent identifying the app with a contact route', () async {
    String? sentUserAgent;
    final client = MockClient((request) async {
      sentUserAgent = request.headers['user-agent'];
      return http.Response('{"display_name": "Kyoto, Japan"}', 200);
    });
    final service = NominatimLocationTagService(client: client);

    await service.enrich(const GeoTag(latitude: 35.0, longitude: 135.7));

    expect(sentUserAgent, isNotNull);
    expect(sentUserAgent, startsWith('TripJournal/'));
    // Nominatim's usage policy requires a contact route, not just a name/version.
    expect(sentUserAgent, contains('http'));
  });

  test('prefers city over state when both are present in the address', () async {
    final client = MockClient(
      (request) async => http.Response(
        '{"address": {"state": "Kyoto Prefecture", "city": "Kyoto"}, '
        '"display_name": "Kyoto, Kyoto Prefecture, Japan"}',
        200,
      ),
    );
    final service = NominatimLocationTagService(client: client);

    final result = await service.enrich(
      const GeoTag(latitude: 35.0, longitude: 135.7),
    );

    expect(result.placeName, 'Kyoto');
    expect(result.locationTag, '#Kyoto');
  });

  test('falls back to display_name when no preferred address field matches', () async {
    final client = MockClient(
      (request) async => http.Response(
        '{"address": {"postcode": "600-8216"}, "display_name": "Somewhere, Japan"}',
        200,
      ),
    );
    final service = NominatimLocationTagService(client: client);

    final result = await service.enrich(
      const GeoTag(latitude: 35.0, longitude: 135.7),
    );

    expect(result.placeName, 'Somewhere, Japan');
  });

  test('throws on a non-200 response', () async {
    final client = MockClient((request) async => http.Response('', 503));
    final service = NominatimLocationTagService(client: client);

    expect(
      () => service.enrich(const GeoTag(latitude: 35.0, longitude: 135.7)),
      throwsException,
    );
  });

  test('throws when the response has no usable place name', () async {
    final client = MockClient((request) async => http.Response('{}', 200));
    final service = NominatimLocationTagService(client: client);

    expect(
      () => service.enrich(const GeoTag(latitude: 35.0, longitude: 135.7)),
      throwsException,
    );
  });

  test('makes no HTTP call when placeName and locationTag are already set', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      return http.Response('{}', 200);
    });
    final service = NominatimLocationTagService(client: client);

    final result = await service.enrich(
      const GeoTag(
        latitude: 35.0,
        longitude: 135.7,
        placeName: 'Kyoto',
        locationTag: '#Kyoto',
      ),
    );

    expect(calls, 0);
    expect(result.placeName, 'Kyoto');
  });

  test('derives the tag locally (no HTTP call) when only placeName is set', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      return http.Response('{}', 200);
    });
    final service = NominatimLocationTagService(client: client);

    final result = await service.enrich(
      const GeoTag(latitude: 35.0, longitude: 135.7, placeName: 'Gion'),
    );

    expect(calls, 0);
    expect(result.locationTag, '#Gion');
  });
}
