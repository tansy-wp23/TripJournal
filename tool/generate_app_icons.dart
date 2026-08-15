// Derives every platform launcher icon and splash raster from the single
// master artwork at `assets/branding/app_icon.png`.
//
// Deliberately a plain `dart run` script over the `image` package (already a
// direct dependency, used by `tool/generate_mock_photos.dart`) rather than
// adding `flutter_launcher_icons` + `flutter_native_splash`: this needs no new
// dev dependencies, no network, and no build step, and the sizing rules below
// are the part that actually matters -- see `_maxRadius`.
//
// Run from the project root:  dart run tool/generate_app_icons.dart
//
// Everything it writes is committed, so this only needs re-running when the
// master artwork changes.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

const _master = 'assets/branding/app_icon.png';

/// Icon plate colour. The artwork is a flat, dark-outlined illustration on a
/// transparent background, so it needs an opaque plate behind it: iOS forbids
/// alpha in app icons outright, and on Android an adaptive icon's background
/// layer must be opaque or the launcher shows the wallpaper through it.
/// White keeps the near-black outline at full contrast.
final _plate = ColorRgb8(0xFF, 0xFF, 0xFF);

/// Android density buckets, as multipliers of dp.
const _densities = <String, double>{
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

/// Adaptive icons are a 108dp canvas of which only the centre 66dp circle is
/// guaranteed visible -- launchers mask the rest to a circle, squircle or
/// teardrop. 66/108/2 as a fraction of the canvas edge.
const _adaptiveSafeRadius = 66 / 108 / 2;

/// The Android 12+ system splash draws the icon on a 240dp canvas and masks it
/// to the inner 160dp circle.
const _android12SafeRadius = 160 / 240 / 2;

/// A maskable web icon must survive an 80%-diameter circular crop.
const _maskableSafeRadius = 0.4;

/// Plain (unmasked) plate icons: enough breathing room to look deliberate
/// without wasting the canvas.
const _plateSafeRadius = 0.42;

void main() {
  final master = decodePng(File(_master).readAsBytesSync());
  if (master == null) {
    stderr.writeln('could not decode $_master');
    exitCode = 1;
    return;
  }

  final art = _trim(master);
  final radius = _maxRadius(art);
  stdout.writeln('master  ${master.width}x${master.height}');
  stdout.writeln('artwork ${art.width}x${art.height} '
      '(trimmed), max radius from centre ${radius.toStringAsFixed(1)}px');
  stdout.writeln('');

  _android(art);
  _ios(art);
  _macos(art);
  _windows(art);
  _web(art);

  stdout.writeln('\ndone.');
}

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

/// The artwork cropped to its opaque bounds, so every downstream size is
/// measured against the ink rather than against the master's own padding.
Image _trim(Image src) {
  var minX = src.width, minY = src.height, maxX = -1, maxY = -1;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      if (src.getPixel(x, y).a < 8) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return src;
  return copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

/// Distance from the artwork's centre to its furthest opaque pixel.
///
/// Every "does it survive a circular mask" decision below is made against this
/// rather than against the bounding box's corner. The notebook's corners are
/// rounded and its top-left is empty, so the true radius is meaningfully
/// smaller than half the diagonal -- measuring it buys back icon size that a
/// bounding-box estimate would throw away.
double _maxRadius(Image art) {
  final cx = (art.width - 1) / 2, cy = (art.height - 1) / 2;
  var best = 0.0;
  for (var y = 0; y < art.height; y++) {
    for (var x = 0; x < art.width; x++) {
      if (art.getPixel(x, y).a < 8) continue;
      final d = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
      if (d > best) best = d;
    }
  }
  return best;
}

/// Composes [art] onto a [size]x[size] canvas.
///
/// [safeRadius] is the fraction of the canvas edge within which every opaque
/// pixel must land; the artwork is scaled to exactly fill it. [background] of
/// null leaves the canvas transparent. [inset] and [corner] (both fractions of
/// the canvas edge / plate width) shape the plate for platforms that don't
/// apply their own mask.
Image _compose(
  Image art,
  int size, {
  required double safeRadius,
  Color? background,
  double inset = 0,
  double corner = 0,
  bool opaque = false,
}) {
  var canvas = Image(width: size, height: size, numChannels: 4);

  if (background != null) {
    final pad = (size * inset).round();
    fillRect(
      canvas,
      x1: pad,
      y1: pad,
      x2: size - pad - 1,
      y2: size - pad - 1,
      color: background,
      radius: (size - 2 * pad) * corner,
    );
  }

  final scale = (safeRadius * size) / _maxRadius(art);
  final w = math.max(1, (art.width * scale).round());
  final h = math.max(1, (art.height * scale).round());
  final scaled = copyResize(
    art,
    width: w,
    height: h,
    interpolation: Interpolation.cubic,
  );

  compositeImage(
    canvas,
    scaled,
    dstX: ((size - w) / 2).round(),
    dstY: ((size - h) / 2).round(),
  );

  // iOS rejects an app icon with an alpha channel, so drop it rather than
  // relying on the plate happening to cover every pixel.
  if (opaque) canvas = canvas.convert(numChannels: 3);
  return canvas;
}

/// The bare artwork at a given pixel height, no canvas and no plate.
Image _artAtHeight(Image art, int height) => copyResize(
      art,
      height: height,
      interpolation: Interpolation.cubic,
    );

void _write(String path, Image image) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(encodePng(image));
  stdout.writeln('  ${path.padRight(62)} ${image.width}x${image.height}');
}

// ---------------------------------------------------------------------------
// Android
// ---------------------------------------------------------------------------

void _android(Image art) {
  stdout.writeln('android');
  const res = 'android/app/src/main/res';

  _densities.forEach((bucket, d) {
    // Legacy raster. minSdk is 26, so `mipmap-anydpi-v26` wins on every
    // supported device and this is only a fallback for tooling that reads the
    // PNG directly -- keep it looking like the adaptive result.
    _write(
      '$res/mipmap-$bucket/ic_launcher.png',
      _compose(
        art,
        (48 * d).round(),
        safeRadius: _plateSafeRadius,
        background: _plate,
        corner: 0.22,
      ),
    );

    // Adaptive foreground: artwork only, on the 108dp canvas.
    _write(
      '$res/mipmap-$bucket/ic_launcher_foreground.png',
      _compose(art, (108 * d).round(), safeRadius: _adaptiveSafeRadius),
    );

    // Android 13 themed icon. A flat silhouette of the notebook would be a
    // featureless slab, so the line work is what gets kept: dark pixels become
    // opaque, light fills fade out, and the system tints the result.
    _write(
      '$res/mipmap-$bucket/ic_launcher_monochrome.png',
      _compose(_monochrome(art), (108 * d).round(),
          safeRadius: _adaptiveSafeRadius),
    );

    // Pre-Android-12 splash: drawn centred by launch_background.xml at its own
    // intrinsic size, so it is generated per density at a fixed 120dp height.
    _write(
      '$res/drawable-$bucket/splash_logo.png',
      _artAtHeight(art, (120 * d).round()),
    );

    // Android 12+ system splash icon: 240dp canvas, inner 160dp circle shown.
    _write(
      '$res/drawable-$bucket/android12_splash_logo.png',
      _compose(art, (240 * d).round(), safeRadius: _android12SafeRadius),
    );
  });

  // Play Store listing / anywhere a single hero icon is wanted.
  _write(
    'assets/branding/app_icon_512.png',
    _compose(art, 512,
        safeRadius: _plateSafeRadius, background: _plate, corner: 0.22),
  );
}

/// Line-art version of [art] for Android 13 themed icons: alpha is driven by
/// darkness, so outlines stay solid and pale fills drop away.
Image _monochrome(Image art) {
  final out = Image(width: art.width, height: art.height, numChannels: 4);
  for (var y = 0; y < art.height; y++) {
    for (var x = 0; x < art.width; x++) {
      final p = art.getPixel(x, y);
      if (p.a < 8) continue;
      final lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).toDouble();
      // Solid below 90, gone above 170 -- a smooth ramp between keeps the
      // strokes anti-aliased instead of jagged.
      final t = ((170 - lum) / 80).clamp(0.0, 1.0);
      out.setPixelRgba(x, y, 0, 0, 0, (p.a.toDouble() * t).round());
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// iOS
// ---------------------------------------------------------------------------

/// Filename suffix -> pixel size, matching the existing AppIcon.appiconset.
const _iosIcons = <String, int>{
  'Icon-App-20x20@1x': 20,
  'Icon-App-20x20@2x': 40,
  'Icon-App-20x20@3x': 60,
  'Icon-App-29x29@1x': 29,
  'Icon-App-29x29@2x': 58,
  'Icon-App-29x29@3x': 87,
  'Icon-App-40x40@1x': 40,
  'Icon-App-40x40@2x': 80,
  'Icon-App-40x40@3x': 120,
  'Icon-App-60x60@2x': 120,
  'Icon-App-60x60@3x': 180,
  'Icon-App-76x76@1x': 76,
  'Icon-App-76x76@2x': 152,
  'Icon-App-83.5x83.5@2x': 167,
  'Icon-App-1024x1024@1x': 1024,
};

void _ios(Image art) {
  stdout.writeln('ios');
  const iconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  _iosIcons.forEach((name, size) {
    _write(
      '$iconSet/$name.png',
      _compose(art, size,
          safeRadius: _plateSafeRadius, background: _plate, opaque: true),
    );
  });

  // LaunchScreen.storyboard centres this at its natural size.
  const launch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
  _write('$launch/LaunchImage.png', _artAtHeight(art, 120));
  _write('$launch/LaunchImage@2x.png', _artAtHeight(art, 240));
  _write('$launch/LaunchImage@3x.png', _artAtHeight(art, 360));
}

// ---------------------------------------------------------------------------
// macOS
// ---------------------------------------------------------------------------

void _macos(Image art) {
  stdout.writeln('macos');
  const iconSet = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final size in [16, 32, 64, 128, 256, 512, 1024]) {
    // macOS draws these unmasked, so the rounded plate and its margin have to
    // be part of the image; 80% of the canvas matches Apple's icon grid.
    _write(
      '$iconSet/app_icon_$size.png',
      _compose(
        art,
        size,
        safeRadius: _plateSafeRadius * 0.8,
        background: _plate,
        inset: 0.0975,
        corner: 0.225,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Windows
// ---------------------------------------------------------------------------

void _windows(Image art) {
  stdout.writeln('windows');
  final images = [
    for (final size in [16, 24, 32, 48, 64, 128, 256])
      _compose(art, size,
          safeRadius: _plateSafeRadius, background: _plate, corner: 0.12),
  ];
  const path = 'windows/runner/resources/app_icon.ico';
  // encodeIco() only writes one frame unless the image is animated; the
  // encoder's own multi-size entry point is what packs all seven.
  File(path).writeAsBytesSync(IcoEncoder().encodeImages(images));
  stdout.writeln('  ${path.padRight(62)} ${images.length} sizes');
}

// ---------------------------------------------------------------------------
// Web
// ---------------------------------------------------------------------------

void _web(Image art) {
  stdout.writeln('web');
  _write('web/favicon.png',
      _compose(art, 32, safeRadius: 0.46, background: _plate));

  for (final size in [192, 512]) {
    _write(
      'web/icons/Icon-$size.png',
      _compose(art, size,
          safeRadius: _plateSafeRadius, background: _plate, corner: 0.22),
    );
    _write(
      'web/icons/Icon-maskable-$size.png',
      // Full bleed: the browser supplies the mask, so the plate must reach the
      // edges and the artwork must stay inside the 80% safe circle.
      _compose(art, size, safeRadius: _maskableSafeRadius, background: _plate),
    );
  }
}
