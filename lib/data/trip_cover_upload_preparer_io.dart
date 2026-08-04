import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'trip_cover_storage.dart';
import 'trip_cover_upload.dart';

Future<PreparedTripCoverUpload> prepareTripCoverUpload(
  TripCoverDraft cover,
) async {
  final extension = supportedTripCoverExtension(cover.name);
  if (extension != null) return directTripCoverUpload(cover, extension);

  final result = await FlutterImageCompress.compressWithFile(
    cover.path,
    format: CompressFormat.jpeg,
  );
  if (result == null || !_isJpeg(result)) {
    throw StateError('Cover image could not be converted to JPEG.');
  }
  return PreparedTripCoverUpload(
    bytes: result,
    extension: 'jpg',
    contentType: 'image/jpeg',
  );
}

bool _isJpeg(Uint8List bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[bytes.length - 2] == 0xff &&
      bytes[bytes.length - 1] == 0xd9;
}
