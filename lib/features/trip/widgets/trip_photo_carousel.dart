import 'package:flutter/material.dart';

import '../trip_photos.dart';
import 'trip_cover_local_image.dart';
import 'trip_cover_photo.dart';

/// Swipeable strip of every photo in a trip, occupying the slot the static
/// cover photo used to hold at the top of Trip View.
///
/// The cover itself is deliberately *not* a page here. A carousel page has to
/// map one-to-one onto a [TripPhoto] so the full-screen slideshow can open on
/// exactly the photo that was tapped; the cover has no day and no entry to
/// navigate back to, so prepending it would put every index off by one. It
/// still renders as the fallback when the trip has no photos at all.
class TripPhotoCarousel extends StatefulWidget {
  const TripPhotoCarousel({
    super.key,
    required this.photos,
    required this.onPhotoTap,
    this.coverPhotoPath,
    this.height = 160,
  });

  final List<TripPhoto> photos;

  /// Hands back the tapped [TripPhoto] rather than its index on purpose. The
  /// carousel may be showing a filtered subset (food photos can be toggled
  /// off) while the slideshow always shows everything, so position here is not
  /// position there — the caller resolves the real one by identity.
  final ValueChanged<TripPhoto> onPhotoTap;

  final String? coverPhotoPath;

  /// Matches the height the cover photo occupied, so swapping this in doesn't
  /// move anything below it.
  final double height;

  @override
  State<TripPhotoCarousel> createState() => _TripPhotoCarouselState();
}

class _TripPhotoCarouselState extends State<TripPhotoCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void didUpdateWidget(TripPhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Hiding food photos can shrink the list out from under the current page.
    if (_currentIndex >= widget.photos.length) {
      _currentIndex = widget.photos.isEmpty ? 0 : widget.photos.length - 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return TripCoverPhoto(
        photoPath: widget.coverPhotoPath,
        height: widget.height,
        width: double.infinity,
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            key: const Key('trip-photo-carousel'),
            controller: _controller,
            itemCount: widget.photos.length,
            // No implicit scrolling and no keep-alives: only the neighbouring
            // pages should ever hold a decoded bitmap.
            allowImplicitScrolling: false,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return GestureDetector(
                key: Key('trip-carousel-page-$index'),
                onTap: () => widget.onPhotoTap(photo),
                child: _CarouselImage(
                  // Keyed by path so page recycling can never render one
                  // photo's bitmap in another's slot.
                  key: ValueKey(photo.path),
                  path: photo.path,
                  height: widget.height,
                ),
              );
            },
          ),
          // Overlaid rather than stacked below, so the carousel occupies
          // exactly the height the cover photo did.
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: _PageDots(count: widget.photos.length, current: _currentIndex),
          ),
        ],
      ),
    );
  }
}

class _CarouselImage extends StatelessWidget {
  const _CarouselImage({super.key, required this.path, required this.height});

  final String path;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = MediaQuery.devicePixelRatioOf(context);

    final image = buildTripCoverLocalImage(
      path,
      width: double.infinity,
      height: height,
      // Decode at display size. Originals may be up to 32 MB, and a PageView
      // keeps several pages alive at once.
      cacheWidth: (width * scale).round(),
      errorBuilder: (context, error, stackTrace) => _placeholder(context),
    );

    return Container(
      width: double.infinity,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: image ?? _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Icon(
      Icons.broken_image_outlined,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      size: height / 3,
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            key: Key('trip-carousel-dot-$i'),
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current
                  ? scheme.onPrimary
                  : scheme.onPrimary.withValues(alpha: 0.45),
            ),
          ),
      ],
    );
  }
}
