import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tripjournal/data/trip_repository_locator.dart';
import 'package:tripjournal/features/home/home_screen.dart';

void main() {
  Future<void> openKyotoTrip(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kyoto Trip').last);
    await tester.pumpAndSettle();
  }

  testWidgets('edits, saves, and reopens a persisted trip summary', (
    tester,
  ) async {
    final original = await tripRepository.getTrip('trip-001');
    await tripRepository.updateTrip(
      original!.copyWith(summary: 'Original generated summary.'),
    );
    addTearDown(() => tripRepository.updateTrip(original));

    await openKyotoTrip(tester);
    expect(find.text('Original generated summary.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-trip-summary-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('trip-summary-editor-field')),
      'My edited Kyoto summary.',
    );
    await tester.tap(find.byKey(const Key('save-trip-summary-button')));
    await tester.pumpAndSettle();

    expect(find.text('My edited Kyoto summary.'), findsOneWidget);
    expect(
      (await tripRepository.getTrip('trip-001'))!.summary,
      'My edited Kyoto summary.',
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kyoto Trip').last);
    await tester.pumpAndSettle();
    expect(find.text('My edited Kyoto summary.'), findsOneWidget);
  });

  testWidgets('Cancel discards summary edits without saving', (tester) async {
    final original = await tripRepository.getTrip('trip-001');
    await tripRepository.updateTrip(
      original!.copyWith(summary: 'Saved summary.'),
    );
    addTearDown(() => tripRepository.updateTrip(original));

    await openKyotoTrip(tester);
    await tester.tap(find.byKey(const Key('edit-trip-summary-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('trip-summary-editor-field')),
      'Discard this draft.',
    );
    await tester.tap(find.byKey(const Key('cancel-edit-trip-summary-button')));
    await tester.pumpAndSettle();

    expect(find.text('Saved summary.'), findsOneWidget);
    expect(
      (await tripRepository.getTrip('trip-001'))!.summary,
      'Saved summary.',
    );
  });

  testWidgets('generated summary is persisted before it is shown', (
    tester,
  ) async {
    final original = await tripRepository.getTrip('trip-001');
    addTearDown(() => tripRepository.updateTrip(original!));

    await openKyotoTrip(tester);
    await tester.tap(find.byKey(const Key('generate-trip-summary-button')));
    await tester.pumpAndSettle();

    final persisted = await tripRepository.getTrip('trip-001');
    expect(persisted!.summary, isNotNull);
    expect(persisted.summary, isNotEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kyoto Trip').last);
    await tester.pumpAndSettle();
    expect(find.text(persisted.summary!), findsOneWidget);
  });
}
