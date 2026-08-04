import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/data/mock_trip_cover_storage.dart';
import 'package:tripjournal/data/supabase_trip_repository.dart';
import 'package:tripjournal/features/trip/controller/trip_controller.dart';
import 'package:tripjournal/models/trip.dart';

const _baseUrl = 'https://example.supabase.co';
const _userId = '11111111-1111-4111-8111-111111111111';

Map<String, dynamic> _tripRow({
  String id = '22222222-2222-4222-8222-222222222222',
  String? deletedAt,
}) {
  return {
    'id': id,
    'user_id': _userId,
    'title': 'Penang Weekend',
    'cover_photo_url': 'trip-covers/penang.jpg',
    'start_date': '2026-08-05',
    'end_date': '2026-08-07',
    'notes': 'Try the char kway teow.',
    'created_at': '2026-07-01T02:03:04.000Z',
    'updated_at': '2026-07-02T03:04:05.000Z',
    'deleted_at': deletedAt,
  };
}

Trip _trip() {
  return Trip(
    id: '22222222-2222-4222-8222-222222222222',
    userId: _userId,
    title: 'Penang Weekend',
    coverPhotoPath: 'trip-covers/penang.jpg',
    startDate: DateTime(2026, 8, 5),
    endDate: DateTime(2026, 8, 7),
    notes: 'Try the char kway teow.',
    createdAt: DateTime.utc(2026, 7, 1, 2, 3, 4),
    updatedAt: DateTime.utc(2026, 7, 2, 3, 4, 5),
  );
}

SupabaseTripRepository _repository(
  MockClient httpClient, {
  DateTime Function()? clock,
}) {
  final client = SupabaseClient(
    _baseUrl,
    'anon-key',
    httpClient: httpClient,
    accessToken: () async => 'test-token',
  );
  return SupabaseTripRepository(client, clock: clock);
}

http.Response _jsonResponse(
  Object body, {
  required http.BaseRequest request,
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
    request: request,
  );
}

void main() {
  group('queries', () {
    test(
      'getTrips filters by owner and active rows, then maps the response',
      () async {
        final repository = _repository(
          MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/rest/v1/trips');
            expect(request.url.queryParameters['select'], '*');
            expect(request.url.queryParameters['user_id'], 'eq.$_userId');
            expect(request.url.queryParameters['deleted_at'], 'is.null');
            return _jsonResponse([_tripRow()], request: request);
          }),
        );

        final trips = await repository.getTrips(_userId);

        expect(trips, hasLength(1));
        expect(trips.single.title, 'Penang Weekend');
        expect(trips.single.deletedAt, isNull);
      },
    );

    test(
      'getDeletedTrips requests deleted rows and filters expired results',
      () async {
        final now = DateTime.utc(2026, 8, 5, 12);
        final repository = _repository(
          MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.queryParameters['user_id'], 'eq.$_userId');
            expect(request.url.queryParameters['deleted_at'], 'not.is.null');
            return _jsonResponse([
              _tripRow(
                id: '33333333-3333-4333-8333-333333333333',
                deletedAt: now
                    .subtract(const Duration(days: 1))
                    .toIso8601String(),
              ),
              _tripRow(
                id: '44444444-4444-4444-8444-444444444444',
                deletedAt: now
                    .subtract(const Duration(days: 30))
                    .toIso8601String(),
              ),
            ], request: request);
          }),
          clock: () => now,
        );

        final trips = await repository.getDeletedTrips(_userId);

        expect(trips.map((trip) => trip.id), [
          '33333333-3333-4333-8333-333333333333',
        ]);
      },
    );

    test('getTrip filters by id and returns the maybeSingle row', () async {
      final trip = _trip();
      final repository = _repository(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.queryParameters['id'], 'eq.${trip.id}');
          return _jsonResponse(_tripRow(), request: request);
        }),
      );

      final result = await repository.getTrip(trip.id);

      expect(result?.id, trip.id);
    });
  });

  group('writes', () {
    test('addTrip inserts a snake_case row', () async {
      final trip = _trip();
      final repository = _repository(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/rest/v1/trips');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['user_id'], _userId);
          expect(body['cover_photo_url'], 'trip-covers/penang.jpg');
          expect(body['start_date'], '2026-08-05');
          expect(body['end_date'], '2026-08-07');
          expect(body, isNot(contains('userId')));
          expect(body, isNot(contains('startDate')));
          return _jsonResponse([], request: request);
        }),
      );

      await repository.addTrip(trip);
    });

    test('updateTrip updates by id with a snake_case row', () async {
      final trip = _trip();
      final repository = _repository(
        MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/rest/v1/trips');
          expect(request.url.queryParameters['id'], 'eq.${trip.id}');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['user_id'], _userId);
          expect(body['updated_at'], '2026-07-02T03:04:05.000Z');
          expect(body, isNot(contains('updatedAt')));
          return _jsonResponse([], request: request);
        }),
      );

      await repository.updateTrip(trip);
    });

    test(
      'moveToTrash invokes the move_trip_to_trash RPC with the trip id',
      () async {
        final trip = _trip();
        final repository = _repository(
          MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/rest/v1/rpc/move_trip_to_trash');
            expect(jsonDecode(request.body), {'p_trip_id': trip.id});
            return _jsonResponse([], request: request);
          }),
        );

        await repository.moveToTrash(trip.id);
      },
    );

    test(
      'restoreTrip invokes restore_trip with the full editable payload',
      () async {
        final trip = _trip();
        final repository = _repository(
          MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/rest/v1/rpc/restore_trip');
            expect(jsonDecode(request.body), {
              'p_trip_id': trip.id,
              'p_title': 'Penang Weekend',
              'p_cover_photo_url': 'trip-covers/penang.jpg',
              'p_start_date': '2026-08-05',
              'p_end_date': '2026-08-07',
              'p_notes': 'Try the char kway teow.',
            });
            return _jsonResponse([], request: request);
          }),
        );

        await repository.restoreTrip(trip);
      },
    );
  });

  test(
    'API errors reach TripController without replacing its loaded list',
    () async {
      var requestCount = 0;
      final repository = _repository(
        MockClient((request) async {
          requestCount++;
          if (requestCount == 1) {
            return _jsonResponse([_tripRow()], request: request);
          }
          return _jsonResponse(
            {'message': 'database unavailable'},
            request: request,
            statusCode: 500,
          );
        }),
      );
      final controller = TripController(
        repository,
        MockJournalRepository(),
        MockTripCoverStorage(),
      );

      await controller.loadTrips(_userId);
      final previouslyLoaded = controller.trips;
      await controller.loadTrips(_userId);

      expect(controller.trips, same(previouslyLoaded));
      expect(controller.trips.single.title, 'Penang Weekend');
      expect(controller.error, contains('database unavailable'));
    },
  );
}
