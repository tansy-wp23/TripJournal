import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

final class TripCoverDraft {
  TripCoverDraft._({
    required this.name,
    required this.path,
    required this._file,
    this._bytes,
    this.mimeType,
  });

  final String name;
  final String path;
  final String? mimeType;
  final XFile _file;
  Uint8List? _bytes;

  Uint8List? get previewBytes => _bytes;

  Future<Uint8List> readAsBytes() async {
    return _bytes ??= await _file.readAsBytes();
  }

  static Future<TripCoverDraft> fromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    return TripCoverDraft._(
      name: file.name,
      path: file.path,
      file: file,
      bytes: bytes,
      mimeType: file.mimeType,
    );
  }

  factory TripCoverDraft.fromPath(String path) {
    final file = XFile(path);
    return TripCoverDraft._(
      name: file.name,
      path: file.path,
      file: file,
      mimeType: file.mimeType,
    );
  }
}

abstract interface class TripCoverStorage {
  Future<String> uploadCover({
    required String userId,
    required String tripId,
    required TripCoverDraft cover,
  });

  Future<void> deleteCoverUrl(String? publicUrl);
}
