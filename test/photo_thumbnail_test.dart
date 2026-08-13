import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/widgets/photo_thumbnail.dart';

Widget wrapped(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // Deliberately a device-style path, not an `assets/` one: `assets/` now
  // routes to Image.asset (seed data points at real bundled photos), so it is
  // no longer a stand-in for "this file isn't there".
  const missingFile = '/no/such/directory/does_not_exist.jpg';

  testWidgets('shows a placeholder icon, not a crash, for a missing/nonexistent file', (tester) async {
    await tester.pumpWidget(wrapped(const PhotoThumbnail(photoPath: missingFile)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('an asset path that is not bundled still degrades to the placeholder', (tester) async {
    await tester.pumpWidget(wrapped(const PhotoThumbnail(photoPath: 'assets/mock/not_bundled.jpg')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('a bundled asset renders the real image', (tester) async {
    await tester.pumpWidget(wrapped(const PhotoThumbnail(photoPath: 'assets/mock/gion_evening.jpg')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });

  testWidgets('renders as a fixed square regardless of size', (tester) async {
    await tester.pumpWidget(wrapped(const PhotoThumbnail(photoPath: missingFile, size: 100)));
    await tester.pumpAndSettle();

    final box = tester.getSize(find.byType(PhotoThumbnail));
    expect(box.width, 100);
    expect(box.height, 100);
  });

  testWidgets('no remove affordance is shown when onRemove is null (read-only display)', (tester) async {
    await tester.pumpWidget(wrapped(const PhotoThumbnail(photoPath: missingFile)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cancel), findsNothing);
  });

  testWidgets('tapping the remove affordance invokes onRemove', (tester) async {
    var removed = false;
    await tester.pumpWidget(wrapped(PhotoThumbnail(
      photoPath: missingFile,
      onRemove: () => removed = true,
      removeButtonKey: const Key('remove-photo-0'),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('remove-photo-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('remove-photo-0')));
    await tester.pump();

    expect(removed, isTrue);
  });
}
