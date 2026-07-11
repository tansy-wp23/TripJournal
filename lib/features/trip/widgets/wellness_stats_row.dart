import 'package:flutter/material.dart';

import '../../journal/widgets/format_utils.dart';
import '../../journal/widgets/mood_display.dart';
import '../trip_summary_stats.dart';
import 'stat_tile.dart';

/// Row of glanceable [TripStats] tiles — shared between the homepage
/// wellness strip and the Trip View header, per
/// IMPLEMENTATION_PLAN_HOMEPAGE.md ("the same TripStats summary").
class WellnessStatsRow extends StatelessWidget {
  const WellnessStatsRow({super.key, required this.stats});

  final TripStats stats;

  @override
  Widget build(BuildContext context) {
    final averageMood = stats.averageMood;
    final totalCaloriesBurned = stats.totalCaloriesBurned;
    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.directions_walk,
            label: '${formatThousands(stats.totalSteps)} steps',
          ),
        ),
        Expanded(
          child: StatTile(
            icon: averageMood == null ? Icons.mood : moodIcon(averageMood),
            label: averageMood == null ? 'No mood yet' : moodLabel(averageMood),
          ),
        ),
        Expanded(
          child: StatTile(
            icon: Icons.restaurant,
            label: 'Eaten: ${formatThousands(stats.totalCaloriesEaten)} kcal',
          ),
        ),
        Expanded(
          child: StatTile(
            icon: Icons.local_fire_department,
            label: totalCaloriesBurned != null
                ? 'Burned: ${formatThousands(totalCaloriesBurned)} kcal'
                : 'Burned: — (no health data)',
          ),
        ),
        Expanded(
          child: StatTile(icon: Icons.calendar_today, label: stats.daysLoggedSummary),
        ),
      ],
    );
  }
}
