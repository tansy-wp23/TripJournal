import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Subdirectory of the app's documents directory that owns every copied photo.
/// Keeping them together is what makes [deleteCopiedPhoto] able to tell "a
/// file we own" from "a path the picker handed us".
const _photosDirName = 'photos';

/// Copies [photo] into `<appDocuments>/photos/<uuid>.<ext>` and returns the new
/// absolute path, or null if the copy could not be made.
///
/// Null rather than a throw: under `flutter test` there is no plugin to answer
/// the `getApplicationDocumentsDirectory` method channel, so this path is hit
/// by every widget test that adds a photo. That has to be a quiet fallback,
/// not a failure.
///
/// A uuid name — not a timestamp — because a multi-select gallery pick copies
/// several files inside the same microsecond.
Future<String?> copyPhotoIntoAppStorage(XFile photo) async {
  try {
    if (photo.path.isEmpty) return null;

    final source = File(photo.path);
    if (!await source.exists()) return null;

    final documents = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${documents.path}/$_photosDirName');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    // TODO(phase7): downscale here via flutter_image_compress before copying —
    // validatePhotoSize allows 32 MB originals, and the carousel decodes them.
    final destination = '${photosDir.path}/${_uuid.v4()}${_extensionOf(photo)}';
    await source.copy(destination);
    return destination;
  } catch (_) {
    return null;
  }
}

/// Deletes a photo previously returned by [copyPhotoIntoAppStorage].
///
/// Refuses anything outside the photos directory so that removing a photo can
/// never delete the user's original in their gallery — entry photos saved
/// before this feature existed still hold raw picker paths.
Future<void> deleteCopiedPhoto(String path) async {
  try {
    final documents = await getApplicationDocumentsDirectory();
    final owned = '${documents.path}/$_photosDirName';
    if (!path.startsWith(owned)) return;

    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Cleanup is best-effort — a leaked file is never worth an error.
  }
}

String _extensionOf(XFile photo) {
  final name = photo.name.isNotEmpty ? photo.name : photo.path;
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return '.jpg';
  final extension = name.substring(dot);
  // Guard against a "." appearing in a directory name rather than the file.
  return extension.contains('/') || extension.contains(r'\') ? '.jpg' : extension;
}
