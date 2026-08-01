import 'package:flutter/material.dart';

import '../../../models/journal_entry.dart';
import '../../../models/trip.dart';
import '../../journal/widgets/format_utils.dart';
import '../trip_wellness_stats.dart';
import '../widgets/mood_breakdown_chart.dart';
import '../widgets/steps_per_day_chart.dart';
import '../widgets/stat_tile.dart';

/// Dedicated per-trip wellness view (IMPLEMENTATION_PLAN_EXTRA_FEATURES.md
/// #1) — a fuller breakdown than the glanceable [WellnessStatsRow] on the
/// trip header. Reads through already-loaded entries (no extra I/O); pure
/// presentation over [computeTripWellnessStats].
class TripWellnessScreen extends StatelessWidget {
  const TripWellnessScreen({
    super.key,
    required this.trip,
    required this.entries,
  });

  final Trip trip;
  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final stats = computeTripWellnessStats(entries: entries, trip: trip);

    return Scaffold(
      appBar: AppBar(title: Text('${trip.title} — Wellness')),
      body: entries.isEmpty
          ? const _EmptyWellnessState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  stats.entriesLoggedSummary,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.directions_walk,
                        label:
                            '${formatThousands(stats.totalSteps)} total steps',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        icon: Icons.speed,
                        label:
                            '${stats.averageStepsPerDay.round()} avg steps/day',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.restaurant,
                        label:
                            'Eaten: ${formatThousands(stats.totalCaloriesEaten)} kcal',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        icon: Icons.local_fire_department,
                        label: stats.totalCaloriesBurned != null
                            ? 'Burned: ${formatThousands(stats.totalCaloriesBurned!)} kcal'
                            : 'Burned: — (no health data)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Steps per day',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                StepsPerDayChart(
                  tripDays: trip.dayList,
                  stepsPerDay: stats.stepsPerDay,
                ),
                const SizedBox(height: 24),
                Text(
                  'Mood breakdown',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                MoodBreakdownChart(moodBreakdown: stats.moodBreakdown),
              ],
            ),
    );
  }
}

class _EmptyWellnessState extends StatelessWidget {
  const _EmptyWellnessState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.query_stats,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No data yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Journal a day on this trip to start seeing your wellness stats here.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
