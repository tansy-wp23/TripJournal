import 'package:flutter/material.dart';

import '../../journal/screens/entry_detail_screen.dart';
import '../../journal/widgets/format_utils.dart';
import '../trip_photos.dart';
import '../widgets/trip_cover_local_image.dart';

/// Full-screen slideshow over every photo in a trip.
///
/// Opened positioned at a particular photo — from the header carousel or from
/// a day's thumbnail strip — but swiping deliberately runs past the day
/// boundary into the neighbouring days, so a trip reads as one continuous
/// sequence rather than a set of dead ends. The app bar always says which day
/// the current photo belongs to.
///
/// Kept separate from `PhotoViewerScreen` (which shows the photos of a single
/// entry) because that screen knows nothing about days or trips, and folding
/// both jobs into it would complicate a widget that already works.
class TripPhotoSlideshowScreen extends StatefulWidget {
  const TripPhotoSlideshowScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<TripPhoto> photos;
  final int initialIndex;

  @override
  State<TripPhotoSlideshowScreen> createState() => _TripPhotoSlideshowScreenState();
}

class _TripPhotoSlideshowScreenState extends State<TripPhotoSlideshowScreen> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    // Defensive clamp: callers resolve an index by identity or via
    // firstIndexForDay, but an out-of-range value must never throw here.
    final maxIndex = widget.photos.isEmpty ? 0 : widget.photos.length - 1;
    _currentIndex = widget.initialIndex.clamp(0, maxIndex);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: _appBar(context, title: null, photo: null),
        body: const Center(
          child: Text('No photos yet.', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final photo = widget.photos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _appBar(
        context,
        title: 'Day ${photo.dayNumber} · ${formatDate(photo.date)} · '
            '${_currentIndex + 1} of ${widget.photos.length}',
        photo: photo,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              key: const Key('trip-slideshow-page-view'),
              controller: _controller,
              itemCount: widget.photos.length,
              allowImplicitScrolling: false,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) => _SlideshowImage(
                key: ValueKey(widget.photos[index].path),
                path: widget.photos[index].path,
              ),
            ),
          ),
          if (photo.caption != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      photo.kind == TripPhotoKind.meal
                          ? Icons.restaurant
                          : Icons.photo_camera_outlined,
                      color: Colors.white54,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        key: const Key('trip-slideshow-caption'),
                        photo.caption!,
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar(
    BuildContext context, {
    required String? title,
    required TripPhoto? photo,
  }) {
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      title: title == null
          ? null
          : Text(title, style: const TextStyle(fontSize: 16)),
      leading: IconButton(
        key: const Key('trip-slideshow-close-button'),
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (photo != null)
          IconButton(
            key: const Key('slideshow-go-to-entry'),
            icon: const Icon(Icons.article_outlined),
            tooltip: 'Open entry',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EntryDetailScreen(entryId: photo.entryId),
              ),
            ),
          ),
      ],
    );
  }
}

class _SlideshowImage extends StatelessWidget {
  const _SlideshowImage({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = MediaQuery.devicePixelRatioOf(context);

    // BoxFit.contain here, unlike the cropped carousel thumbnails — this is
    // where the user sees the whole picture.
    final image = buildTripCoverLocalImage(
      path,
      cacheWidth: (width * scale).round(),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );

    return Center(child: image ?? _placeholder());
  }

  Widget _placeholder() {
    return const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 96);
  }
}
