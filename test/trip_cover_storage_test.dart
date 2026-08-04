import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

import 'package:tripjournal/data/mock_trip_cover_storage.dart';
import 'package:tripjournal/data/supabase_trip_cover_storage.dart';

const _baseUrl = 'https://example.supabase.co';
const _userId = '00000000-0000-0000-0000-000000000001';
const _tripId = '550e8400-e29b-41d4-a716-446655440000';
const _coverId = '7d9f2f8f-4a77-4f08-b64f-21cfa2f609a1';

final class _FixedUuid extends Uuid {
  const _FixedUuid();

  @override
  String v4({Map<String, dynamic>? options, V4Options? config}) => _coverId;
}

SupabaseTripCoverStorage _storage(MockClient httpClient) {
  final client = SupabaseClient(
    _baseUrl,
    'anon-key',
    httpClient: httpClient,
    accessToken: () async => 'test-token',
  );
  return SupabaseTripCoverStorage(client, const _FixedUuid());
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
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'trip-cover-storage-test-',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  group('MockTripCoverStorage', () {
    test('returns the local path and accepts deletion as a no-op', () async {
      final storage = MockTripCoverStorage();

      final result = await storage.uploadCover(
        userId: _userId,
        tripId: _tripId,
        localPath: r'C:\photos\cover.JPG',
      );
      await storage.deleteCoverUrl('https://example.com/cover.jpg');

      expect(result, r'C:\photos\cover.JPG');
    });
  });

  group('SupabaseTripCoverStorage upload', () {
    test(
      'normalizes a supported extension and uploads to the owner/trip path',
      () async {
        final file = File('${temporaryDirectory.path}/cover.JPG');
        await file.writeAsBytes([1, 2, 3]);
        const objectPath = '$_userId/$_tripId/cover-$_coverId.jpg';
        final storage = _storage(
          MockClient((request) async {
            expect(request.method, 'POST');
            expect(
              request.url.path,
              '/storage/v1/object/trip-covers/$objectPath',
            );
            expect(request.headers['x-upsert'], 'false');
            expect(request.body, contains('name="cacheControl"'));
            expect(request.body, contains('3600'));
            return _jsonResponse({
              'Key': 'trip-covers/$objectPath',
            }, request: request);
          }),
        );

        final publicUrl = await storage.uploadCover(
          userId: _userId,
          tripId: _tripId,
          localPath: file.path,
        );

        expect(
          publicUrl,
          '$_baseUrl/storage/v1/object/public/trip-covers/$objectPath',
        );
      },
    );

    test('preserves every supported lowercase extension', () async {
      for (final extension in ['jpg', 'jpeg', 'png', 'webp']) {
        final file = File('${temporaryDirectory.path}/cover.$extension');
        await file.writeAsBytes([1]);
        final expectedSuffix = 'cover-$_coverId.$extension';
        final storage = _storage(
          MockClient((request) async {
            expect(request.url.pathSegments.last, expectedSuffix);
            return _jsonResponse({'Key': expectedSuffix}, request: request);
          }),
        );

        await storage.uploadCover(
          userId: _userId,
          tripId: _tripId,
          localPath: file.path,
        );
      }
    });

    test('uses jpg when the local extension is unsupported', () async {
      final file = File('${temporaryDirectory.path}/cover.gif');
      await file.writeAsBytes([1]);
      final storage = _storage(
        MockClient((request) async {
          expect(request.url.pathSegments.last, 'cover-$_coverId.jpg');
          return _jsonResponse({'Key': 'cover.jpg'}, request: request);
        }),
      );

      await storage.uploadCover(
        userId: _userId,
        tripId: _tripId,
        localPath: file.path,
      );
    });
  });

  group('SupabaseTripCoverStorage deletion', () {
    test(
      'removes the object path parsed from a trip-covers public URL',
      () async {
        const objectPath = '$_userId/$_tripId/cover-$_coverId.webp';
        final storage = _storage(
          MockClient((request) async {
            expect(request.method, 'DELETE');
            expect(request.url.path, '/storage/v1/object/trip-covers');
            expect(jsonDecode(request.body), {
              'prefixes': [objectPath],
            });
            return _jsonResponse([], request: request);
          }),
        );

        await storage.deleteCoverUrl(
          '$_baseUrl/storage/v1/object/public/trip-covers/$objectPath?download=1',
        );
      },
    );

    test('ignores null and URLs outside the exact public bucket path', () async {
      var requests = 0;
      final storage = _storage(
        MockClient((request) async {
          requests++;
          return _jsonResponse([], request: request);
        }),
      );

      await storage.deleteCoverUrl(null);
      await storage.deleteCoverUrl('https://example.com/cover.jpg');
      await storage.deleteCoverUrl(
        '$_baseUrl/storage/v1/object/public/journal-photos/$_coverId.jpg',
      );
      await storage.deleteCoverUrl(
        '$_baseUrl/storage/v1/object/public/trip-covers-malicious/$_coverId.jpg',
      );
      await storage.deleteCoverUrl(
        '$_baseUrl/not-storage?next=/storage/v1/object/public/trip-covers/$_coverId.jpg',
      );

      expect(requests, 0);
    });
  });
}
