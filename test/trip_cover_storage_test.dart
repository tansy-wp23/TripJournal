import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
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

final class _TestImageCompressPlatform extends UnsupportedFlutterImageCompress {
  _TestImageCompressPlatform(this._compress);

  final Future<Uint8List?> Function(String path) _compress;
  int calls = 0;
  CompressFormat? requestedFormat;

  @override
  Future<Uint8List?> compressWithFile(
    String path, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) async {
    calls++;
    requestedFormat = format;
    return _compress(path);
  }
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

int _indexOfBytes(List<int> bytes, List<int> pattern, [int start = 0]) {
  for (var index = start; index <= bytes.length - pattern.length; index++) {
    var matches = true;
    for (var offset = 0; offset < pattern.length; offset++) {
      if (bytes[index + offset] != pattern[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return index;
  }
  return -1;
}

Uint8List _uploadedFileBytes(http.BaseRequest request) {
  final contentType = request.headers['content-type']!;
  final boundary = RegExp(r'boundary=(.+)$').firstMatch(contentType)!.group(1)!;
  final body = (request as http.Request).bodyBytes;
  final filenameStart = _indexOfBytes(body, utf8.encode('filename="'));
  final contentStartMarker = utf8.encode('\r\n\r\n');
  final contentStart =
      _indexOfBytes(body, contentStartMarker, filenameStart) +
      contentStartMarker.length;
  final contentEnd = _indexOfBytes(
    body,
    utf8.encode('\r\n--$boundary'),
    contentStart,
  );
  return Uint8List.fromList(body.sublist(contentStart, contentEnd));
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
        final sourceBytes = Uint8List.fromList([1, 2, 3, 4]);
        await file.writeAsBytes(sourceBytes);
        final expectedSuffix = 'cover-$_coverId.$extension';
        final storage = _storage(
          MockClient((request) async {
            expect(request.url.pathSegments.last, expectedSuffix);
            expect(_uploadedFileBytes(request), sourceBytes);
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
      final source = image.Image(width: 2, height: 2)
        ..setPixelRgb(0, 0, 255, 0, 0)
        ..setPixelRgb(1, 0, 0, 255, 0)
        ..setPixelRgb(0, 1, 0, 0, 255)
        ..setPixelRgb(1, 1, 255, 255, 255);
      final gifBytes = image.encodeGif(source);
      await file.writeAsBytes(gifBytes);
      final previousPlatform = FlutterImageCompressPlatform.instance;
      final platform = _TestImageCompressPlatform((path) async {
        final decoded = image.decodeImage(await File(path).readAsBytes());
        return Uint8List.fromList(image.encodeJpg(decoded!));
      });
      FlutterImageCompressPlatform.instance = platform;
      addTearDown(() {
        FlutterImageCompressPlatform.instance = previousPlatform;
      });
      final storage = _storage(
        MockClient((request) async {
          expect(request.url.pathSegments.last, 'cover-$_coverId.jpg');
          expect(
            latin1.decode(request.bodyBytes).toLowerCase(),
            contains('content-type: image/jpeg'),
          );
          final uploadedBytes = _uploadedFileBytes(request);
          expect(uploadedBytes, isNot(gifBytes));
          expect(image.JpegDecoder().isValidFile(uploadedBytes), isTrue);
          return _jsonResponse({'Key': 'cover.jpg'}, request: request);
        }),
      );

      await storage.uploadCover(
        userId: _userId,
        tripId: _tripId,
        localPath: file.path,
      );

      expect(platform.calls, 1);
      expect(platform.requestedFormat, CompressFormat.jpeg);
    });

    test('transcodes HEIC input before uploading JPEG bytes', () async {
      final file = File('${temporaryDirectory.path}/cover.HEIC');
      final heicBytes = Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x18,
        ...ascii.encode('ftypheic'),
        0x00,
        0x00,
        0x00,
        0x00,
      ]);
      await file.writeAsBytes(heicBytes);
      final jpegBytes = Uint8List.fromList(
        image.encodeJpg(image.Image(width: 1, height: 1)),
      );
      final previousPlatform = FlutterImageCompressPlatform.instance;
      final platform = _TestImageCompressPlatform((path) async => jpegBytes);
      FlutterImageCompressPlatform.instance = platform;
      addTearDown(() {
        FlutterImageCompressPlatform.instance = previousPlatform;
      });
      final storage = _storage(
        MockClient((request) async {
          expect(request.url.pathSegments.last, 'cover-$_coverId.jpg');
          expect(
            latin1.decode(request.bodyBytes).toLowerCase(),
            contains('content-type: image/jpeg'),
          );
          final uploadedBytes = _uploadedFileBytes(request);
          expect(uploadedBytes, jpegBytes);
          expect(image.JpegDecoder().isValidFile(uploadedBytes), isTrue);
          return _jsonResponse({'Key': 'cover.jpg'}, request: request);
        }),
      );

      await storage.uploadCover(
        userId: _userId,
        tripId: _tripId,
        localPath: file.path,
      );

      expect(platform.calls, 1);
      expect(platform.requestedFormat, CompressFormat.jpeg);
    });

    test('does not upload or create files when transcoding fails', () async {
      final file = File('${temporaryDirectory.path}/cover.gif');
      await file.writeAsBytes(ascii.encode('GIF89a'));
      final previousPlatform = FlutterImageCompressPlatform.instance;
      final platform = _TestImageCompressPlatform((path) async {
        throw const FileSystemException('conversion failed');
      });
      FlutterImageCompressPlatform.instance = platform;
      addTearDown(() {
        FlutterImageCompressPlatform.instance = previousPlatform;
      });
      var requests = 0;
      final storage = _storage(
        MockClient((request) async {
          requests++;
          return _jsonResponse({'Key': 'unexpected'}, request: request);
        }),
      );

      await expectLater(
        storage.uploadCover(
          userId: _userId,
          tripId: _tripId,
          localPath: file.path,
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(requests, 0);
      final remainingFiles = temporaryDirectory.listSync();
      expect(remainingFiles, hasLength(1));
      expect(
        FileSystemEntity.identicalSync(remainingFiles.single.path, file.path),
        isTrue,
      );
    });

    test('rejects non-JPEG transcoder output before upload', () async {
      final file = File('${temporaryDirectory.path}/cover.heic');
      final heicBytes = Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x18,
        ...ascii.encode('ftypheic'),
      ]);
      await file.writeAsBytes(heicBytes);
      final previousPlatform = FlutterImageCompressPlatform.instance;
      final platform = _TestImageCompressPlatform((path) async => heicBytes);
      FlutterImageCompressPlatform.instance = platform;
      addTearDown(() {
        FlutterImageCompressPlatform.instance = previousPlatform;
      });
      var requests = 0;
      final storage = _storage(
        MockClient((request) async {
          requests++;
          return _jsonResponse({'Key': 'unexpected'}, request: request);
        }),
      );

      await expectLater(
        storage.uploadCover(
          userId: _userId,
          tripId: _tripId,
          localPath: file.path,
        ),
        throwsStateError,
      );

      expect(platform.calls, 1);
      expect(requests, 0);
      final remainingFiles = temporaryDirectory.listSync();
      expect(remainingFiles, hasLength(1));
      expect(
        FileSystemEntity.identicalSync(remainingFiles.single.path, file.path),
        isTrue,
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
      await storage.deleteCoverUrl(
        '$_baseUrl/not-storage#/storage/v1/object/public/trip-covers/$_coverId.jpg',
      );

      expect(requests, 0);
    });

    test('ignores public paths from a different storage origin', () async {
      var requests = 0;
      final storage = _storage(
        MockClient((request) async {
          requests++;
          return _jsonResponse([], request: request);
        }),
      );
      const objectPath = '$_userId/$_tripId/cover-$_coverId.jpg';

      await storage.deleteCoverUrl(
        'https://attacker.example/storage/v1/object/public/trip-covers/$objectPath',
      );
      await storage.deleteCoverUrl(
        'https://example.supabase.co.attacker.example/storage/v1/object/public/trip-covers/$objectPath',
      );
      await storage.deleteCoverUrl(
        'https:/storage/v1/object/public/trip-covers/$objectPath',
      );
      await storage.deleteCoverUrl(
        'http://example.supabase.co/storage/v1/object/public/trip-covers/$objectPath',
      );
      await storage.deleteCoverUrl(
        'https://example.supabase.co:444/storage/v1/object/public/trip-covers/$objectPath',
      );

      expect(requests, 0);
    });

    test('ignores encoded storage or bucket prefix characters', () async {
      var requests = 0;
      final storage = _storage(
        MockClient((request) async {
          requests++;
          return _jsonResponse([], request: request);
        }),
      );
      const objectPath = '$_userId/$_tripId/cover-$_coverId.jpg';

      await storage.deleteCoverUrl(
        '$_baseUrl/%73torage/v1/object/public/trip-covers/$objectPath',
      );
      await storage.deleteCoverUrl(
        '$_baseUrl/storage/v1/object/public/%74rip-covers/$objectPath',
      );
      await storage.deleteCoverUrl(
        '$_baseUrl/storage%2Fv1/object/public/trip-covers/$objectPath',
      );

      expect(requests, 0);
    });

    test('accepts an explicit default port for the storage origin', () async {
      const objectPath = '$_userId/$_tripId/cover-$_coverId.jpg';
      var requests = 0;
      final storage = _storage(
        MockClient((request) async {
          requests++;
          expect(jsonDecode(request.body), {
            'prefixes': [objectPath],
          });
          return _jsonResponse([], request: request);
        }),
      );

      await storage.deleteCoverUrl(
        'https://example.supabase.co:443/storage/v1/object/public/trip-covers/$objectPath',
      );

      expect(requests, 1);
    });
  });
}
