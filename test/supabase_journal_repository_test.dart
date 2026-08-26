import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tripjournal/data/current_user_id_provider.dart';
import 'package:tripjournal/data/supabase_journal_repository.dart';
import 'package:tripjournal/models/geo_tag.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/mood.dart';
import 'package:tripjournal/models/portion_size.dart';

const _baseUrl = 'https://example.supabase.co';
const _userId = '11111111-1111-4111-8111-111111111111';
const _tripId = '22222222-2222-4222-8222-222222222222';
const _entryId = '33333333-3333-4333-8333-333333333333';
const _logId = '44444444-4444-4444-8444-444444444444';
const _mealId = '55555555-5555-4555-8555-555555555555';

final class _StubUserIdProvider implements CurrentUserIdProvider {
  _StubUserIdProvider({this.signedIn = true});

  final bool signedIn;

  @override
  String requireUserId() {
    if (!signedIn) throw const UnauthenticatedTripUserException();
    return _userId;
  }
}

Map<String, dynamic> _entryRow({
  Object? location,
  Object? healthLogs,
  String mood = 'happy',
}) {
  return {
    'id': _entryId,
    'user_id': _userId,
    'trip_id': _tripId,
    'title': 'Kek Lok Si',
    'body': 'Climbed all the way up.',
    'mood': mood,
    'photo_urls': ['https://cdn.example/a.jpg', 'https://cdn.example/b.jpg'],
    'location': location,
    'entry_date': '2026-08-06',
    'created_at': '2026-08-06T02:03:04.000Z',
    'updated_at': '2026-08-06T05:06:07.000Z',
    'health_logs': healthLogs ?? [_healthLogRow()],
  };
}

Map<String, dynamic> _healthLogRow({Object? meals}) {
  return {
    'id': _logId,
    'user_id': _userId,
    'entry_id': _entryId,
    'steps': 12000,
    'calories_eaten': 550,
    'calories_burned': 430,
    'ai_advice': 'Nice long walk today.',
    'meals': meals ?? [_mealRow()],
  };
}

Map<String, dynamic> _mealRow({
  String mealType = 'lunch',
  String portion = 'large',
  int? rating = 4,
}) {
  return {
    'id': _mealId,
    'user_id': _userId,
    'health_log_id': _logId,
    'name': 'Ramen',
    'calories': 550,
    'meal_type': mealType,
    'portion': portion,
    'photo_url': 'https://cdn.example/ramen.jpg',
    'rating': rating,
    'restaurant_name': 'Ichiran',
    'food_review': 'Rich broth.',
  };
}

JournalEntry _entry({HealthLog? healthLog, GeoTag? location}) {
  return JournalEntry(
    id: _entryId,
    tripId: _tripId,
    title: 'Kek Lok Si',
    body: 'Climbed all the way up.',
    mood: Mood.happy,
    photoPaths: const ['https://cdn.example/a.jpg'],
    location: location,
    createdAt: DateTime.utc(2026, 8, 6, 2, 3, 4),
    updatedAt: DateTime.utc(2026, 8, 6, 5, 6, 7),
    healthLog: healthLog,
  );
}

HealthLog _log({List<Meal> meals = const []}) {
  return HealthLog(
    id: _logId,
    entryId: _entryId,
    steps: 12000,
    caloriesEaten: 550,
    caloriesBurned: 430,
    meals: meals,
    aiAdvice: 'Nice long walk today.',
  );
}

Meal _meal() {
  return const Meal(
    id: _mealId,
    name: 'Ramen',
    calories: 550,
    mealType: MealType.lunch,
    portion: PortionSize.large,
    photoPath: 'https://cdn.example/ramen.jpg',
    rating: 4,
    restaurantName: 'Ichiran',
    foodReview: 'Rich broth.',
  );
}

SupabaseJournalRepository _repository(
  MockClient httpClient, {
  bool signedIn = true,
}) {
  final client = SupabaseClient(
    _baseUrl,
    'anon-key',
    httpClient: httpClient,
    accessToken: () async => 'test-token',
  );
  return SupabaseJournalRepository(
    client,
    _StubUserIdProvider(signedIn: signedIn),
  );
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

/// Records every request so a multi-table write can be asserted as a sequence.
class _Recorder {
  final List<http.Request> requests = [];

  MockClient client({Object Function(http.Request request)? respond}) {
    return MockClient((request) async {
      requests.add(request);
      return _jsonResponse(
        respond?.call(request) ?? <Object>[],
        request: request,
      );
    });
  }

  Iterable<String> get summary =>
      requests.map((request) => '${request.method} ${request.url.path}');

  http.Request at(int index) => requests[index];

  Map<String, dynamic> bodyAt(int index) =>
      jsonDecode(requests[index].body) as Map<String, dynamic>;

  List<dynamic> bodyListAt(int index) =>
      jsonDecode(requests[index].body) as List<dynamic>;
}

void main() {
  group('reads', () {
    test('getEntries embeds the log and meals, scoped to the trip', () async {
      final repository = _repository(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/rest/v1/journal_entries');
          expect(
            request.url.queryParameters['select'],
            '*,health_logs(*,meals(*))',
          );
          expect(request.url.queryParameters['trip_id'], 'eq.$_tripId');
          // Ascending matters: postgrest's `order` defaults to descending, so
          // without it the timeline would read newest-first here and
          // oldest-first on MockJournalRepository.
          expect(
            request.url.queryParameters['order'],
            'created_at.asc.nullslast',
          );
          return _jsonResponse([_entryRow()], request: request);
        }),
      );

      final entries = await repository.getEntries(_tripId);

      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry.id, _entryId);
      expect(entry.tripId, _tripId);
      expect(entry.mood, Mood.happy);
      expect(entry.photoPaths, [
        'https://cdn.example/a.jpg',
        'https://cdn.example/b.jpg',
      ]);
      expect(entry.createdAt, DateTime.utc(2026, 8, 6, 2, 3, 4));
    });

    test('getEntries maps the embedded health log and its meals', () async {
      final repository = _repository(
        MockClient(
          (request) async => _jsonResponse([_entryRow()], request: request),
        ),
      );

      final log = (await repository.getEntries(_tripId)).single.healthLog!;

      expect(log.id, _logId);
      expect(log.entryId, _entryId);
      expect(log.steps, 12000);
      expect(log.caloriesEaten, 550);
      expect(log.caloriesBurned, 430);
      expect(log.aiAdvice, 'Nice long walk today.');
      expect(log.meals, hasLength(1));
      expect(log.meals.single.name, 'Ramen');
      expect(log.meals.single.mealType, MealType.lunch);
      expect(log.meals.single.portion, PortionSize.large);
      expect(log.meals.single.photoPath, 'https://cdn.example/ramen.jpg');
      expect(log.meals.single.rating, 4);
      expect(log.meals.single.restaurantName, 'Ichiran');
      expect(log.meals.single.foodReview, 'Rich broth.');
    });

    test(
      'an entry with no health log maps to a null log, not a crash',
      () async {
        final repository = _repository(
          MockClient(
            (request) async => _jsonResponse([
              _entryRow(healthLogs: <Object>[]),
            ], request: request),
          ),
        );

        expect((await repository.getEntries(_tripId)).single.healthLog, isNull);
      },
    );

    test('the location jsonb blob round-trips into a GeoTag', () async {
      final repository = _repository(
        MockClient(
          (request) async => _jsonResponse([
            _entryRow(
              location: {
                'latitude': 5.4141,
                'longitude': 100.3288,
                'placeName': 'Kek Lok Si Temple',
                'formattedAddress': 'Air Itam, Penang',
                'placeId': 'ChIJabc',
              },
            ),
          ], request: request),
        ),
      );

      final location = (await repository.getEntries(_tripId)).single.location!;

      expect(location.latitude, 5.4141);
      expect(location.longitude, 100.3288);
      expect(location.placeName, 'Kek Lok Si Temple');
      expect(location.formattedAddress, 'Air Itam, Penang');
      expect(location.placeId, 'ChIJabc');
    });

    test(
      'a location blob missing coordinates drops the tag, keeping the entry',
      () async {
        // Latitude/longitude are the only non-optional parts of a GeoTag. Losing
        // the pin is recoverable; losing the whole day's writing is not.
        final repository = _repository(
          MockClient(
            (request) async => _jsonResponse([
              _entryRow(location: {'placeName': 'Somewhere'}),
            ], request: request),
          ),
        );

        final entry = (await repository.getEntries(_tripId)).single;

        expect(entry.location, isNull);
        expect(entry.title, 'Kek Lok Si');
      },
    );

    test('an out-of-range location drops the tag, keeping the entry', () async {
      final repository = _repository(
        MockClient(
          (request) async => _jsonResponse([
            _entryRow(location: {'latitude': 91, 'longitude': 100}),
          ], request: request),
        ),
      );

      final entry = (await repository.getEntries(_tripId)).single;

      expect(entry.location, isNull);
      expect(entry.title, 'Kek Lok Si');
    });

    test('an unknown enum name degrades instead of throwing', () async {
      // These columns are plain text, so a row written by a newer build (or by
      // hand in the SQL editor) can name a value this build has never seen.
      final repository = _repository(
        MockClient(
          (request) async => _jsonResponse([
            _entryRow(
              mood: 'euphoric',
              healthLogs: [
                _healthLogRow(
                  meals: [_mealRow(mealType: 'brunch', portion: 'gigantic')],
                ),
              ],
            ),
          ], request: request),
        ),
      );

      final entry = (await repository.getEntries(_tripId)).single;

      expect(entry.mood, Mood.neutral);
      expect(entry.healthLog!.meals.single.mealType, MealType.snack);
      expect(entry.healthLog!.meals.single.portion, PortionSize.regular);
    });

    test('getEntry filters by id and returns the maybeSingle row', () async {
      final repository = _repository(
        MockClient((request) async {
          expect(request.url.queryParameters['id'], 'eq.$_entryId');
          return _jsonResponse(_entryRow(), request: request);
        }),
      );

      expect((await repository.getEntry(_entryId))?.id, _entryId);
    });

    test('getEntry returns null for a row that is not there', () async {
      // maybeSingle() over an empty result set, which is what a deleted or
      // never-existing entry id produces.
      final repository = _repository(
        MockClient(
          (request) async => _jsonResponse(<Object>[], request: request),
        ),
      );

      expect(await repository.getEntry(_entryId), isNull);
    });
  });

  group('addEntry', () {
    test('saves entry, health log, and meals through one atomic RPC', () async {
      final recorder = _Recorder();
      final repository = _repository(recorder.client());

      await repository.addEntry(
        _entry(
          healthLog: _log(meals: [_meal()]),
          location: const GeoTag(latitude: 5.4, longitude: 100.3),
        ),
      );

      expect(recorder.requests, hasLength(1));
      expect(recorder.at(0).method, 'POST');
      expect(recorder.at(0).url.path, '/rest/v1/rpc/save_journal_entry_bundle');
      final body = recorder.bodyAt(0);
      final entryBody = body['p_entry'] as Map<String, dynamic>;
      expect(entryBody['id'], _entryId);
      expect(entryBody['trip_id'], _tripId);
      expect(entryBody['mood'], 'happy');
      expect(entryBody['photo_urls'], ['https://cdn.example/a.jpg']);
      expect(entryBody, isNot(contains('user_id')));
      expect(entryBody['location'], {
        'latitude': 5.4,
        'longitude': 100.3,
        'placeName': null,
        'formattedAddress': null,
        'placeId': null,
        'locationTag': null,
      });
      expect(entryBody['entry_date'], '2026-08-06');

      final logBody = body['p_health_log'] as Map<String, dynamic>;
      expect(logBody['id'], _logId);
      expect(logBody['entry_id'], _entryId);
      expect(logBody['calories_burned'], 430);
      expect(logBody, isNot(contains('user_id')));

      final mealBody =
          (body['p_meals'] as List<dynamic>).single as Map<String, dynamic>;
      expect(mealBody['health_log_id'], _logId);
      expect(mealBody['meal_type'], 'lunch');
      expect(mealBody['portion'], 'large');
      expect(mealBody['photo_url'], 'https://cdn.example/ramen.jpg');
      expect(mealBody['rating'], 4);
      expect(mealBody['restaurant_name'], 'Ichiran');
      expect(mealBody['food_review'], 'Rich broth.');
      expect(mealBody, isNot(contains('user_id')));
    });

    test('sends null health data without extra requests', () async {
      final recorder = _Recorder();
      final repository = _repository(recorder.client());

      await repository.addEntry(_entry());

      expect(recorder.requests, hasLength(1));
      final body = recorder.bodyAt(0);
      expect(body['p_health_log'], isNull);
      expect(body['p_meals'], isEmpty);
    });

    test('throws before writing anything when nobody is signed in', () async {
      // RLS would not reject this -- it would accept rows keyed to a user that
      // does not exist and then never return them again.
      final recorder = _Recorder();
      final repository = _repository(recorder.client(), signedIn: false);

      await expectLater(
        repository.addEntry(_entry()),
        throwsA(isA<UnauthenticatedTripUserException>()),
      );
      expect(recorder.requests, isEmpty);
    });
  });

  group('updateEntry', () {
    test('uses the same atomic bundle RPC as create', () async {
      final recorder = _Recorder();
      final repository = _repository(recorder.client());

      await repository.updateEntry(_entry(healthLog: _log(meals: [_meal()])));

      expect(recorder.requests, hasLength(1));
      expect(recorder.at(0).method, 'POST');
      expect(recorder.at(0).url.path, '/rest/v1/rpc/save_journal_entry_bundle');

      final body = recorder.bodyAt(0);
      final entryBody = body['p_entry'] as Map<String, dynamic>;
      expect(entryBody['id'], _entryId);
      expect(entryBody['trip_id'], _tripId);
      expect(entryBody['created_at'], '2026-08-06T02:03:04.000Z');
      expect(entryBody['updated_at'], '2026-08-06T05:06:07.000Z');
      expect(body['p_health_log'], isA<Map<String, dynamic>>());
      expect(body['p_meals'], hasLength(1));
    });
  });

  test('deleteEntry deletes by id', () async {
    final recorder = _Recorder();
    final repository = _repository(recorder.client());

    await repository.deleteEntry(_entryId);

    expect(recorder.summary, ['DELETE /rest/v1/journal_entries']);
    expect(recorder.at(0).url.queryParameters['id'], 'eq.$_entryId');
  });
}
