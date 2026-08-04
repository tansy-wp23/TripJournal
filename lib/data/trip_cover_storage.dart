abstract interface class TripCoverStorage {
  Future<String> uploadCover({
    required String userId,
    required String tripId,
    required String localPath,
  });

  Future<void> deleteCoverUrl(String? publicUrl);
}
