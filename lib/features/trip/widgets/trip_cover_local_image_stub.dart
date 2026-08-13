import 'package:flutter/material.dart';

Widget? buildTripCoverLocalImage(
  String path, {
  double? width,
  double? height,
  int? cacheWidth,
  BoxFit fit = BoxFit.cover,
  required ImageErrorWidgetBuilder errorBuilder,
}) {
  // Bundled assets work on web too — only device files don't.
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
  return null;
}
