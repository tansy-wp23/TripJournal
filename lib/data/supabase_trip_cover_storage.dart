import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'trip_cover_storage.dart';
import 'trip_cover_upload_preparer.dart';

const _bucketName = 'trip-covers';
const _publicPathPrefix = '/storage/v1/object/public/$_bucketName/';

final class SupabaseTripCoverStorage implements TripCoverStorage {
  SupabaseTripCoverStorage(this._client, [this._uuid = const Uuid()]);

  final SupabaseClient _client;
  final Uuid _uuid;

  @override
  Future<String> uploadCover({
    required String userId,
    required String tripId,
    required TripCoverDraft cover,
  }) async {
    final prepared = await prepareTripCoverUpload(cover);
    final objectPath =
        '$userId/$tripId/cover-${_uuid.v4()}.${prepared.extension}';
    final bucket = _client.storage.from(_bucketName);

    await bucket.uploadBinary(
      objectPath,
      prepared.bytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: false,
        contentType: prepared.contentType,
      ),
    );

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
