import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/widgets/health_log_form.dart';

void main() {
  testWidgets('the meal dialog offers an optional "Detect from photo" action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HealthLogForm(entryDate: DateTime(2026, 1, 1), onChanged: (_) {})),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detect-from-photo-button')), findsOneWidget);
    expect(find.text('Detect from photo'), findsOneWidget);
  });

  testWidgets('tapping "Detect from photo" offers camera and gallery, matching the entry photo flow', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HealthLogForm(entryDate: DateTime(2026, 1, 1), onChanged: (_) {})),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detect-from-photo-button')));
    await tester.pumpAndSettle();

    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
  });

  testWidgets(
    'a picker result of "nothing picked" is a no-op — no crash, no stuck loading state, '
    'and manual entry still fully works',
    (tester) async {
      HealthLogFormData? latest;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HealthLogForm(entryDate: DateTime(2026, 1, 1), onChanged: (data) => latest = data)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-meal-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detect-from-photo-button')));
      await tester.pumpAndSettle();

      // Under `flutter test` there's no interactive file dialog, so the real
      // ImagePicker call resolves with nothing picked — the same outcome as
      // a user backing out of the OS picker on a real device.
      await tester.tap(find.byKey(const Key('detect-photo-gallery')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('detect-from-photo-loading')), findsNothing);
      expect(find.text('Detect from photo'), findsOneWidget); // button reverted, not stuck

      // The photo path is a convenience only — manual entry must still work
      // entirely on its own.
      await tester.enterText(find.byKey(const Key('meal-name-field')), 'Fried rice');
      await tester.enterText(find.byKey(const Key('meal-calories-field')), '550');
      await tester.tap(find.byKey(const Key('confirm-meal-button')));
      await tester.pumpAndSettle();

      expect(latest!.meals.single.name, 'Fried rice');
      expect(latest!.meals.single.calories, 550);
    },
  );
}
