import 'dart:io';

import 'package:flutter/material.dart';

/// [cacheWidth] decodes the file at display size instead of sensor size —
/// photos may be up to 32 MB (see `photo_validation.dart`), and a 12 MP image
/// decodes to roughly 48 MB in memory. Null keeps the original behaviour of
/// decoding at full resolution.
Widget? buildTripCoverLocalImage(
  String path, {
  double? width,
  double? height,
  int? cacheWidth,
  BoxFit fit = BoxFit.cover,
  required ImageErrorWidgetBuilder errorBuilder,
}) {
  // Seed data points at bundled assets rather than device files; everything
  // the user picks is a real path. Checking the prefix keeps both working
  // through one call site.
  if (path.startsWith('assets/')) {
    return Image.asset(
      path,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }

  final file = File(path);
  if (!file.existsSync()) return null;
  return Image.file(
    file,
    width: width,
    height: height,
    cacheWidth: cacheWidth,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
