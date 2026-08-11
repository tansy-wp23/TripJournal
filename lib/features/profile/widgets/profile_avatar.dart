import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../trip/widgets/trip_cover_local_image.dart';

/// Circular profile picture. Renders picked-but-unsaved bytes, a public
/// HTTP(S) URL, or a local device file path (the shape mock avatar storage
/// echoes back on non-web platforms), falling back to the user's initial
/// when none is available or the image fails to load. Mirrors
/// `TripCoverPhoto`'s fallback chain.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.radius,
    this.avatarUrl,
    this.previewBytes,
    required this.initial,
  });

  final double radius;
  final String? avatarUrl;
  final Uint8List? previewBytes;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    final isNetworkUrl =
        uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
    final size = radius * 2;

    Widget? image;
    if (previewBytes != null) {
      image = Image.memory(
        previewBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _initial(context),
      );
    } else if (url != null && isNetworkUrl) {
      image = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _initial(context),
      );
    } else if (url != null) {
      image = buildTripCoverLocalImage(
        url,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) => _initial(context),
      );
    }

    return CircleAvatar(
      radius: radius,
      child: image == null ? _initial(context) : ClipOval(child: image),
    );
  }

  Widget _initial(BuildContext context) {
    return Text(initial, style: Theme.of(context).textTheme.headlineMedium);
  }
}
