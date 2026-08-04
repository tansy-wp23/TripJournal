import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'trip_cover_storage.dart';

const _bucketName = 'trip-covers';
const _publicPathPrefix = <String>[
  'storage',
  'v1',
  'object',
  'public',
  _bucketName,
];
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
    final extension = _normalizedExtension(localPath);
    final objectPath = '$userId/$tripId/cover-${_uuid.v4()}.$extension';
    final bucket = _client.storage.from(_bucketName);

    await bucket.upload(
      objectPath,
      File(localPath),
      fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
    );

    return bucket.getPublicUrl(objectPath);
  }

  @override
  Future<void> deleteCoverUrl(String? publicUrl) async {
    final objectPath = _objectPathFromPublicUrl(publicUrl);
    if (objectPath == null) return;

    await _client.storage.from(_bucketName).remove([objectPath]);
  }
}

String _normalizedExtension(String localPath) {
  final fileName = localPath.replaceAll('\\', '/').split('/').last;
  final dotIndex = fileName.lastIndexOf('.');
  final extension = dotIndex < 0
      ? ''
      : fileName.substring(dotIndex + 1).toLowerCase();
  return _supportedExtensions.contains(extension) ? extension : 'jpg';
}

String? _objectPathFromPublicUrl(String? publicUrl) {
  if (publicUrl == null) return null;

  final uri = Uri.tryParse(publicUrl);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }

  final segments = uri.pathSegments;
  if (segments.length <= _publicPathPrefix.length) return null;
  for (var index = 0; index < _publicPathPrefix.length; index++) {
    if (segments[index] != _publicPathPrefix[index]) return null;
  }

  final objectSegments = segments.skip(_publicPathPrefix.length).toList();
  if (objectSegments.any((segment) => segment.isEmpty)) return null;
  return objectSegments.join('/');
}
