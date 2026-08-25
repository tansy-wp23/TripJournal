import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'current_user_id_provider.dart';
import 'photo_storage.dart';

const _bucketName = 'journal-photos';

/// Real [PhotoStorage] backed by Supabase Storage — mirrors
/// `SupabaseTripCoverStorage`'s `trip-covers` bucket, including its
/// `{userId}/{tripId}/{file}` object layout.
///
/// That layout is not a convention, it is the access rule. The
/// `journal_photos_*` policies call `storage_trip_mutation_allowed(name,
/// false)`, which reads the first folder as the owner's uid, parses the second
/// as a trip uuid, and refuses the write unless that trip exists and belongs to
/// the caller. A flat or differently-shaped path is rejected outright.
final class SupabasePhotoStorage implements PhotoStorage {
  SupabasePhotoStorage(
    this._client,
    this._userIdProvider, [
    this._uuid = const Uuid(),
  ]);

  final SupabaseClient _client;
  final CurrentUserIdProvider _userIdProvider;
  final Uuid _uuid;

  /// Honours [PhotoStorage.savePhoto]'s "never throws" contract.
  ///
  /// A failed upload returns the picker's own path, exactly as the local
  /// implementation does when there is no filesystem to copy into. The photo
  /// then behaves as it did before Storage existed — readable this session,
  /// possibly evicted later — which is strictly better than aborting the rest
  /// of a multi-select batch. Failures are silent by design here because the
  /// caller has no useful recovery beyond carrying on.
  @override
  Future<String> savePhoto(XFile photo, {required String tripId}) async {
    try {
      final userId = _userIdProvider.requireUserId();
      final bytes = await photo.readAsBytes();
      final extension = _extensionFromName(photo.name);
      final objectPath = '$userId/$tripId/entry-${_uuid.v4()}.$extension';
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
    } catch (_) {
      return photo.path;
    }
  }

  /// Best-effort, and a no-op for anything this storage never wrote — the same
  /// contract the local implementation honours for paths it does not own. An
  /// entry can hold a mix of both after a mode switch or a failed upload.
  @override
  Future<void> deletePhoto(String? path) async {
    final objectPath = _objectPathFromPublicUrl(
      path,
      storageUri: Uri.parse(_client.storage.url),
    );
    if (objectPath == null) return;

    try {
      await _client.storage.from(_bucketName).remove([objectPath]);
    } catch (_) {
      // Cleanup only. The user already removed the photo from the entry; a
      // failure here leaves an unreferenced object, not a broken entry.
    }
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

/// Recovers the storage object path from a public URL this class produced.
///
/// Mirrors `SupabaseProfileAvatarStorage`'s parser, including its refusals:
/// a URL pointing at another host, or one whose encoded path smuggles a `/`
/// or `\` through `%2F`/`%5C`, is treated as "not ours" rather than decoded
/// into a path that would delete somebody else's object.
String? _objectPathFromPublicUrl(String? publicUrl, {required Uri storageUri}) {
  if (publicUrl == null || publicUrl.isEmpty) return null;

  const publicPathPrefix = '/storage/v1/object/public/$_bucketName/';

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
  if (!rawPath.startsWith(publicPathPrefix)) return null;

  final encodedObjectPath = rawPath.substring(publicPathPrefix.length);
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
