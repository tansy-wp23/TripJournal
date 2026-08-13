import 'package:flutter/material.dart';

import '../../trip/widgets/trip_cover_local_image.dart';

/// Square photo thumbnail rendering the actual image content from a local
/// file path (picked via image_picker) — replaces the old filename-only
/// chip. Falls back to a placeholder icon for a missing or corrupt file,
/// never a crash — mirrors `TripCoverPhoto`'s existsSync + errorBuilder
/// pattern. See IMPLEMENTATION_PLAN_UX_POLISH.md §3.
class PhotoThumbnail extends StatelessWidget {
  const PhotoThumbnail({
    super.key,
    required this.photoPath,
    this.size = 88,
    this.onTap,
    this.onRemove,
    this.removeButtonKey,
  });

  final String photoPath;
  final double size;

  /// Opens the full-screen viewer (IMPLEMENTATION_PLAN_INLINE_PHOTO.md §2)
  /// when set. Null keeps the thumbnail non-interactive on its image area.
  final VoidCallback? onTap;

  /// Null hides the remove affordance entirely (read-only display, e.g. the
  /// entry detail screen).
  final VoidCallback? onRemove;
  final Key? removeButtonKey;

  @override
  Widget build(BuildContext context) {
    // Decode at thumbnail resolution, not sensor resolution. A 12 MP photo
    // decodes to ~48 MB in ARGB, and validatePhotoSize allows 32 MB originals
    // — a grid of those at full size is an OOM waiting to happen.
    final decodeWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();

    // Shared shim: handles bundled assets (seed data), real device files, and
    // returns null for anything missing — which also makes this widget safe on
    // web, where it used to import dart:io unconditionally.
    final image = buildTripCoverLocalImage(
      photoPath,
      width: size,
      height: size,
      cacheWidth: decodeWidth,
      errorBuilder: (context, error, stackTrace) => _placeholderIcon(context),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onTap,
              child: Container(
                width: size,
                height: size,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: image ?? _placeholderIcon(context),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: -8,
              right: -8,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                shape: const CircleBorder(),
                child: IconButton(
                  key: removeButtonKey,
                  onPressed: onRemove,
                  icon: const Icon(Icons.cancel),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Remove photo',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholderIcon(BuildContext context) {
    return Icon(
      Icons.broken_image_outlined,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      size: size / 2,
    );
  }
}
