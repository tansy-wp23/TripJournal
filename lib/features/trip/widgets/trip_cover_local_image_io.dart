import 'dart:io';

import 'package:flutter/material.dart';

Widget? buildTripCoverLocalImage(
  String path, {
  double? width,
  double? height,
  required ImageErrorWidgetBuilder errorBuilder,
}) {
  final file = File(path);
  if (!file.existsSync()) return null;
  return Image.file(
    file,
    width: width,
    height: height,
    fit: BoxFit.cover,
    errorBuilder: errorBuilder,
  );
}
