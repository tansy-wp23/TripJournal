import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tripjournal/features/location/place_search_locator.dart';
import 'package:tripjournal/features/location/place_search_service.dart';

void main() {
  group('SupabasePlaceSearchService search', () {
    test(
      'a blank trimmed query returns no suggestions without invoking',
      () async {
        var invocationCount = 0;
        final service = SupabasePlaceSearchService(
          invoke: (_, _) async {
            invocationCount++;
            return const <String, dynamic>{};
          },
        );

        expect(await service.search(' \t\n '), isEmpty);
        expect(invocationCount, 0);
      },
    );

    test('trims the query and parses every suggestion field', () async {
      String? invokedAction;
      Map<String, dynamic>? invokedBody;
      final service = SupabasePlaceSearchService(
        invoke: (action, body) async {
          invokedAction = action;
          invokedBody = body;
          return {
            'suggestions': [
              {
                'placeId': 'ChIJLfySpTOuEmsRPCRKrzl8ZEY',
                'primaryText': 'Sydney Opera House',
                'secondaryText': 'Bennelong Point, Sydney NSW, Australia',
              },
            ],
          };
        },
      );

      final suggestions = await service.search('  Opera House  ');

      expect(invokedAction, 'search');
      expect(invokedBody, {'query': 'Opera House'});
      expect(suggestions, hasLength(1));
      expect(suggestions.single.placeId, 'ChIJLfySpTOuEmsRPCRKrzl8ZEY');
      expect(suggestions.single.primaryText, 'Sydney Opera House');
      expect(
        suggestions.single.secondaryText,
        'Bennelong Point, Sydney NSW, Australia',
      );
    });

    test(
      'rejects a malformed suggestions payload with a stable error',
      () async {
        final service = SupabasePlaceSearchService(
          invoke: (_, _) async => {
            'suggestions': [
              {
                'placeId': 'place-1',
                'primaryText': 42,
                'secondaryText': 'Not enough to make this valid',
              },
            ],
          },
        );

        await expectLater(
          service.search('valid query'),
          throwsA(
            isA<PlaceSearchException>()
                .having((error) => error.code, 'code', 'invalid_response')
                .having(
                  (error) => error.message,
                  'message',
                  isNot(contains('valid query')),
                ),
          ),
        );
      },
    );

    test('maps a timeout without exposing the original query', () async {
      const privateQuery = 'private medical clinic near my hotel';
      final service = SupabasePlaceSearchService(
        invoke: (_, _) => throw TimeoutException(privateQuery),
      );

      await expectLater(
        service.search(privateQuery),
        throwsA(
          isA<PlaceSearchException>()
              .having((error) => error.code, 'code', 'timeout')
              .having(
                (error) => error.message,
                'message',
                isNot(contains(privateQuery)),
              ),
        ),
      );
    });
  });

  group('SupabasePlaceSearchService location resolution', () {
    test('resolvePlace parses all five GeoTag fields', () async {
      final service = SupabasePlaceSearchService(
        invoke: (action, body) async {
          expect(action, 'resolve');
          expect(body, {'placeId': 'place-123'});
          return {
            'location': {
              'latitude': 35.0116,
              'longitude': 135.7681,
              'placeName': 'Gion',
              'formattedAddress': 'Gion, Higashiyama Ward, Kyoto, Japan',
              'placeId': 'place-123',
            },
          };
        },
      );

      final location = await service.resolvePlace(' place-123 ');

      expect(location.latitude, 35.0116);
      expect(location.longitude, 135.7681);
      expect(location.placeName, 'Gion');
      expect(location.formattedAddress, 'Gion, Higashiyama Ward, Kyoto, Japan');
      expect(location.placeId, 'place-123');
    });

    test(
      'reverseGeocode forwards valid coordinates and parses a GeoTag',
      () async {
        final service = SupabasePlaceSearchService(
          invoke: (action, body) async {
            expect(action, 'reverse');
            expect(body, {'latitude': 3.139, 'longitude': 101.6869});
            return {
              'location': {
                'latitude': 3.139,
                'longitude': 101.6869,
                'placeName': 'Kuala Lumpur City Centre',
                'formattedAddress': 'Kuala Lumpur, Malaysia',
                'placeId': null,
              },
            };
          },
        );

        final location = await service.reverseGeocode(
          latitude: 3.139,
          longitude: 101.6869,
        );

        expect(location.placeName, 'Kuala Lumpur City Centre');
        expect(location.placeId, isNull);
      },
    );

    test(
      'rejects non-finite and out-of-range coordinates before invoking',
      () async {
        var invocationCount = 0;
        final service = SupabasePlaceSearchService(
          invoke: (_, _) async {
            invocationCount++;
            return const <String, dynamic>{};
          },
        );

        for (final coordinates in [
          (latitude: 90.0001, longitude: 0.0),
          (latitude: -90.0001, longitude: 0.0),
          (latitude: 0.0, longitude: 180.0001),
          (latitude: 0.0, longitude: -180.0001),
          (latitude: double.nan, longitude: 0.0),
          (latitude: 0.0, longitude: double.infinity),
        ]) {
          await expectLater(
            service.reverseGeocode(
              latitude: coordinates.latitude,
              longitude: coordinates.longitude,
            ),
            throwsA(
              isA<PlaceSearchException>().having(
                (error) => error.code,
                'code',
                'invalid_request',
              ),
            ),
          );
        }
        expect(invocationCount, 0);
      },
    );

    test('rejects malformed or out-of-range location payloads', () async {
      final payloads = <Map<String, dynamic>>[
        {
          'location': {'latitude': 1.0},
        },
        {
          'location': {
            'latitude': 91.0,
            'longitude': 2.0,
            'placeName': 'Impossible',
            'formattedAddress': null,
            'placeId': null,
          },
        },
        {
          'location': {
            'latitude': 1.0,
            'longitude': 2.0,
            'placeName': <String>[],
            'formattedAddress': null,
            'placeId': null,
          },
        },
      ];

      for (final payload in payloads) {
        final service = SupabasePlaceSearchService(
          invoke: (_, _) async => payload,
        );
        await expectLater(
          service.resolvePlace('place-123'),
          throwsA(
            isA<PlaceSearchException>().having(
              (error) => error.code,
              'code',
              'invalid_response',
            ),
          ),
        );
      }
    });
  });

  group('production place-search locator', () {
    test('resolves lazily without requiring Supabase initialization', () {
      expect(placeSearchService, isA<SupabasePlaceSearchService>());
    });

    test(
      'maps non-2xx provider responses without leaking request details',
      () async {
        const privateQuery = 'home address on Cedar Street';
        String? functionName;
        Map<String, dynamic>? functionBody;
        final invoke = buildPlaceFunctionInvoker(
          call: (name, {required body}) async {
            functionName = name;
            functionBody = body;
            return const FunctionResponse(
              status: 502,
              data: {
                'error': {
                  'code': 'provider_error',
                  'message': 'Provider rejected home address on Cedar Street',
                },
              },
            );
          },
        );

        await expectLater(
          invoke('search', {'query': privateQuery}),
          throwsA(
            isA<PlaceSearchException>()
                .having((error) => error.code, 'code', 'provider_error')
                .having(
                  (error) => error.message,
                  'message',
                  isNot(contains(privateQuery)),
                ),
          ),
        );
        expect(functionName, 'places-proxy');
        expect(functionBody, {'action': 'search', 'query': privateQuery});
      },
    );

    test(
      'maps thrown function timeouts to the same sanitized contract',
      () async {
        const privateCoordinates = '3.139,101.6869';
        final invoke = buildPlaceFunctionInvoker(
          call: (_, {required body}) async => throw const FunctionException(
            status: 504,
            details: {
              'error': {
                'code': 'timeout',
                'message': 'Timed out resolving 3.139,101.6869',
              },
            },
          ),
        );

        await expectLater(
          invoke('reverse', {'latitude': 3.139, 'longitude': 101.6869}),
          throwsA(
            isA<PlaceSearchException>()
                .having((error) => error.code, 'code', 'timeout')
                .having(
                  (error) => error.message,
                  'message',
                  isNot(contains(privateCoordinates)),
                ),
          ),
        );
      },
    );
  });
}
