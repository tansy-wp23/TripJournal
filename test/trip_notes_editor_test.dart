import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/trip_repository_locator.dart';
import 'package:tripjournal/features/trip/trip_form_screen.dart';
import 'package:tripjournal/main.dart';

void main() {
  Future<void> openKyotoTripView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TripJournalApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kyoto Trip').last);
    await tester.pumpAndSettle();
  }

  group('notes inline editor (IMPLEMENTATION_PLAN_INLINE_PHOTO.md §1)', () {
    testWidgets('tapping the notes card opens a notes-only editor, pre-filled', (tester) async {
      await openKyotoTripView(tester);

      expect(find.text('Renew rail pass before boarding. Confirm ryokan check-in time.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('trip-notes-card')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Notes'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Renew rail pass before boarding. Confirm ryokan check-in time.'),
        findsOneWidget,
      );
      // Notes-only — no title/date/cover fields present.
      expect(find.byKey(const Key('trip-title-field')), findsNothing);
      expect(find.byKey(const Key('trip-start-date-field')), findsNothing);
    });

    testWidgets('editing and confirming Save persists the new notes and returns to trip view', (tester) async {
      await openKyotoTripView(tester);

      await tester.tap(find.byKey(const Key('trip-notes-card')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('trip-notes-editor-field')), 'Updated packing list.');
      await tester.tap(find.byKey(const Key('save-notes-button')));
      await tester.pumpAndSettle();

      expect(find.text('Save changes?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('notes-save-confirm-confirm')));
      await tester.pumpAndSettle();

      // Back on Trip View, showing the updated notes.
      expect(find.text('Edit Notes'), findsNothing);
      expect(find.text('Updated packing list.'), findsOneWidget);

      final trip = await tripRepository.getTrip('trip-001');
      expect(trip!.notes, 'Updated packing list.');
    });

    testWidgets('saving through the notes editor changes ONLY notes — title, dates, and cover are untouched', (
      tester,
    ) async {
      final before = await tripRepository.getTrip('trip-001');
      await openKyotoTripView(tester);

      await tester.tap(find.byKey(const Key('trip-notes-card')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('trip-notes-editor-field')), 'Only the notes should change.');
      await tester.tap(find.byKey(const Key('save-notes-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notes-save-confirm-confirm')));
      await tester.pumpAndSettle();

      final after = await tripRepository.getTrip('trip-001');
      expect(after!.notes, 'Only the notes should change.');
      expect(after.title, before!.title);
      expect(after.coverPhotoPath, before.coverPhotoPath);
      expect(after.startDate, before.startDate);
      expect(after.endDate, before.endDate);
      expect(after.id, before.id);
    });

    testWidgets('Cancel on the save dialog keeps you in the editor with input intact, unsaved', (tester) async {
      await openKyotoTripView(tester);

      await tester.tap(find.byKey(const Key('trip-notes-card')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('trip-notes-editor-field')), 'Not saved yet.');
      await tester.tap(find.byKey(const Key('save-notes-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notes-save-confirm-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Save changes?'), findsNothing);
      expect(find.text('Edit Notes'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Not saved yet.'), findsOneWidget);

      final trip = await tripRepository.getTrip('trip-001');
      expect(trip!.notes, isNot('Not saved yet.'));
    });

    testWidgets('an untouched editor leaves on back with no discard prompt', (tester) async {
      await openKyotoTripView(tester);

      await tester.tap(find.byKey(const Key('trip-notes-card')));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit Notes'), findsNothing);
    });

    testWidgets('editing then pressing back prompts "Discard changes?"; Discard leaves unsaved', (tester) async {
      await openKyotoTripView(tester);

      await tester.tap(find.byKey(const Key('trip-notes-card')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('trip-notes-editor-field')), 'Draft, never saved.');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('notes-discard-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Notes'), findsNothing);
      final trip = await tripRepository.getTrip('trip-001');
      expect(trip!.notes, isNot('Draft, never saved.'));
    });

    testWidgets('"Keep editing" dismisses the discard prompt and preserves the draft', (tester) async {
      await openKyotoTripView(tester);

      await tester.tap(find.byKey(const Key('trip-notes-card')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('trip-notes-editor-field')), 'Keep this draft.');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notes-discard-keep-editing')));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit Notes'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Keep this draft.'), findsOneWidget);
    });

    testWidgets('a trip with no notes shows an inviting placeholder, still tappable to add notes', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TripJournalApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Osaka Trip'));
      await tester.pumpAndSettle();

      expect(find.text('No notes yet — tap to add.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('trip-notes-card')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Notes'), findsOneWidget);
      expect(find.widgetWithText(TextField, ''), findsOneWidget);
    });

    testWidgets('the AppBar edit icon still opens the full trip-edit form, unaffected', (tester) async {
      await openKyotoTripView(tester);

      await tester.tap(find.byKey(const Key('trip-view-edit-button')));
      await tester.pumpAndSettle();

      expect(find.byType(TripFormScreen), findsOneWidget);
      expect(find.byKey(const Key('trip-title-field')), findsOneWidget);
    });
  });
}
