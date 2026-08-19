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

  // Photos stored in Supabase Storage come back as public URLs rather than
  // device paths. Mirrors TripCoverPhoto's own scheme check so entry photos,
  // the full-screen viewer, the trip carousel and the slideshow all render a
  // remote photo through this one shim instead of each learning about URLs.
  final uri = Uri.tryParse(path);
  if (uri != null &&
      uri.hasAuthority &&
      (uri.scheme == 'http' || uri.scheme == 'https')) {
    return Image.network(
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
