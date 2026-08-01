import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/screens/trip_wellness_screen.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';
import 'package:tripjournal/models/trip.dart';

Trip _trip() {
  final start = DateTime(2026, 4, 10);
  final end = DateTime(2026, 4, 12);
  return Trip(
    id: 't',
    userId: 'u',
    title: 'Bali',
    startDate: start,
    endDate: end,
    createdAt: start,
    updatedAt: start,
  );
}

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  required Mood mood,
  HealthLog? healthLog,
}) {
  return JournalEntry(
    id: id,
    tripId: 't',
    title: 'title-$id',
    body: 'body',
    mood: mood,
    photoPaths: const [],
    createdAt: createdAt,
    updatedAt: createdAt,
    healthLog: healthLog,
  );
}

void main() {
  testWidgets('shows the empty state when the trip has no entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TripWellnessScreen(trip: _trip(), entries: const []),
      ),
    );

    expect(find.text('No data yet'), findsOneWidget);
    expect(find.textContaining('Journal a day on this trip'), findsOneWidget);
  });

  testWidgets(
    'shows aggregated stats, steps chart, and mood breakdown when entries exist',
    (tester) async {
      final trip = _trip();
      final entries = [
        _entry(
          id: 'e1',
          createdAt: DateTime(2026, 4, 10),
          mood: Mood.happy,
          healthLog: const HealthLog(
            id: 'h1',
            entryId: 'e1',
            steps: 4000,
            caloriesEaten: 1200,
            meals: [],
          ),
        ),
        _entry(id: 'e2', createdAt: DateTime(2026, 4, 11), mood: Mood.happy),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: TripWellnessScreen(trip: trip, entries: entries),
        ),
      );

      expect(find.text('2 of 3 days journaled'), findsOneWidget);
      expect(find.text('4,000 total steps'), findsOneWidget);
      expect(find.text('Burned: — (no health data)'), findsOneWidget);
      expect(find.text('Steps per day'), findsOneWidget);
      expect(find.text('Mood breakdown'), findsOneWidget);
      expect(find.byKey(const Key('mood-bar-happy')), findsOneWidget);
      // 3 trip days -> 3 bars rendered.
      expect(find.byKey(const Key('steps-bar-0')), findsOneWidget);
      expect(find.byKey(const Key('steps-bar-2')), findsOneWidget);
    },
  );
}
