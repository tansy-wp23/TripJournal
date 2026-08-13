import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/screens/entry_detail_screen.dart';
import 'package:tripjournal/features/trip/screens/trip_photo_slideshow_screen.dart';
import 'package:tripjournal/features/trip/trip_photos.dart';

TripPhoto _photo({
  required String path,
  required int dayNumber,
  String entryId = 'entry-1',
  TripPhotoKind kind = TripPhotoKind.entry,
  String? caption,
}) {
  return TripPhoto(
    path: path,
    kind: kind,
    entryId: entryId,
    date: DateTime(2026, 4, 9 + dayNumber),
    dayNumber: dayNumber,
    caption: caption,
  );
}

/// Day 1 has two photos, day 2 has two, day 3 has one — enough to swipe
/// across a boundary in both directions.
final _photos = [
  _photo(path: 'd1-a.jpg', dayNumber: 1, caption: 'Arrival'),
  _photo(path: 'd1-b.jpg', dayNumber: 1, caption: 'Arrival'),
  _photo(path: 'd2-a.jpg', dayNumber: 2, caption: 'Gion'),
  _photo(path: 'd2-meal.jpg', dayNumber: 2, kind: TripPhotoKind.meal, caption: 'Nasi lemak'),
  _photo(path: 'd3-a.jpg', dayNumber: 3, entryId: 'entry-3', caption: 'Fushimi Inari'),
];

Widget _wrapped(List<TripPhoto> photos, int initialIndex) {
  // ProviderScope because "open entry" pushes EntryDetailScreen, which is a
  // ConsumerWidget.
  return ProviderScope(
    child: MaterialApp(
      home: TripPhotoSlideshowScreen(photos: photos, initialIndex: initialIndex),
    ),
  );
}

Future<void> _swipeForward(WidgetTester tester) async {
  await tester.fling(
    find.byKey(const Key('trip-slideshow-page-view')),
    const Offset(-400, 0),
    1000,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the requested photo', (tester) async {
    await tester.pumpWidget(_wrapped(_photos, 2));
    await tester.pumpAndSettle();

    expect(find.text('Day 2 · Apr 11, 2026 · 3 of 5'), findsOneWidget);
    expect(find.byKey(const Key('trip-slideshow-caption')), findsOneWidget);
    expect(find.text('Gion'), findsOneWidget);
  });

  testWidgets('swiping past a day boundary rolls the header on to the next day', (tester) async {
    // The whole point of the agreed design: entering a day opens the trip, not
    // a dead end at that day's last photo.
    await tester.pumpWidget(_wrapped(_photos, 1)); // last photo of day 1
    await tester.pumpAndSettle();
    expect(find.text('Day 1 · Apr 10, 2026 · 2 of 5'), findsOneWidget);

    await _swipeForward(tester);

    expect(find.text('Day 2 · Apr 11, 2026 · 3 of 5'), findsOneWidget);
  });

  testWidgets('the caption follows the current photo, naming the meal for food pics', (tester) async {
    await tester.pumpWidget(_wrapped(_photos, 2));
    await tester.pumpAndSettle();
    expect(find.text('Gion'), findsOneWidget);

    await _swipeForward(tester);

    expect(find.text('Nasi lemak'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
  });

  testWidgets('"open entry" navigates to the entry the current photo belongs to', (tester) async {
    await tester.pumpWidget(_wrapped(_photos, 4)); // day 3, entry-3
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('slideshow-go-to-entry')));
    await tester.pumpAndSettle();

    expect(find.byType(EntryDetailScreen), findsOneWidget);
  });

  testWidgets('the close button dismisses the slideshow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TripPhotoSlideshowScreen(photos: _photos, initialIndex: 0),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('trip-slideshow-close-button')));
    await tester.pumpAndSettle();

    expect(find.byType(TripPhotoSlideshowScreen), findsNothing);
  });

  testWidgets('an empty photo list shows an empty state instead of throwing', (tester) async {
    await tester.pumpWidget(_wrapped(const [], 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No photos yet.'), findsOneWidget);
    expect(find.byKey(const Key('slideshow-go-to-entry')), findsNothing);
  });

  testWidgets('an out-of-range initial index is clamped rather than throwing', (tester) async {
    await tester.pumpWidget(_wrapped(_photos, 99));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Day 3 · Apr 12, 2026 · 5 of 5'), findsOneWidget);
  });

  testWidgets('dangling paths render placeholders, not a crash', (tester) async {
    await tester.pumpWidget(_wrapped(_photos, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.broken_image_outlined), findsWidgets);
  });
}
