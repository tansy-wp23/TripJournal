import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'profile_avatar_storage.dart';

const _bucketName = 'profile-avatars';
const _publicPathPrefix = '/storage/v1/object/public/$_bucketName/';

/// Real [ProfileAvatarStorage] backed by Supabase Storage — mirrors
/// `SupabaseTripCoverStorage`'s `trip-covers` bucket pattern.
final class SupabaseProfileAvatarStorage implements ProfileAvatarStorage {
  SupabaseProfileAvatarStorage(this._client, [this._uuid = const Uuid()]);

  final SupabaseClient _client;
  final Uuid _uuid;

  @override
  Future<String> uploadAvatar({
    required String userId,
    required XFile photo,
  }) async {
    final bytes = await photo.readAsBytes();
    final extension = _extensionFromName(photo.name);
    final objectPath = '$userId/avatar-${_uuid.v4()}.$extension';
    final bucket = _client.storage.from(_bucketName);

    await bucket.uploadBinary(
      objectPath,
      bytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: false,
        contentType: _contentTypeFor(extension),
      ),
    );

    return bucket.getPublicUrl(objectPath);
  }

  @override
  Future<void> deleteAvatarUrl(String? publicUrl) async {
    final objectPath = _objectPathFromPublicUrl(
      publicUrl,
      storageUri: Uri.parse(_client.storage.url),
    );
    if (objectPath == null) return;

    await _client.storage.from(_bucketName).remove([objectPath]);
  }

  String _extensionFromName(String name) {
    final normalizedName = name.replaceAll('\\', '/').split('/').last;
    final dotIndex = normalizedName.lastIndexOf('.');
    final extension = dotIndex < 0
        ? 'jpg'
        : normalizedName.substring(dotIndex + 1).toLowerCase();
    return switch (extension) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
  }

  String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
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