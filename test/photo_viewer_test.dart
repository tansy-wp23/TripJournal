import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/screens/entry_detail_screen.dart';
import 'package:tripjournal/features/journal/screens/photo_viewer_screen.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';

void main() {
  Future<void> openEntryDetail(WidgetTester tester, String entryId) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Pump the trip view directly (Kyoto = trip-001) rather than the full
    // app: these tests are about the photo viewer, not auth routing or
    // Home's trip list.
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: 'trip-001'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('entry-tile-$entryId')));
    await tester.pumpAndSettle();
  }

  group('full-screen photo viewer (IMPLEMENTATION_PLAN_INLINE_PHOTO.md §2)', () {
    testWidgets('tapping a thumbnail opens the viewer at the tapped index, with a page counter', (tester) async {
      // entry-1 ("Arrival in Kyoto") is seeded with 2 photos.
      await openEntryDetail(tester, 'entry-1');

      await tester.tap(find.byKey(const Key('photo-thumbnail-1')));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget); // opened at index 1 (the 2nd photo)
    });

    testWidgets('opening the first thumbnail starts the counter at 1', (tester) async {
      await openEntryDetail(tester, 'entry-1');

      await tester.tap(find.byKey(const Key('photo-thumbnail-0')));
      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('swiping moves to the next photo and updates the counter', (tester) async {
      await openEntryDetail(tester, 'entry-1');

      await tester.tap(find.byKey(const Key('photo-thumbnail-0')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);

      await tester.fling(find.byKey(const Key('photo-viewer-page-view')), const Offset(-400, 0), 800);
      await tester.pumpAndSettle();

      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('shows a broken-image placeholder, not a crash, for the mock (non-real) file paths', (
      tester,
    ) async {
      await openEntryDetail(tester, 'entry-1');

      await tester.tap(find.byKey(const Key('photo-thumbnail-0')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('a single-photo entry shows no page counter', (tester) async {
      // entry-2 ("Fushimi Inari hike") is seeded with exactly 1 photo.
      await openEntryDetail(tester, 'entry-2');

      await tester.tap(find.byKey(const Key('photo-thumbnail-0')));
      await tester.pumpAndSettle();

      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('the close (×) button dismisses back to the entry', (tester) async {
      await openEntryDetail(tester, 'entry-1');

      await tester.tap(find.byKey(const Key('photo-thumbnail-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-viewer-close-button')));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(find.byType(EntryDetailScreen), findsOneWidget);
    });

    testWidgets('tapping the image (tap-outside style dismiss) also returns to the entry', (tester) async {
      await openEntryDetail(tester, 'entry-1');

      await tester.tap(find.byKey(const Key('photo-thumbnail-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoViewerScreen), findsNothing);
    });

    testWidgets('system back also dismisses the viewer', (tester) async {
      await openEntryDetail(tester, 'entry-1');

      await tester.tap(find.byKey(const Key('photo-thumbnail-0')));
      await tester.pumpAndSettle();

      // The AppBar's leading is a custom × icon, not Flutter's standard back
      // button, so `pageBack()` (which looks for that specific widget)
      // doesn't apply here — simulate the actual OS back gesture instead.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(find.byType(EntryDetailScreen), findsOneWidget);
    });
  });
}
