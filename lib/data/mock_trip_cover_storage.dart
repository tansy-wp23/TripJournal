import 'trip_cover_storage.dart';

final class MockTripCoverStorage implements TripCoverStorage {
  @override
  Future<String> uploadCover({
    required String userId,
    required String tripId,
    required String localPath,
  }) async {
    return localPath;
  }

  @override
  Future<void> deleteCoverUrl(String? publicUrl) async {}
}
