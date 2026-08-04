import 'dart:typed_data';

import 'trip_cover_storage.dart';

const supportedTripCoverExtensions = {'jpg', 'jpeg', 'png', 'webp'};

final class PreparedTripCoverUpload {
  const PreparedTripCoverUpload({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
}

final class UnsupportedTripCoverFormatException implements Exception {
  const UnsupportedTripCoverFormatException();

  @override
  String toString() {
    return 'This image format is not supported here. Choose a JPG, PNG, or WebP image.';
  }
}

String? supportedTripCoverExtension(String fileName) {
  final normalizedName = fileName.replaceAll('\\', '/').split('/').last;
  final dotIndex = normalizedName.lastIndexOf('.');
  final extension = dotIndex < 0
      ? ''
      : normalizedName.substring(dotIndex + 1).toLowerCase();
  return supportedTripCoverExtensions.contains(extension) ? extension : null;
}

String tripCoverContentType(String extension) {
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => throw ArgumentError.value(extension, 'extension'),
  };
}

Future<PreparedTripCoverUpload> directTripCoverUpload(
  TripCoverDraft cover,
  String extension,
) async {
  return PreparedTripCoverUpload(
    bytes: await cover.readAsBytes(),
    extension: extension,
    contentType: tripCoverContentType(extension),
  );
}
