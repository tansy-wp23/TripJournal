import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/widgets/photo_thumbnail.dart';

Widget wrapped(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows a placeholder icon, not a crash, for a missing/nonexistent file', (tester) async {
    await tester.pumpWidget(wrapped(const PhotoThumbnail(photoPath: 'assets/mock/does_not_exist.jpg')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renders as a fixed square regardless of size', (tester) async {
    await tester.pumpWidget(wrapped(const PhotoThumbnail(photoPath: 'assets/mock/missing.jpg', size: 100)));
    await tester.pumpAndSettle();

    final box = tester.getSize(find.byType(PhotoThumbnail));
    expect(box.width, 100);
    expect(box.height, 100);
  });

  testWidgets('no remove affordance is shown when onRemove is null (read-only display)', (tester) async {
    await tester.pumpWidget(wrapped(const PhotoThumbnail(photoPath: 'assets/mock/missing.jpg')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cancel), findsNothing);
  });

  testWidgets('tapping the remove affordance invokes onRemove', (tester) async {
    var removed = false;
    await tester.pumpWidget(wrapped(PhotoThumbnail(
      photoPath: 'assets/mock/missing.jpg',
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
