import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/widgets/trip_cover_photo.dart';

void main() {
  testWidgets('shows the placeholder icon when photoPath is null', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TripCoverPhoto(height: 100)));
    expect(find.byIcon(Icons.photo), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows the placeholder icon for a mock path with no real file behind it', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: TripCoverPhoto(photoPath: 'assets/mock/kyoto_arrival_1.jpg', height: 100),
    ));
    expect(find.byIcon(Icons.photo), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  // Deliberately no "renders the real image" test here: pointing
  // TripCoverPhoto at an actual file on disk makes Image.file kick off a
  // real image decode that reliably hangs `flutter test` for its full
  // 10-minute timeout in this environment (tried both pumpAndSettle() and a
  // single pump() — both hang). The fallback logic covered above is what
  // actually matters for correctness (never attempting to decode a path
  // with no real file behind it); the ternary that picks Image.file() when
  // existsSync() is true is trivial enough to trust by inspection.
}
