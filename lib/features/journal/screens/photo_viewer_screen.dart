import 'package:flutter/material.dart';

import '../../trip/widgets/trip_cover_local_image.dart';

/// Full-screen photo viewer for a daily journal entry's photos — tapping a
/// square (`BoxFit.cover`) thumbnail opens the whole, uncropped image here
/// (`BoxFit.contain`), with horizontal swipe between the entry's other
/// photos via [PageView]. See IMPLEMENTATION_PLAN_INLINE_PHOTO.md §2.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.photoPaths, required this.initialIndex});

  final List<String> photoPaths;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: widget.photoPaths.length > 1
            ? Text('${_currentIndex + 1} / ${widget.photoPaths.length}')
            : null,
        leading: IconButton(
          key: const Key('photo-viewer-close-button'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        key: const Key('photo-viewer-page-view'),
        controller: _controller,
        itemCount: widget.photoPaths.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final image = buildTripCoverLocalImage(
            widget.photoPaths[index],
            cacheWidth: (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context))
                .round(),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _placeholder(),
          );
          return GestureDetector(
            // Dismiss on tap — the required "tap-outside" affordance; the ×
            // and system back also work (default Scaffold/back behaviour).
            onTap: () => Navigator.pop(context),
            child: Center(child: image ?? _placeholder()),
          );
        },
      ),
    );
  }

  Widget _placeholder() {
    return const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 96);
  }
}
