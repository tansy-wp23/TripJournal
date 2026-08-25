import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/screens/entry_detail_screen.dart';
import 'package:tripjournal/features/trip/screens/food_showcase_screen.dart';
import 'package:tripjournal/features/trip/trip_photos.dart';

void main() {
  testWidgets('shows a friendly empty state when there are no food photos', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FoodShowcaseScreen(photos: [])),
    );

    expect(find.byKey(const Key('food-showcase-empty-title')), findsOneWidget);
  });

  testWidgets('groups photos by day, in day order', (tester) async {
    final photos = [
      TripPhoto(
        path: 'assets/mock/day1_food.jpg',
        kind: TripPhotoKind.meal,
        entryId: 'entry-1',
        date: DateTime(2026, 8, 10),
        dayNumber: 1,
        caption: 'Ramen',
      ),
      TripPhoto(
        path: 'assets/mock/day2_food.jpg',
        kind: TripPhotoKind.meal,
        entryId: 'entry-2',
        date: DateTime(2026, 8, 11),
        dayNumber: 2,
        caption: 'Okonomiyaki',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: FoodShowcaseScreen(photos: photos)),
    );

    expect(find.byKey(const Key('food-showcase-day-header-1')), findsOneWidget);
    expect(find.byKey(const Key('food-showcase-day-header-2')), findsOneWidget);
    expect(find.text('Ramen'), findsOneWidget);
    expect(find.text('Okonomiyaki'), findsOneWidget);
  });

  testWidgets('tapping a food photo navigates to its owning entry', (
    tester,
  ) async {
    final photo = TripPhoto(
      path: 'assets/mock/day1_food.jpg',
      kind: TripPhotoKind.meal,
      entryId: 'entry-1',
      date: DateTime(2026, 8, 10),
      dayNumber: 1,
      caption: 'Ramen',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: FoodShowcaseScreen(photos: [photo])),
      ),
    );

    await tester.tap(
      find.byKey(const Key('food-showcase-photo-assets/mock/day1_food.jpg')),
    );
    await tester.pumpAndSettle();

    final entryScreen = tester.widget<EntryDetailScreen>(
      find.byType(EntryDetailScreen),
    );
    expect(entryScreen.entryId, 'entry-1');
  });
}
