import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/data/mock_trip_repository.dart';
import 'package:tripjournal/features/trip/trip_summary_stats.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

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
  group('computeTripStats', () {
    test('sums steps/calories eaten and counts distinct logged days, not raw entry count', () {
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
        // Same calendar day as e1 — should not double-count the day.
        _entry(
          id: 'e2',
          createdAt: DateTime(2026, 4, 10, 20),
          mood: Mood.excited,
          // No caloriesBurned (denied/no device that day) — should not
          // block the running total, just be excluded from it.
          healthLog: const HealthLog(id: 'h2', entryId: 'e2', steps: 2000, caloriesEaten: 700, meals: []),
        ),
        // No health log at all — should not blow up totals.
        _entry(id: 'e3', createdAt: DateTime(2026, 4, 11), mood: Mood.stressed),
      ];

      final stats = computeTripStats(entries: entries, totalDays: 5);

      expect(stats.totalSteps, 3000);
      expect(stats.totalCaloriesEaten, 1200);
      expect(stats.totalCaloriesBurned, 300); // only e1 had data — partial sum, not null
      expect(stats.daysLogged, 2);
      expect(stats.totalDays, 5);
      expect(stats.daysLoggedSummary, '2 of 5 days logged');
      // moods: happy(4), excited(5), stressed(1) -> avg 3.33 -> round 3 -> neutral
      expect(stats.averageMood, Mood.neutral);
    });

    test('totalCaloriesBurned is null (not zero) when no entry has burned data', () {
      final entries = [
        _entry(
          id: 'e1',
          createdAt: DateTime(2026, 4, 10),
          mood: Mood.neutral,
          healthLog: const HealthLog(id: 'h1', entryId: 'e1', steps: 1000, caloriesEaten: 500, meals: []),
        ),
      ];

      final stats = computeTripStats(entries: entries, totalDays: 1);

      expect(stats.totalCaloriesBurned, isNull);
      expect(stats.totalCaloriesEaten, 500); // caloriesEaten is unaffected — always summed
    });

    test('empty entries produce zero totals, null burned calories, and a null average mood', () {
      final stats = computeTripStats(entries: const [], totalDays: 4);
      expect(stats.totalSteps, 0);
      expect(stats.totalCaloriesEaten, 0);
      expect(stats.totalCaloriesBurned, isNull);
      expect(stats.daysLogged, 0);
      expect(stats.averageMood, isNull);
      expect(stats.daysLoggedSummary, '0 of 4 days logged');
    });

    test('a single mood rounds to itself', () {
      final stats = computeTripStats(
        entries: [_entry(id: 'e1', createdAt: DateTime(2026, 1, 1), mood: Mood.tired)],
        totalDays: 1,
      );
      expect(stats.averageMood, Mood.tired);
    });
  });

  test('tripStatsForTrip pulls entries via the journal repository for a real seeded trip', () async {
    final trip = await MockTripRepository().getTrip('trip-001');
    final stats = await tripStatsForTrip(trip!, MockJournalRepository());

    expect(stats.daysLogged, 3); // entry-1..3, three distinct April days
    expect(stats.totalSteps, 8200 + 15600 + 3100);
    expect(stats.totalCaloriesEaten, 1950 + 2400 + 1600);
    // entry-3's healthLog seeds caloriesBurned: null — entry-1/2 have data,
    // so the total is the partial sum of the known days, not null.
    expect(stats.totalCaloriesBurned, 2350 + 3100);
    expect(stats.totalDays, trip.durationDays);
  });
}
