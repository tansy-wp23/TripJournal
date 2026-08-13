import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/screens/trip_photo_slideshow_screen.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';
import 'package:tripjournal/features/trip/widgets/trip_photo_carousel.dart';

// Seeded trip-001 ("Kyoto Trip") photos, in the order buildTripPhotos emits —
// entry photos first, then that entry's meal photos:
//   index 0, 1 -> day 1, entry-1's own photos ("Arrival in Kyoto")
//   index 2    -> day 1, entry-1's meal photo (the seeded Ramen lunch)
//   index 3    -> day 2, entry-2's photo ("Fushimi Inari hike")
//   day 3      -> no photos
const _totalTripPhotos = 4;
const _firstPhotoOfDay2 = 3;

Widget _wrapped() {
  return const ProviderScope(
    child: MaterialApp(home: TripViewScreen(tripId: 'trip-001')),
  );
}

Future<void> _pumpTripView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_wrapped());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the trip header shows a carousel of every photo in the trip', (tester) async {
    await _pumpTripView(tester);

    expect(find.byType(TripPhotoCarousel), findsOneWidget);
    expect(find.byKey(const Key('trip-carousel-dot-0')), findsOneWidget);
    expect(find.byKey(const Key('trip-carousel-dot-3')), findsOneWidget);
    expect(find.byKey(const Key('trip-carousel-dot-4')), findsNothing);
  });

  testWidgets('days with photos show a strip, days without show none', (tester) async {
    await _pumpTripView(tester);

    expect(find.byKey(const Key('day-photo-strip-1')), findsOneWidget);
    expect(find.byKey(const Key('day-photo-strip-2')), findsOneWidget);
    // Day 3's entry has no photos — the strip is omitted entirely rather than
    // reserved as blank space, so day tile heights don't shift.
    expect(find.byKey(const Key('day-photo-strip-3')), findsNothing);
  });

  testWidgets('tapping a day thumbnail opens the slideshow at that photo in the whole trip', (
    tester,
  ) async {
    await _pumpTripView(tester);

    await tester.tap(find.byKey(const Key('day-photo-2-0')));
    await tester.pumpAndSettle();

    final slideshow = tester.widget<TripPhotoSlideshowScreen>(
      find.byType(TripPhotoSlideshowScreen),
    );
    // Day 2's only photo is the fourth in the trip — and the slideshow gets
    // the full list, so the user can keep swiping back into day 1.
    expect(slideshow.photos.length, _totalTripPhotos);
    expect(slideshow.initialIndex, _firstPhotoOfDay2);
    expect(find.text('Day 2 · Apr 11, 2026 · 4 of 4'), findsOneWidget);
  });

  testWidgets('tapping day 1\'s second thumbnail opens on that exact photo', (tester) async {
    await _pumpTripView(tester);

    await tester.tap(find.byKey(const Key('day-photo-1-1')));
    await tester.pumpAndSettle();

    final slideshow = tester.widget<TripPhotoSlideshowScreen>(
      find.byType(TripPhotoSlideshowScreen),
    );
    expect(slideshow.initialIndex, 1);
  });

  testWidgets('tapping the header carousel opens the slideshow on the same photo', (tester) async {
    await _pumpTripView(tester);

    await tester.tap(find.byKey(const Key('trip-carousel-page-0')));
    await tester.pumpAndSettle();

    final slideshow = tester.widget<TripPhotoSlideshowScreen>(
      find.byType(TripPhotoSlideshowScreen),
    );
    expect(slideshow.initialIndex, 0);
    expect(slideshow.photos.length, _totalTripPhotos);
  });

  testWidgets('with a filter active, day photo indices are still the unfiltered ones', (
    tester,
  ) async {
    // The trap this guards: displayDayGroups is rebuilt from filteredEntries,
    // so a day strip derived from its own group would hand the slideshow an
    // index computed against a different list — opening the wrong photo.
    await _pumpTripView(tester);

    await tester.tap(find.byKey(const Key('trip-view-search-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fushimi');
    await tester.pumpAndSettle(const Duration(seconds: 1)); // debounce

    // Only day 2 survives the filter, but its photo is still trip photo #4.
    expect(find.byKey(const Key('day-photo-strip-1')), findsNothing);

    await tester.tap(find.byKey(const Key('day-photo-2-0')));
    await tester.pumpAndSettle();

    final slideshow = tester.widget<TripPhotoSlideshowScreen>(
      find.byType(TripPhotoSlideshowScreen),
    );
    expect(slideshow.photos.length, _totalTripPhotos);
    expect(slideshow.initialIndex, _firstPhotoOfDay2);
  });

  testWidgets('a trip with no photos keeps its plain cover photo', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // trip-003 ("Taipei Trip") is seeded in the future with no entries at all.
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: TripViewScreen(tripId: 'trip-003')),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-photo-carousel')), findsNothing);
    expect(find.byKey(const Key('day-photo-strip-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
