import 'trip_cover_storage.dart';

final class MockTripCoverStorage implements TripCoverStorage {
  @override
  Future<String> uploadCover({
    required String userId,
    required String tripId,
    required TripCoverDraft cover,
  }) async {
    final scheme = Uri.tryParse(cover.path)?.scheme.toLowerCase();
    if (cover.path.isEmpty || scheme == 'blob' || scheme == 'data') {
      return Uri(
        scheme: 'mock-cover',
        host: userId,
        pathSegments: [tripId, cover.name],
      ).toString();
    }
    return cover.path;
  }

  @override
  Future<void> deleteCoverUrl(String? publicUrl) async {}
}
