import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/repository_locator.dart';
import 'package:tripjournal/main.dart';

void main() {
  testWidgets(
    'editing an existing meal on a saved entry recomputes and persists the '
    'caloriesEaten total — not just the sub-form display',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TripJournalApp());
      await tester.pumpAndSettle();

      // Seeded entry-1 ("Arrival in Kyoto") has three meals summing to
      // 350 + 650 + 950 = 1950 kcal.
      final before = await journalRepository.getEntry('entry-1');
      expect(before?.healthLog?.caloriesEaten, 1950);

      await tester.tap(find.text('Kyoto Trip').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arrival in Kyoto'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-entry-button')));
      await tester.pumpAndSettle();

      // meal-row-2 is the third seeded meal, "Kaiseki dinner" (950 kcal).
      await tester.tap(find.byKey(const Key('edit-meal-2')));
      await tester.pumpAndSettle();
      expect(find.text('Edit meal'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Kaiseki dinner'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('meal-calories-field')), '1200');
      await tester.tap(find.byKey(const Key('confirm-meal-button')));
      await tester.pumpAndSettle();

      expect(find.text('Total calories eaten: ~2200 kcal'), findsOneWidget); // 350 + 650 + 1200

      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-confirm-confirm')));
      await tester.pumpAndSettle();

      final after = await journalRepository.getEntry('entry-1');
      expect(after?.healthLog?.caloriesEaten, 2200);
      // Steps and the meal's identity/name are untouched by the edit.
      expect(after?.healthLog?.steps, before?.healthLog?.steps);
      expect(after?.healthLog?.meals.length, 3);
      expect(after?.healthLog?.meals[2].name, 'Kaiseki dinner');
      expect(after?.healthLog?.meals[2].calories, 1200);
    },
  );
}
