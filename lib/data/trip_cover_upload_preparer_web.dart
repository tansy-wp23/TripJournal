import 'trip_cover_storage.dart';
import 'trip_cover_upload.dart';

Future<PreparedTripCoverUpload> prepareTripCoverUpload(
  TripCoverDraft cover,
) async {
  final extension = supportedTripCoverExtension(cover.name);
  if (extension == null) {
    throw const UnsupportedTripCoverFormatException();
  }
  return directTripCoverUpload(cover, extension);
}
