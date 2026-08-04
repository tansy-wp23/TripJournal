import 'dart:typed_data';

import 'package:image/image.dart' as image;

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

final class InvalidTripCoverImageException implements Exception {
  const InvalidTripCoverImageException();

  @override
  String toString() {
    return 'This image is damaged or does not match its file type. Choose a valid JPG, PNG, or WebP image.';
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
) async {
  return validateTripCoverBytes(
    bytes: await cover.readAsBytes(),
    fileName: cover.name,
    declaredMimeType: cover.mimeType,
  );
}

PreparedTripCoverUpload validateTripCoverBytes({
  required Uint8List bytes,
  required String fileName,
  String? declaredMimeType,
}) {
  final extension = supportedTripCoverExtension(fileName);
  if (extension == null) throw const UnsupportedTripCoverFormatException();

  final expectedContentType = tripCoverContentType(extension);
  final normalizedMimeType = declaredMimeType
      ?.split(';')
      .first
      .trim()
      .toLowerCase();
  if (normalizedMimeType != null && normalizedMimeType != expectedContentType) {
    throw const InvalidTripCoverImageException();
  }

  final expectedFormat = extension == 'jpg' || extension == 'jpeg'
      ? _TripCoverFormat.jpeg
      : extension == 'png'
      ? _TripCoverFormat.png
      : _TripCoverFormat.webp;
  if (_detectFormat(bytes) != expectedFormat ||
      !_isDecodable(bytes, expectedFormat)) {
    throw const InvalidTripCoverImageException();
  }

  return PreparedTripCoverUpload(
    bytes: bytes,
    extension: extension,
    contentType: expectedContentType,
  );
}

enum _TripCoverFormat { jpeg, png, webp }

_TripCoverFormat? _detectFormat(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return _TripCoverFormat.jpeg;
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return _TripCoverFormat.png;
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return _TripCoverFormat.webp;
  }
  return null;
}

bool _isDecodable(Uint8List bytes, _TripCoverFormat format) {
  try {
    final decoder = switch (format) {
      _TripCoverFormat.jpeg => image.JpegDecoder(),
      _TripCoverFormat.png => image.PngDecoder(),
      _TripCoverFormat.webp => image.WebPDecoder(),
    };
    return decoder.isValidFile(bytes) && decoder.decode(bytes) != null;
  } catch (_) {
    return false;
  }
}
