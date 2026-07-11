import '../../data/journal_repository.dart';
import '../../models/journal_entry.dart';
import '../../models/mood.dart';
import '../../models/trip.dart';

/// Wellbeing scale used to average [Mood] values — kept in one place per
/// IMPLEMENTATION_PLAN_HOMEPAGE.md Phase 3 (1 = stressed .. 5 = excited).
const Map<Mood, int> moodScale = {
  Mood.stressed: 1,
  Mood.tired: 2,
  Mood.neutral: 3,
  Mood.happy: 4,
  Mood.excited: 5,
};

Mood _moodClosestToScore(int score) {
  var closest = Mood.neutral;
  var smallestDiff = 1 << 30;
  for (final entry in moodScale.entries) {
    final diff = (score - entry.value).abs();
    if (diff < smallestDiff) {
      smallestDiff = diff;
      closest = entry.key;
    }
  }
  return closest;
}

/// Simple numeric aggregation over a trip's journal entries, for the
/// dashboard/trip-view "wellness strip". This is NOT the AI Trip Recap
/// (that's Module 2's job) — just totals over data already collected.
class TripStats {
  const TripStats({
    required this.totalSteps,
    required this.totalCaloriesEaten,
    required this.totalCaloriesBurned,
    required this.averageMood,
    required this.daysLogged,
    required this.totalDays,
  });

  final int totalSteps;
  final int totalCaloriesEaten;

  /// Sum of calories burned across entries that have health-platform data.
  /// Null when NOT A SINGLE entry has calories-burned data (denied
  /// permission / no device the whole trip) — the UI must show a graceful
  /// "no health data" placeholder in that case, never a bare 0. Kept
  /// entirely separate from [totalCaloriesEaten] — no net figure, see
  /// IMPLEMENTATION_PLAN_ENHANCEMENTS.md §2.
  final int? totalCaloriesBurned;

  /// Null when the trip has no journal entries yet.
  final Mood? averageMood;

  /// Number of distinct calendar days with at least one journal entry —
  /// NOT a raw entry count, since a day may hold multiple entries.
  final int daysLogged;
  final int totalDays;

  String get daysLoggedSummary => '$daysLogged of $totalDays days logged';
}

/// Pure aggregation — no I/O, so it's trivial to unit test directly.
TripStats computeTripStats({
  required List<JournalEntry> entries,
  required int totalDays,
}) {
  var totalSteps = 0;
  var totalCaloriesEaten = 0;
  var totalCaloriesBurned = 0;
  var hasCaloriesBurnedData = false;
  final moodScores = <int>[];
  final loggedDays = <DateTime>{};

  for (final entry in entries) {
    final healthLog = entry.healthLog;
    if (healthLog != null) {
      totalSteps += healthLog.steps;
      totalCaloriesEaten += healthLog.caloriesEaten;
      final caloriesBurned = healthLog.caloriesBurned;
      if (caloriesBurned != null) {
        totalCaloriesBurned += caloriesBurned;
        hasCaloriesBurnedData = true;
      }
    }
    moodScores.add(moodScale[entry.mood]!);
    loggedDays.add(DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day));
  }

  final averageMood = moodScores.isEmpty
      ? null
      : _moodClosestToScore((moodScores.reduce((a, b) => a + b) / moodScores.length).round());

  return TripStats(
    totalSteps: totalSteps,
    totalCaloriesEaten: totalCaloriesEaten,
    totalCaloriesBurned: hasCaloriesBurnedData ? totalCaloriesBurned : null,
    averageMood: averageMood,
    daysLogged: loggedDays.length,
    totalDays: totalDays,
  );
}

/// Fetches [trip]'s journal entries via [journalRepository] and aggregates
/// them into a [TripStats]. Thin async wrapper around [computeTripStats].
Future<TripStats> tripStatsForTrip(Trip trip, JournalRepository journalRepository) async {
  final entries = await journalRepository.getEntries(trip.id);
  return computeTripStats(entries: entries, totalDays: trip.durationDays);
}
