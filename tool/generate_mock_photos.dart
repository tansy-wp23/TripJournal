// Generates the placeholder JPEGs behind the seeded `assets/mock/...` paths in
// `mock_journal_repository.dart` and `mock_trip_repository.dart`.
//
// Those paths have always been dangling, which was invisible while photos only
// ever appeared as small thumbnails, but makes the trip carousel and slideshow
// look broken on a fresh checkout. Generated rather than checked-in stock
// photography so there is no licensing question and the repo stays small.
//
// Run from the project root:  dart run tool/generate_mock_photos.dart
import 'dart:io';

import 'package:image/image.dart';

/// name -> (top colour, bottom colour, caption)
const _photos = <String, (int, int, int, int, int, int, String)>{
  'kyoto_arrival_1': (240, 180, 120, 120, 60, 90, 'Kyoto - Arrival'),
  'gion_evening': (70, 40, 90, 20, 15, 40, 'Gion - Evening'),
  'fushimi_inari_gates': (220, 90, 50, 130, 40, 30, 'Fushimi Inari'),
  'dotonbori_night': (30, 40, 90, 90, 30, 70, 'Dotonbori - Night'),
  // A seeded *meal* photo, so the food-photo half of the trip carousel (and
  // its toggle) is visible without having to pick from the device gallery.
  'ramen_lunch': (250, 220, 160, 170, 90, 40, 'Ramen - Lunch'),
};

void main() {
  final dir = Directory('assets/mock');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  for (final entry in _photos.entries) {
    final (r1, g1, b1, r2, g2, b2, caption) = entry.value;
    final image = Image(width: 1200, height: 800);

    for (var y = 0; y < image.height; y++) {
      final t = y / (image.height - 1);
      final r = (r1 + (r2 - r1) * t).round();
      final g = (g1 + (g2 - g1) * t).round();
      final b = (b1 + (b2 - b1) * t).round();
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    drawString(
      image,
      caption,
      font: arial48,
      x: 48,
      y: image.height - 96,
      color: ColorRgb8(255, 255, 255),
    );

    final file = File('${dir.path}/${entry.key}.jpg');
    file.writeAsBytesSync(encodeJpg(image, quality: 82));
    stdout.writeln('wrote ${file.path} (${file.lengthSync()} bytes)');
  }
}
