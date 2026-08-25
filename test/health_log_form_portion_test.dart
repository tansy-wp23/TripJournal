import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/widgets/health_log_form.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/portion_size.dart';

void main() {
  testWidgets('adding a meal defaults its portion to Regular', (tester) async {
    HealthLogFormData? latest;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HealthLogForm(tripId: 'trip-001', entryDate: DateTime(2026, 1, 1), onChanged: (data) => latest = data)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('meal-name-field')), 'Nasi lemak');
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    expect(latest!.meals.single.portion, PortionSize.regular);
    expect(find.textContaining('Regular'), findsOneWidget); // shown on the meal row
  });

  testWidgets('selecting a different portion in the add-meal dialog is reflected on save', (tester) async {
    HealthLogFormData? latest;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HealthLogForm(tripId: 'trip-001', entryDate: DateTime(2026, 1, 1), onChanged: (data) => latest = data)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('meal-name-field')), 'Nasi lemak');
    await tester.tap(find.descendant(
      of: find.byKey(const Key('meal-portion-selector')),
      matching: find.text('Large'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    expect(latest!.meals.single.portion, PortionSize.large);
    expect(find.textContaining('Large'), findsWidgets); // row shows the chosen portion
  });

  testWidgets('editing a meal pre-selects its existing portion', (tester) async {
    const seedMeal = Meal(
      id: 'meal-seed',
      name: 'Nasi lemak',
      calories: 900,
      mealType: MealType.lunch,
      portion: PortionSize.large,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HealthLogForm(tripId: 'trip-001', entryDate: DateTime(2026, 1, 1), initialMeals: const [seedMeal], onChanged: (_) {})),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-meal-0')));
    await tester.pumpAndSettle();

    final segmentedButton = tester.widget<SegmentedButton<PortionSize>>(
      find.byKey(const Key('meal-portion-selector')),
    );
    expect(segmentedButton.selected, {PortionSize.large});
  });

  testWidgets('the meal row shows portion and an estimate-prefixed calorie figure', (tester) async {
    const seedMeal = Meal(
      id: 'meal-seed',
      name: 'Nasi lemak',
      calories: 600,
      mealType: MealType.lunch,
      portion: PortionSize.large,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HealthLogForm(tripId: 'trip-001', entryDate: DateTime(2026, 1, 1), initialMeals: const [seedMeal], onChanged: (_) {})),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Lunch · Large · ~600 kcal'), findsOneWidget); // the meal row
    expect(find.text('Total calories eaten: ~600 kcal'), findsOneWidget); // the running total
  });

  group('portion scales the calorie estimate (IMPLEMENTATION_PLAN_UX_POLISH.md §1)', () {
    testWidgets('changing portion auto-fills a scaled calorie suggestion', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HealthLogForm(tripId: 'trip-001', entryDate: DateTime(2026, 1, 1), onChanged: (_) {})),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-meal-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('meal-name-field')), 'Nasi lemak');
      await tester.enterText(find.byKey(const Key('meal-calories-field')), '500'); // entered at Regular
      await tester.tap(find.descendant(
        of: find.byKey(const Key('meal-portion-selector')),
        matching: find.text('Large'),
      ));
      await tester.pumpAndSettle();

      // 500 (regular) * 1.4 (large) = 700 — suggested, not forced.
      expect(find.widgetWithText(TextField, '700'), findsOneWidget);
    });

    testWidgets('the auto-filled suggestion remains fully editable', (tester) async {
      HealthLogFormData? latest;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HealthLogForm(tripId: 'trip-001', entryDate: DateTime(2026, 1, 1), onChanged: (data) => latest = data)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-meal-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('meal-name-field')), 'Nasi lemak');
      await tester.enterText(find.byKey(const Key('meal-calories-field')), '500');
      await tester.tap(find.descendant(
        of: find.byKey(const Key('meal-portion-selector')),
        matching: find.text('Large'),
      ));
      await tester.pumpAndSettle();

      // Override the suggested 700 with the user's own figure.
      await tester.enterText(find.byKey(const Key('meal-calories-field')), '650');
      await tester.tap(find.byKey(const Key('confirm-meal-button')));
      await tester.pumpAndSettle();

      expect(latest!.meals.single.calories, 650); // final value wins, not the suggestion
    });

    testWidgets('a later override is what subsequent portion changes scale from, not the original entry', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HealthLogForm(tripId: 'trip-001', entryDate: DateTime(2026, 1, 1), onChanged: (_) {})),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-meal-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('meal-name-field')), 'Nasi lemak');
      await tester.enterText(find.byKey(const Key('meal-calories-field')), '500'); // at Regular
      await tester.tap(find.descendant(
        of: find.byKey(const Key('meal-portion-selector')),
        matching: find.text('Large'),
      ));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '700'), findsOneWidget); // 500 * 1.4

      // Override the Large suggestion with the user's own figure (at Large).
      await tester.enterText(find.byKey(const Key('meal-calories-field')), '650');

      await tester.tap(find.descendant(
        of: find.byKey(const Key('meal-portion-selector')),
        matching: find.text('Small'),
      ));
      await tester.pumpAndSettle();

      // 650 (large) normalized to regular is ~464.29, * 0.7 (small) rounds to 325.
      expect(find.widgetWithText(TextField, '325'), findsOneWidget);
    });

    testWidgets('changing portion with no calories entered yet leaves the field untouched', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HealthLogForm(tripId: 'trip-001', entryDate: DateTime(2026, 1, 1), onChanged: (_) {})),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-meal-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('meal-name-field')), 'Nasi lemak');
      await tester.tap(find.descendant(
        of: find.byKey(const Key('meal-portion-selector')),
        matching: find.text('Large'),
      ));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byKey(const Key('meal-calories-field')));
      expect(field.controller!.text, isEmpty); // no base yet — nothing to suggest
    });

    testWidgets('editing an existing meal scales further portion changes from its stored calories', (
      tester,
    ) async {
      const seedMeal = Meal(
        id: 'meal-seed',
        name: 'Nasi lemak',
        calories: 900, // entered at Large
        mealType: MealType.lunch,
        portion: PortionSize.large,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HealthLogForm(tripId: 'trip-001', entryDate: DateTime(2026, 1, 1), initialMeals: const [seedMeal], onChanged: (_) {})),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit-meal-0')));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byKey(const Key('meal-portion-selector')),
        matching: find.text('Regular'),
      ));
      await tester.pumpAndSettle();

      // 900 (large) normalized to regular: 900 / 1.4 ≈ 642.86, at Regular rounds to 643.
      expect(find.widgetWithText(TextField, '643'), findsOneWidget);
    });
  });
}
