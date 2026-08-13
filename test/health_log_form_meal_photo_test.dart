import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/photo_storage.dart';
import 'package:tripjournal/features/journal/widgets/health_log_form.dart';
import 'package:tripjournal/features/journal/widgets/photo_thumbnail.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';

class _RecordingPhotoStorage implements PhotoStorage {
  final List<String> saved = [];
  final List<String?> deleted = [];

  @override
  Future<String> savePhoto(XFile photo) async {
    saved.add(photo.path);
    return '/app/photos/copied.jpg';
  }

  @override
  Future<void> deletePhoto(String? path) async => deleted.add(path);
}

const _photographedMeal = Meal(
  id: 'meal-1',
  name: 'Nasi lemak',
  calories: 600,
  mealType: MealType.breakfast,
  photoPath: '/app/photos/nasi-lemak.jpg',
);

Widget _form({
  required ValueChanged<HealthLogFormData> onChanged,
  List<Meal> initialMeals = const [],
  PhotoStorage? photoStorage,
}) {
  return MaterialApp(
    home: Scaffold(
      body: HealthLogForm(
        entryDate: DateTime(2026, 1, 1),
        initialMeals: initialMeals,
        photoStorage: photoStorage,
        onChanged: onChanged,
      ),
    ),
  );
}

void main() {
  testWidgets('a meal logged from a photo shows that photo in the meal list', (tester) async {
    await tester.pumpWidget(_form(onChanged: (_) {}, initialMeals: const [_photographedMeal]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-row-photo-0')), findsOneWidget);
    // The seeded path has no file behind it — a missing photo must degrade to
    // a placeholder, never a crash.
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hand-typed meal shows no photo', (tester) async {
    const typed = Meal(id: 'm', name: 'Toast', calories: 200, mealType: MealType.breakfast);
    await tester.pumpWidget(_form(onChanged: (_) {}, initialMeals: const [typed]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-row-photo-0')), findsNothing);
  });

  testWidgets('editing a meal pre-fills its existing photo and keeps it on save', (tester) async {
    HealthLogFormData? latest;
    await tester.pumpWidget(_form(
      onChanged: (data) => latest = data,
      initialMeals: const [_photographedMeal],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-meal-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-photo-thumbnail')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('meal-calories-field')), '700');
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    expect(latest!.meals.single.calories, 700);
    expect(latest!.meals.single.photoPath, '/app/photos/nasi-lemak.jpg');
  });

  testWidgets('removing the photo in the dialog drops it from the saved meal', (tester) async {
    HealthLogFormData? latest;
    await tester.pumpWidget(_form(
      onChanged: (data) => latest = data,
      initialMeals: const [_photographedMeal],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-meal-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remove-meal-photo')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-photo-thumbnail')), findsNothing);

    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    expect(latest!.meals.single.photoPath, isNull);
    expect(find.byKey(const Key('meal-row-photo-0')), findsNothing);
  });

  testWidgets('removing a photo never deletes the meal\'s already-saved file', (tester) async {
    // The user can still cancel out of the dialog, which would leave the meal
    // pointing at a file we had already deleted.
    final storage = _RecordingPhotoStorage();
    await tester.pumpWidget(_form(
      onChanged: (_) {},
      initialMeals: const [_photographedMeal],
      photoStorage: storage,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-meal-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remove-meal-photo')));
    await tester.pumpAndSettle();

    expect(storage.deleted, isEmpty);
  });

  testWidgets('backing out of the picker stores nothing and leaves the dialog usable', (tester) async {
    // Under `flutter test` the real ImagePicker resolves with nothing picked —
    // the same outcome as a user dismissing the OS picker.
    final storage = _RecordingPhotoStorage();
    HealthLogFormData? latest;
    await tester.pumpWidget(_form(onChanged: (data) => latest = data, photoStorage: storage));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detect-from-photo-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detect-photo-gallery')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(storage.saved, isEmpty);
    expect(find.byKey(const Key('meal-photo-thumbnail')), findsNothing);

    await tester.enterText(find.byKey(const Key('meal-name-field')), 'Fried rice');
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    expect(latest!.meals.single.name, 'Fried rice');
    expect(latest!.meals.single.photoPath, isNull);
  });

  testWidgets('the meal photo renders through the shared PhotoThumbnail', (tester) async {
    await tester.pumpWidget(_form(onChanged: (_) {}, initialMeals: const [_photographedMeal]));
    await tester.pumpAndSettle();

    final thumbnail = tester.widget<PhotoThumbnail>(find.byKey(const Key('meal-row-photo-0')));
    expect(thumbnail.photoPath, '/app/photos/nasi-lemak.jpg');
    // Read-only in the list: no remove badge outside the edit dialog.
    expect(thumbnail.onRemove, isNull);
  });
}
