import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'trip_cover_storage.dart';
import 'trip_cover_upload.dart';

Future<PreparedTripCoverUpload> prepareTripCoverUpload(
  TripCoverDraft cover,
) async {
  final extension = supportedTripCoverExtension(cover.name);
  if (extension != null) return directTripCoverUpload(cover);

  final result = await FlutterImageCompress.compressWithFile(
    cover.path,
    format: CompressFormat.jpeg,
  );
  if (result == null) {
    throw StateError('Cover image could not be converted to JPEG.');
  }
  return validateTripCoverBytes(
    bytes: result,
    fileName: 'converted-cover.jpg',
    declaredMimeType: 'image/jpeg',
  );
}
