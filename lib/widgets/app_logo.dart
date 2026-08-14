import 'package:flutter/material.dart';

/// The app's own artwork, drawn square at [size].
///
/// The single place the asset path lives, so the splash and the sign-in screen
/// can't drift apart. Every launcher icon and native splash raster is generated
/// from this same file by `dart run tool/generate_app_icons.dart`, which is what
/// keeps the in-app logo identical to the one on the home screen.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.size});

  /// Bundled master artwork.
  static const asset = 'assets/branding/app_icon.png';

  /// Rendered edge length. Where the caller imposes a tight width (a stretched
  /// [Column], say), [BoxFit.contain] keeps the artwork square and centred at
  /// this height rather than letting it distort.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // The master is 512px square; without this it decodes at full resolution
      // to fill a box a fraction of that.
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
    );
  }
}
