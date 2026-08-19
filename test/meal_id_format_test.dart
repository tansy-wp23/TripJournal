import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/widgets/health_log_form.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';

/// `meals.id` is a `uuid` column (`tripjournal_schema.sql`), so a newly added
/// meal has to carry a real UUID.
///
/// This exists because it did not. Meal ids were minted as
/// `meal-<microsecondsSinceEpoch>`, which every mock-mode test and every
/// unit test of `SupabaseJournalRepository` accepted happily — the fake
/// Postgrest client has no column types, and the fixtures all used
/// hand-written UUIDs. The first thing that ever disagreed was Postgres
/// itself, on a device, with `22P02 invalid input syntax for type uuid`, and
/// only after `BACKEND_MODE=supabase` was switched on. Asserting the *format*
/// at the point of creation is what closes that gap.
final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

void main() {
  testWidgets('a newly added meal gets a UUID the meals table will accept', (
    tester,
  ) async {
    HealthLogFormData? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HealthLogForm(
            tripId: 'trip-001',
            entryDate: DateTime(2026, 1, 1),
            onChanged: (data) => latest = data,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('meal-name-field')), 'Ramen');
    await tester.enterText(find.byKey(const Key('meal-calories-field')), '550');
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    final meal = latest!.meals.single;
    expect(meal.name, 'Ramen');
    expect(
      meal.id,
      matches(_uuidPattern),
      reason:
          'meals.id is a uuid column — a non-UUID id fails the insert with '
          '22P02 the moment BACKEND_MODE=supabase is used',
    );
  });

  testWidgets('editing a meal keeps its existing id rather than reminting', (
    tester,
  ) async {
    // The repository replaces meals wholesale on save, so a changing id would
    // not corrupt anything — but it would churn primary keys on every edit and
    // make the rows impossible to follow in the database.
    const existing = Meal(
      id: '55555555-5555-4555-8555-555555555555',
      name: 'Ramen',
      calories: 550,
      mealType: MealType.lunch,
    );

    HealthLogFormData? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HealthLogForm(
            tripId: 'trip-001',
            entryDate: DateTime(2026, 1, 1),
            initialMeals: const [existing],
            onChanged: (data) => latest = data,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-meal-0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('meal-calories-field')), '900');
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    expect(latest!.meals.single.id, existing.id);
    expect(latest!.meals.single.calories, 900);
  });
}
