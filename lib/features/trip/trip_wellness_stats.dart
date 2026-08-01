import '../../data/journal_repository.dart';
import '../../models/journal_entry.dart';
import '../../models/mood.dart';
import '../../models/trip.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Richer per-trip wellness aggregation for the dedicated "Trip Wellness"
/// view (IMPLEMENTATION_PLAN_EXTRA_FEATURES.md #1). This is a superset of
/// `trip_summary_stats.dart`'s `TripStats` (which stays as-is, feeding the
/// glanceable header row) — this one adds the breakdowns needed for charts.
/// NOT the AI Trip Recap (teammate's module) — pure numeric aggregation over
/// data already collected by the Journal module.
class TripWellnessStats {
  const TripWellnessStats({
    required this.totalSteps,
    required this.averageStepsPerDay,
    required this.totalCaloriesEaten,
    required this.totalCaloriesBurned,
    required this.moodBreakdown,
    required this.dominantMood,
    required this.entriesLogged,
    required this.daysLogged,
    required this.tripDays,
    required this.stepsPerDay,
  });

  final int totalSteps;

  /// totalSteps / daysLogged (days that actually have an entry) — NOT
  /// divided by the trip's full duration, since unlogged days would dilute
  /// this into a misleadingly low number. Zero when [daysLogged] is zero.
  final double averageStepsPerDay;

  final int totalCaloriesEaten;

  /// Same "null means no data at all, not zero" rule as `TripStats` — see
  /// trip_summary_stats.dart.
  final int? totalCaloriesBurned;

  /// Count per [Mood], including moods with zero entries — keeps chart
  /// rendering simple (every category always present).
  final Map<Mood, int> moodBreakdown;

  /// The most-logged mood. Null when there are no entries. Ties break by
  /// [Mood] enum declaration order.
  final Mood? dominantMood;

  /// Raw entry count — distinct from [daysLogged], since a day can hold
  /// more than one entry.
  final int entriesLogged;

  /// Distinct calendar days with at least one entry.
  final int daysLogged;

  final int tripDays;

  /// Summed steps per calendar day (date-only keys), for a steps-over-time
  /// chart. Only contains days that have at least one entry with a
  /// health log — days with no data are simply absent, not zero.
  final Map<DateTime, int> stepsPerDay;

  String get entriesLoggedSummary => '$daysLogged of $tripDays days journaled';
}

/// Pure aggregation — no I/O, trivial to unit test directly.
TripWellnessStats computeTripWellnessStats({
  required List<JournalEntry> entries,
  required Trip trip,
}) {
  var totalSteps = 0;
  var totalCaloriesEaten = 0;
  var totalCaloriesBurned = 0;
  var hasCaloriesBurnedData = false;
  final moodBreakdown = {for (final m in Mood.values) m: 0};
  final loggedDays = <DateTime>{};
  final stepsPerDay = <DateTime, int>{};

  for (final entry in entries) {
    moodBreakdown[entry.mood] = moodBreakdown[entry.mood]! + 1;
    final day = _dateOnly(entry.createdAt);
    loggedDays.add(day);

    final healthLog = entry.healthLog;
    if (healthLog != null) {
      totalSteps += healthLog.steps;
      totalCaloriesEaten += healthLog.caloriesEaten;
      stepsPerDay[day] = (stepsPerDay[day] ?? 0) + healthLog.steps;

      final caloriesBurned = healthLog.caloriesBurned;
      if (caloriesBurned != null) {
        totalCaloriesBurned += caloriesBurned;
        hasCaloriesBurnedData = true;
      }
    }
  }

  Mood? dominantMood;
  var highestCount = 0;
  for (final m in Mood.values) {
    final count = moodBreakdown[m]!;
    if (count > highestCount) {
      highestCount = count;
      dominantMood = m;
    }
  }

  return TripWellnessStats(
    totalSteps: totalSteps,
    averageStepsPerDay: loggedDays.isEmpty ? 0 : totalSteps / loggedDays.length,
    totalCaloriesEaten: totalCaloriesEaten,
    totalCaloriesBurned: hasCaloriesBurnedData ? totalCaloriesBurned : null,
    moodBreakdown: moodBreakdown,
    dominantMood: dominantMood,
    entriesLogged: entries.length,
    daysLogged: loggedDays.length,
    tripDays: trip.durationDays,
    stepsPerDay: stepsPerDay,
  );
}

/// Fetches [trip]'s journal entries via [journalRepository] and aggregates
/// them into a [TripWellnessStats]. Thin async wrapper around
/// [computeTripWellnessStats].
Future<TripWellnessStats> tripWellnessStatsForTrip(
  Trip trip,
  JournalRepository journalRepository,
) async {
  final entries = await journalRepository.getEntries(trip.id);
  return computeTripWellnessStats(entries: entries, trip: trip);
}
