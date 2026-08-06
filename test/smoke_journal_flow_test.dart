import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_view_screen.dart';

void main() {
  testWidgets('create -> view -> edit -> delete golden path', (WidgetTester tester) async {
    // Tall virtual screen so the create/edit form never needs scrolling —
    // avoids scroll-helper flakiness around mid-animation frames.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Pump the trip view directly (Kyoto = trip-001) rather than the full
    // app: this golden-path test is about the journal flow, not auth
    // routing or Home's trip list.
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: TripViewScreen(tripId: 'trip-001'))));
    await tester.pumpAndSettle();

    // Trip View shows seeded mock entries grouped onto their days.
    expect(find.text('Fushimi Inari hike'), findsOneWidget);
    expect(find.textContaining('15,600 steps'), findsOneWidget);

    // Create a new entry via Day 1's "Add entry" action.
    await tester.tap(find.byKey(const Key('add-entry-day-1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('entry-title-field')), 'Widget test entry');
    await tester.enterText(find.byKey(const Key('entry-body-field')), 'Body written by the smoke test.');
    await tester.enterText(find.byKey(const Key('health-log-steps-field')), '4321');

    // Add a meal through the Health Log sub-form's dialog.
    await tester.tap(find.byKey(const Key('add-meal-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('meal-name-field')), 'Test Snack');
    await tester.enterText(find.byKey(const Key('meal-calories-field')), '200');
    await tester.tap(find.byKey(const Key('confirm-meal-button')));
    await tester.pumpAndSettle();

    expect(find.text('Total calories eaten: ~200 kcal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-confirm-confirm')));
    await tester.pumpAndSettle();

    // Stays on the entry screen after save (IMPLEMENTATION_PLAN_UX_AI.md §3)
    // — now titled "Edit entry" since it's persisted, button reads "Saved",
    // and the AI suggestion is generated and shown in place.
    expect(find.text('Edit entry'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byKey(const Key('ai-advice-text')), findsOneWidget);

    // Leave manually — back to Trip View.
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Day 1 now holds both the seeded entry and the new one (multiple
    // entries per day are allowed).
    expect(find.text('Widget test entry'), findsOneWidget);

    // Open detail screen.
    await tester.tap(find.text('Widget test entry'));
    await tester.pumpAndSettle();
    expect(find.text('Body written by the smoke test.'), findsOneWidget);
    expect(find.text('Test Snack'), findsOneWidget);

    // Edit it. (Trip View, underneath, has its own edit/delete icons now
    // that it's mounted in the same stack — use keys, not find.byIcon, to
    // avoid matching those instead.)
    await tester.tap(find.byKey(const Key('edit-entry-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('entry-title-field')), 'Widget test entry (edited)');
    await tester.tap(find.byKey(const Key('save-entry-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-confirm-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget); // still on the edit screen

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Widget test entry (edited)'), findsOneWidget); // back on Entry Detail

    // Delete it, with confirmation dialog.
    await tester.tap(find.byKey(const Key('delete-entry-button')));
    await tester.pumpAndSettle();
    expect(find.text('Delete entry?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Back on Trip View — the new entry is gone, the seeded one remains.
    expect(find.text('Widget test entry (edited)'), findsNothing);
    expect(find.text('Arrival in Kyoto'), findsOneWidget);
  });
}
