import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_wellness_stats.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';
import 'package:tripjournal/models/trip.dart';

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

Trip _trip({required DateTime start, required DateTime end}) {
  return Trip(
    id: 't',
    userId: 'u',
    title: 'Trip',
    startDate: start,
    endDate: end,
    createdAt: start,
    updatedAt: start,
  );
}

void main() {
  group('computeTripWellnessStats', () {
    test(
      'aggregates steps/calories/mood breakdown across entries on different days',
      () {
        final trip = _trip(
          start: DateTime(2026, 4, 10),
          end: DateTime(2026, 4, 14),
        );
        final entries = [
          _entry(
            id: 'e1',
            createdAt: DateTime(2026, 4, 10, 9),
            mood: Mood.happy,
            healthLog: const HealthLog(
              id: 'h1',
              entryId: 'e1',
              steps: 1000,
              caloriesEaten: 500,
              caloriesBurned: 300,
              meals: [],
            ),
          ),
          _entry(
            id: 'e2',
            createdAt: DateTime(2026, 4, 11, 20),
            mood: Mood.happy,
            healthLog: const HealthLog(
              id: 'h2',
              entryId: 'e2',
              steps: 3000,
              caloriesEaten: 700,
              meals: [],
            ),
          ),
          _entry(
            id: 'e3',
            createdAt: DateTime(2026, 4, 12),
            mood: Mood.stressed,
          ),
        ];

        final stats = computeTripWellnessStats(entries: entries, trip: trip);

        expect(stats.totalSteps, 4000);
        expect(stats.averageStepsPerDay, 4000 / 3); // 3 distinct logged days
        expect(stats.totalCaloriesEaten, 1200);
        expect(stats.totalCaloriesBurned, 300); // only e1 has burned data
        expect(stats.moodBreakdown[Mood.happy], 2);
        expect(stats.moodBreakdown[Mood.stressed], 1);
        expect(stats.moodBreakdown[Mood.neutral], 0);
        expect(stats.dominantMood, Mood.happy);
        expect(stats.entriesLogged, 3);
        expect(stats.daysLogged, 3);
        expect(stats.tripDays, 5);
        expect(stats.entriesLoggedSummary, '3 of 5 days journaled');
        expect(stats.stepsPerDay[DateTime(2026, 4, 10)], 1000);
        expect(stats.stepsPerDay[DateTime(2026, 4, 11)], 3000);
        expect(
          stats.stepsPerDay.containsKey(DateTime(2026, 4, 12)),
          isFalse,
        ); // no health log that day
      },
    );

    test('sums same-day entries into one stepsPerDay bucket', () {
      final trip = _trip(
        start: DateTime(2026, 4, 10),
        end: DateTime(2026, 4, 10),
      );
      final entries = [
        _entry(
          id: 'e1',
          createdAt: DateTime(2026, 4, 10, 8),
          mood: Mood.neutral,
          healthLog: const HealthLog(
            id: 'h1',
            entryId: 'e1',
            steps: 500,
            caloriesEaten: 200,
            meals: [],
          ),
        ),
        _entry(
          id: 'e2',
          createdAt: DateTime(2026, 4, 10, 21),
          mood: Mood.neutral,
          healthLog: const HealthLog(
            id: 'h2',
            entryId: 'e2',
            steps: 700,
            caloriesEaten: 300,
            meals: [],
          ),
        ),
      ];

      final stats = computeTripWellnessStats(entries: entries, trip: trip);

      expect(stats.stepsPerDay.length, 1);
      expect(stats.stepsPerDay[DateTime(2026, 4, 10)], 1200);
      expect(stats.daysLogged, 1);
      expect(stats.entriesLogged, 2);
    });

    test(
      'empty entries produce zeroed stats, null burned calories, and a null dominant mood',
      () {
        final trip = _trip(
          start: DateTime(2026, 4, 10),
          end: DateTime(2026, 4, 13),
        );
        final stats = computeTripWellnessStats(entries: const [], trip: trip);

        expect(stats.totalSteps, 0);
        expect(stats.averageStepsPerDay, 0);
        expect(stats.totalCaloriesEaten, 0);
        expect(stats.totalCaloriesBurned, isNull);
        expect(stats.dominantMood, isNull);
        expect(stats.entriesLogged, 0);
        expect(stats.daysLogged, 0);
        expect(stats.tripDays, 4);
        expect(stats.stepsPerDay, isEmpty);
        for (final mood in Mood.values) {
          expect(stats.moodBreakdown[mood], 0);
        }
      },
    );

    test('mood tie breaks by Mood enum declaration order', () {
      final trip = _trip(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 1),
      );
      final entries = [
        _entry(id: 'e1', createdAt: DateTime(2026, 1, 1, 1), mood: Mood.tired),
        _entry(id: 'e2', createdAt: DateTime(2026, 1, 1, 2), mood: Mood.happy),
      ];

      final stats = computeTripWellnessStats(entries: entries, trip: trip);

      // Mood.values order is [happy, tired, excited, stressed, neutral] —
      // happy is checked first and both have count 1, so happy wins the tie.
      expect(stats.dominantMood, Mood.happy);
    });
  });
}
