import 'package:flutter/material.dart';

import '../../../data/trip_cover_storage.dart';
import 'trip_cover_local_image.dart';

/// Cover photo surface that renders public HTTP URLs or real device files.
/// Seeded mock trips still use paths like `assets/mock/...` with no file behind
/// them, so local paths are checked before loading and otherwise fall back to
/// the placeholder.
class TripCoverPhoto extends StatelessWidget {
  const TripCoverPhoto({
    super.key,
    this.photoPath,
    this.coverDraft,
    this.width,
    this.height,
  });

  final String? photoPath;
  final TripCoverDraft? coverDraft;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    final uri = path == null ? null : Uri.tryParse(path);
    final isNetworkUrl =
        uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');

    final Widget cover;
    if (coverDraft?.previewBytes != null) {
      cover = Image.memory(
        coverDraft!.previewBytes!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholderIcon(context),
      );
    } else if (path != null && isNetworkUrl) {
      cover = Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholderIcon(context),
      );
    } else if (path != null) {
      cover =
          buildTripCoverLocalImage(
            path,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) =>
                _placeholderIcon(context),
          ) ??
          _placeholderIcon(context);
    } else {
      cover = _placeholderIcon(context);
    }

    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: cover,
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
