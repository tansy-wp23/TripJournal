import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/main.dart';

void main() {
  testWidgets(
    'cover photo picker offers camera and gallery, matching the journal entry photo flow',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TripJournalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Trip'));
      await tester.pumpAndSettle();

      expect(find.text('No cover photo added.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-cover-photo-button')));
      await tester.pumpAndSettle();

      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);

      // Under `flutter test` there's no interactive file dialog to complete,
      // so the real picker resolves with nothing picked — same behaviour as
      // a user backing out on a real device. Must not crash or get stuck.
      await tester.tap(find.byKey(const Key('pick-cover-photo-gallery')));
      await tester.pumpAndSettle();

      expect(find.text('No cover photo added.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
