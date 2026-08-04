import 'trip_cover_storage.dart';
import 'trip_cover_upload.dart';

Future<PreparedTripCoverUpload> prepareTripCoverUpload(
  TripCoverDraft cover,
) async {
  return directTripCoverUpload(cover);
}
