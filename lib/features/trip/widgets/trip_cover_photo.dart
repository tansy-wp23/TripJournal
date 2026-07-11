import 'dart:io';

import 'package:flutter/material.dart';

/// Cover photo surface — renders the real device file when [photoPath]
/// points at one (picked via image_picker, see TripFormScreen), or a
/// placeholder icon otherwise. Seeded mock trips still use string paths
/// like `assets/mock/...` with no real file behind them, so this always
/// checks the file actually exists before attempting to load it, rather
/// than trusting the path's shape.
class TripCoverPhoto extends StatelessWidget {
  const TripCoverPhoto({super.key, this.photoPath, this.width, this.height});

  final String? photoPath;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    final file = path == null ? null : File(path);

    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: file != null && file.existsSync()
          ? Image.file(
              file,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _placeholderIcon(context),
            )
          : _placeholderIcon(context),
    );
  }

  Widget _placeholderIcon(BuildContext context) {
    return Icon(
      Icons.photo,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      size: (height ?? 64) / 2,
    );
  }
}
