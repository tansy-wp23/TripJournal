import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'trip_cover_storage.dart';

const _bucketName = 'trip-covers';
const _publicPathPrefix = '/storage/v1/object/public/$_bucketName/';
const _supportedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

final class SupabaseTripCoverStorage implements TripCoverStorage {
  SupabaseTripCoverStorage(this._client, [this._uuid = const Uuid()]);

  final SupabaseClient _client;
  final Uuid _uuid;

  @override
  Future<String> uploadCover({
    required String userId,
    required String tripId,
    required String localPath,
  }) async {
    final supportedExtension = _supportedExtension(localPath);
    final extension = supportedExtension ?? 'jpg';
    final objectPath = '$userId/$tripId/cover-${_uuid.v4()}.$extension';
    final bucket = _client.storage.from(_bucketName);

    if (supportedExtension != null) {
      await bucket.upload(
        objectPath,
        File(localPath),
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: false,
          contentType: _contentTypeFor(supportedExtension),
        ),
      );
    } else {
      final jpegBytes = await _transcodeToJpeg(localPath);
      await bucket.uploadBinary(
        objectPath,
        jpegBytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
          contentType: 'image/jpeg',
        ),
      );
    }

    return bucket.getPublicUrl(objectPath);
  }

  @override
  Future<void> deleteCoverUrl(String? publicUrl) async {
    final objectPath = _objectPathFromPublicUrl(
      publicUrl,
      storageUri: Uri.parse(_client.storage.url),
    );
    if (objectPath == null) return;

    await _client.storage.from(_bucketName).remove([objectPath]);
  }
}

String? _supportedExtension(String localPath) {
  final fileName = localPath.replaceAll('\\', '/').split('/').last;
  final dotIndex = fileName.lastIndexOf('.');
  final extension = dotIndex < 0
      ? ''
      : fileName.substring(dotIndex + 1).toLowerCase();
  return _supportedExtensions.contains(extension) ? extension : null;
}

String _contentTypeFor(String extension) {
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => throw ArgumentError.value(extension, 'extension'),
  };
}

Future<Uint8List> _transcodeToJpeg(String localPath) async {
  final result = await FlutterImageCompress.compressWithFile(
    localPath,
    format: CompressFormat.jpeg,
  );
  if (result == null || !_isJpeg(result)) {
    throw StateError('Cover image could not be converted to JPEG.');
  }
  return result;
}

bool _isJpeg(Uint8List bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[bytes.length - 2] == 0xff &&
      bytes[bytes.length - 1] == 0xd9;
}

String? _objectPathFromPublicUrl(String? publicUrl, {required Uri storageUri}) {
  if (publicUrl == null) return null;

  final uri = Uri.tryParse(publicUrl);
  if (uri == null ||
      uri.userInfo.isNotEmpty ||
      uri.scheme != storageUri.scheme ||
      uri.host != storageUri.host ||
      uri.port != storageUri.port) {
    return null;
  }

  final schemeSeparator = publicUrl.indexOf('://');
  if (schemeSeparator < 0) return null;
  final pathStart = publicUrl.indexOf('/', schemeSeparator + 3);
  if (pathStart < 0) return null;

  final queryStart = publicUrl.indexOf('?', pathStart);
  final fragmentStart = publicUrl.indexOf('#', pathStart);
  final pathEnd = [
    if (queryStart >= 0) queryStart,
    if (fragmentStart >= 0) fragmentStart,
    publicUrl.length,
  ].reduce((first, second) => first < second ? first : second);
  final rawPath = publicUrl.substring(pathStart, pathEnd);
  if (!rawPath.startsWith(_publicPathPrefix)) return null;

  final encodedObjectPath = rawPath.substring(_publicPathPrefix.length);
  final lowercaseObjectPath = encodedObjectPath.toLowerCase();
  if (encodedObjectPath.isEmpty ||
      lowercaseObjectPath.contains('%2f') ||
      lowercaseObjectPath.contains('%5c')) {
    return null;
  }

  final objectPath = Uri.decodeComponent(encodedObjectPath);
  final objectSegments = objectPath.split('/');
  if (objectSegments.any((segment) => segment.isEmpty)) return null;
  return objectPath;
}
