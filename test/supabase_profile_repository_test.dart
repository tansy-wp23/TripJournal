import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tripjournal/data/supabase_profile_repository.dart';
import 'package:tripjournal/models/profile.dart';

const _baseUrl = 'https://example.supabase.co';
const _userId = '11111111-1111-4111-8111-111111111111';

Map<String, dynamic> _profileRow({
  String status = 'active',
  String? deactivatedAt,
}) {
  return {
    'user_id': _userId,
    'email': 'sangyou@example.com',
    'display_name': 'Sang You',
    'avatar_url': 'profile-avatars/$_userId/avatar.jpg',
    'role': 'user',
    'status': status,
    'deactivated_at': deactivatedAt,
    'last_login_at': '2026-08-01T02:03:04.000Z',
    'created_at': '2026-07-01T02:03:04.000Z',
    'updated_at': '2026-07-02T03:04:05.000Z',
    'date_of_birth': '2000-05-07',
    'country': 'Malaysia',
    'travel_interests': ['Scenery', 'Food'],
    'profile_completed': true,
  };
}

Profile _profile() {
  return Profile(
    userID: _userId,
    email: 'sangyou@example.com',
    displayName: 'Sang You',
    avatarUrl: 'profile-avatars/$_userId/avatar.jpg',
    status: AccountStatus.active,
    lastLoginAt: DateTime.utc(2026, 8, 1, 2, 3, 4),
    createdAt: DateTime.utc(2026, 7, 1, 2, 3, 4),
    updatedAt: DateTime.utc(2026, 7, 2, 3, 4, 5),
  );
}

SupabaseProfileRepository _repository(MockClient httpClient) {
  final client = SupabaseClient(
    _baseUrl,
    'anon-key',
    httpClient: httpClient,
    accessToken: () async => 'test-token',
  );
  return SupabaseProfileRepository(client);
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
  group('getProfile', () {
    test('fetches the profile by user_id and maps the response', () async {
      final repository = _repository(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/rest/v1/profiles');
          expect(request.url.queryParameters['select'], '*');
          expect(request.url.queryParameters['user_id'], 'eq.$_userId');
          return _jsonResponse(_profileRow(), request: request);
        }),
      );

      final profile = await repository.getProfile(_userId);

      expect(profile, isNotNull);
      expect(profile!.userID, _userId);
      expect(profile.displayName, 'Sang You');
      expect(profile.status, AccountStatus.active);
      expect(profile.dateOfBirth, DateTime.parse('2000-05-07'));
      expect(profile.country, 'Malaysia');
      expect(profile.travelInterests, ['Scenery', 'Food']);
      expect(profile.profileCompleted, isTrue);
    });

    test('returns null when no profile exists', () async {
      final repository = _repository(
        MockClient((request) async {
          return _jsonResponse([], request: request);
        }),
      );

      final profile = await repository.getProfile(_userId);

      expect(profile, isNull);
    });
  });

  group('createProfileIfMissing', () {
    test('stamps last_login_at on an existing profile (no insert)', () async {
      var requestCount = 0;
      final repository = _repository(
        MockClient((request) async {
          requestCount++;
          if (requestCount == 1) {
            // GET — the existing profile.
            return _jsonResponse(_profileRow(), request: request);
          }
          // PATCH — updateProfile stamps last_login_at.
          expect(request.method, 'PATCH');
          expect(request.url.path, '/rest/v1/profiles');
          expect(request.url.queryParameters['user_id'], 'eq.$_userId');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['last_login_at'], isNotNull);
          expect(body, isNot(contains('user_id')));
          expect(body, isNot(contains('created_at')));
          expect(body, isNot(contains('updated_at')));
          return _jsonResponse(_profileRow(), request: request);
        }),
      );

      final profile = await repository.createProfileIfMissing(
        userId: _userId,
        email: 'sangyou@example.com',
        displayName: 'Sang You',
      );

      expect(profile.userID, _userId);
      expect(requestCount, 2);
    });

    test('inserts a new profile when none exists', () async {
      var requestCount = 0;
      final repository = _repository(
        MockClient((request) async {
          requestCount++;
          if (requestCount == 1) {
            return _jsonResponse([], request: request);
          }
          expect(request.method, 'POST');
          expect(request.url.path, '/rest/v1/profiles');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['user_id'], _userId);
          expect(body['email'], 'sangyou@example.com');
          expect(body['display_name'], 'Sang You');
          expect(body['status'], 'active');
          // Genuinely new profile — must route through onboarding once.
          expect(body['profile_completed'], isFalse);
          expect(body, isNot(contains('userID')));
          expect(body, isNot(contains('displayName')));
          return _jsonResponse(_profileRow(), request: request);
        }),
      );

      final profile = await repository.createProfileIfMissing(
        userId: _userId,
        email: 'sangyou@example.com',
        displayName: 'Sang You',
      );

      expect(profile.userID, _userId);
      expect(requestCount, 2);
    });
  });

  group('updateProfile', () {
    test('updates editable fields and maps the response', () async {
      final profile = _profile();
      final repository = _repository(
        MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/rest/v1/profiles');
          expect(request.url.queryParameters['user_id'], 'eq.$_userId');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['display_name'], 'Sang You');
          expect(body['status'], 'active');
          expect(body, isNot(contains('user_id')));
          expect(body, isNot(contains('created_at')));
          expect(body, isNot(contains('updated_at')));
          return _jsonResponse(_profileRow(), request: request);
        }),
      );

      final updated = await repository.updateProfile(profile);

      expect(updated.userID, _userId);
      expect(updated.displayName, 'Sang You');
    });
  });
}