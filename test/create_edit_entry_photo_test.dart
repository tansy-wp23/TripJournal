import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/main.dart';

void main() {
  testWidgets(
    'picker sheet offers camera and gallery, and a picker result of "nothing '
    'picked" leaves the form untouched and still saveable without a photo',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TripJournalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kyoto Trip').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-entry-day-1')));
      await tester.pumpAndSettle();

      expect(find.text('No photos added.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-photo-button')));
      await tester.pumpAndSettle();
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);

      // Under `flutter test` there's no interactive file dialog to complete,
      // so the real ImagePicker call resolves with nothing picked (the same
      // outcome as a user backing out of the OS picker on a real device).
      // The form must treat that as a no-op, not a crash or a stuck loading
      // state — no photo is added and the rest of the entry stays editable.
      await tester.tap(find.byKey(const Key('pick-photo-gallery')));
      await tester.pumpAndSettle();

      expect(find.text('No photos added.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The entry must still be fully saveable with no photo attached.
      await tester.enterText(find.byKey(const Key('entry-title-field')), 'No photo entry');
      await tester.enterText(find.byKey(const Key('entry-body-field')), 'Saved without a photo.');
      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-confirm-confirm')));
      await tester.pumpAndSettle();

      // Stays on the entry screen after save (IMPLEMENTATION_PLAN_UX_AI.md §3).
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Edit entry'), findsOneWidget);
    },
  );
}
