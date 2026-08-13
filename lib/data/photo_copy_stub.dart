import 'package:cross_file/cross_file.dart';

/// Web has no filesystem to copy into — the caller falls back to the original
/// (blob) path. Mirrors `trip_cover_local_image_stub.dart`'s null-means-
/// unavailable convention.
Future<String?> copyPhotoIntoAppStorage(XFile photo) async => null;

/// Nothing to delete when nothing was ever copied.
Future<void> deleteCopiedPhoto(String path) async {}
