import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tripjournal/data/current_user_id_provider.dart';
import 'package:tripjournal/data/supabase_photo_storage.dart';

const _baseUrl = 'https://example.supabase.co';
const _userId = '11111111-1111-4111-8111-111111111111';
const _tripId = '22222222-2222-4222-8222-222222222222';

final class _StubUserIdProvider implements CurrentUserIdProvider {
  _StubUserIdProvider({this.signedIn = true});

  final bool signedIn;

  @override
  String requireUserId() {
    if (!signedIn) throw const UnauthenticatedTripUserException();
    return _userId;
  }
}

XFile _photo({String name = 'shot.jpg'}) => XFile.fromData(
  Uint8List.fromList([1, 2, 3]),
  name: name,
  // Both: the io implementation derives `name` from `path`, so passing only
  // `name` leaves it empty and every case would fall back to jpeg.
  path: '/tmp/pick/$name',
);

SupabasePhotoStorage _storage(
  MockClient httpClient, {
  bool signedIn = true,
}) {
  final client = SupabaseClient(
    _baseUrl,
    'anon-key',
    httpClient: httpClient,
    accessToken: () async => 'test-token',
  );
  return SupabasePhotoStorage(client, _StubUserIdProvider(signedIn: signedIn));
}

http.Response _ok(http.BaseRequest request, [Object body = const {}]) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
    request: request,
  );
}

void main() {
  group('savePhoto', () {
    test('uploads under {userId}/{tripId}/, which is what RLS checks', () async {
      // storage_trip_mutation_allowed reads folder 1 as the owner uid and
      // parses folder 2 as a trip uuid the caller owns. A flat path is not a
      // tidiness question here -- the policy rejects it.
      late Uri uploaded;
      final storage = _storage(
        MockClient((request) async {
          uploaded = request.url;
          return _ok(request, {'Key': 'journal-photos/x'});
        }),
      );

      final result = await storage.savePhoto(_photo(), tripId: _tripId);

      expect(
        uploaded.path,
        startsWith('/storage/v1/object/journal-photos/$_userId/$_tripId/'),
      );
      expect(uploaded.path, endsWith('.jpg'));
      expect(
        result,
        startsWith(
          '$_baseUrl/storage/v1/object/public/journal-photos/'
          '$_userId/$_tripId/',
        ),
      );
    });

    test('maps the extension to a content type, defaulting to jpeg', () async {
      // The upload is multipart, so the file's own content type travels in the
      // part headers rather than on the request.
      final seen = <String, String>{};
      MockClient record(String key) => MockClient((request) async {
        seen[key] = request.body;
        return _ok(request, {'Key': 'journal-photos/x'});
      });

      await _storage(record('png')).savePhoto(
        _photo(name: 'a.PNG'),
        tripId: _tripId,
      );
      await _storage(record('webp')).savePhoto(
        _photo(name: 'a.webp'),
        tripId: _tripId,
      );
      await _storage(record('odd')).savePhoto(
        _photo(name: 'a.heic'),
        tripId: _tripId,
      );

      expect(seen['png'], contains('image/png'));
      expect(seen['webp'], contains('image/webp'));
      expect(seen['odd'], contains('image/jpeg'));
    });

    test('returns the picker path instead of throwing on a failed upload', () async {
      // The interface promises never to throw: the caller's catch aborts a
      // whole multi-select batch, so one rejected upload must not lose the
      // other photos the user picked.
      final storage = _storage(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'error': 'denied'}),
            403,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );

      final photo = XFile('/tmp/pick/meal.jpg');
      expect(
        await storage.savePhoto(photo, tripId: _tripId),
        '/tmp/pick/meal.jpg',
      );
    });

    test('degrades rather than throwing when nobody is signed in', () async {
      var called = false;
      final storage = _storage(
        MockClient((request) async {
          called = true;
          return _ok(request);
        }),
        signedIn: false,
      );

      expect(
        await storage.savePhoto(XFile('/tmp/x.jpg'), tripId: _tripId),
        '/tmp/x.jpg',
      );
      expect(called, isFalse);
    });
  });

  group('deletePhoto', () {
    test('removes the object named by one of our own public URLs', () async {
      List<dynamic>? removed;
      final storage = _storage(
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          removed = body['prefixes'] as List<dynamic>;
          return _ok(request, []);
        }),
      );

      await storage.deletePhoto(
        '$_baseUrl/storage/v1/object/public/journal-photos/'
        '$_userId/$_tripId/entry-abc.jpg',
      );

      expect(removed, ['$_userId/$_tripId/entry-abc.jpg']);
    });

    test('ignores paths it never wrote', () async {
      // An entry can hold a mix of local paths and Storage URLs after a mode
      // switch or a failed upload.
      var called = false;
      final storage = _storage(
        MockClient((request) async {
          called = true;
          return _ok(request, []);
        }),
      );

      await storage.deletePhoto(null);
      await storage.deletePhoto('');
      await storage.deletePhoto('/data/user/0/app/files/photo.jpg');
      await storage.deletePhoto('assets/mock/ramen_lunch.jpg');
      await storage.deletePhoto(
        'https://evil.example/storage/v1/object/public/journal-photos/a/b.jpg',
      );
      await storage.deletePhoto(
        '$_baseUrl/storage/v1/object/public/trip-covers/$_userId/x.jpg',
      );

      expect(called, isFalse);
    });

    test('refuses a URL smuggling a separator through percent-encoding', () async {
      var called = false;
      final storage = _storage(
        MockClient((request) async {
          called = true;
          return _ok(request, []);
        }),
      );

      await storage.deletePhoto(
        '$_baseUrl/storage/v1/object/public/journal-photos/'
        '$_userId%2F..%2Fother.jpg',
      );

      expect(called, isFalse);
    });

    test('a failed remove is swallowed -- the entry already dropped it', () async {
      final storage = _storage(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'error': 'nope'}),
            500,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );

      await expectLater(
        storage.deletePhoto(
          '$_baseUrl/storage/v1/object/public/journal-photos/'
          '$_userId/$_tripId/entry-abc.jpg',
        ),
        completes,
      );
    });
  });
}
