import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_photos.dart';
import 'package:tripjournal/features/trip/widgets/trip_cover_photo.dart';
import 'package:tripjournal/features/trip/widgets/trip_photo_carousel.dart';

TripPhoto _photo(String path, {int dayNumber = 1, TripPhotoKind kind = TripPhotoKind.entry}) {
  return TripPhoto(
    path: path,
    kind: kind,
    entryId: 'entry-1',
    date: DateTime(2026, 4, 9 + dayNumber),
    dayNumber: dayNumber,
    caption: path,
  );
}

Widget _wrapped({
  required List<TripPhoto> photos,
  String? coverPhotoPath,
  ValueChanged<TripPhoto>? onPhotoTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: TripPhotoCarousel(
        photos: photos,
        coverPhotoPath: coverPhotoPath,
        onPhotoTap: onPhotoTap ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('renders one page and one dot per photo', (tester) async {
    await tester.pumpWidget(_wrapped(photos: [_photo('a.jpg'), _photo('b.jpg'), _photo('c.jpg')]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-photo-carousel')), findsOneWidget);
    expect(find.byKey(const Key('trip-carousel-dot-0')), findsOneWidget);
    expect(find.byKey(const Key('trip-carousel-dot-1')), findsOneWidget);
    expect(find.byKey(const Key('trip-carousel-dot-2')), findsOneWidget);
    expect(find.byKey(const Key('trip-carousel-dot-3')), findsNothing);
  });

  testWidgets('swiping advances to the next page', (tester) async {
    await tester.pumpWidget(_wrapped(photos: [_photo('a.jpg'), _photo('b.jpg')]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-carousel-page-0')), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('trip-photo-carousel')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-carousel-page-1')), findsOneWidget);
  });

  testWidgets('a trip with no photos falls back to the cover photo, with no carousel', (tester) async {
    await tester.pumpWidget(_wrapped(photos: const [], coverPhotoPath: 'assets/mock/cover.jpg'));
    await tester.pumpAndSettle();

    expect(find.byType(TripCoverPhoto), findsOneWidget);
    expect(find.byKey(const Key('trip-photo-carousel')), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(find.byKey(const Key('trip-carousel-dot-0')), findsNothing);
  });

  testWidgets('a trip with no photos and no cover still renders without crashing', (tester) async {
    await tester.pumpWidget(_wrapped(photos: const []));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TripCoverPhoto), findsOneWidget);
  });

  testWidgets('tapping a page hands back that photo, not its index', (tester) async {
    // Index would be ambiguous: the carousel can show a filtered subset while
    // the slideshow shows everything.
    final photos = [_photo('a.jpg'), _photo('b.jpg')];
    TripPhoto? tapped;

    await tester.pumpWidget(_wrapped(photos: photos, onPhotoTap: (photo) => tapped = photo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('trip-carousel-page-0')));
    await tester.pumpAndSettle();

    expect(identical(tapped, photos.first), isTrue);
  });

  testWidgets('dangling photo paths render a placeholder rather than throwing', (tester) async {
    // Seeded mock data points at assets/mock/*.jpg with no file behind it.
    await tester.pumpWidget(_wrapped(photos: [_photo('assets/mock/nothing-here.jpg')]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('occupies exactly the height the cover photo used to', (tester) async {
    // The trip timeline's tests reach keys far down the list; growing the
    // header would push them out of the built window.
    await tester.pumpWidget(_wrapped(photos: [_photo('a.jpg')]));
    await tester.pumpAndSettle();

    final carousel = tester.getSize(find.byType(TripPhotoCarousel));
    expect(carousel.height, 160);
  });
}
