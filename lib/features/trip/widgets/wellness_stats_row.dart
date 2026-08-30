import 'package:flutter/material.dart';

import '../../journal/widgets/format_utils.dart';
import '../../journal/widgets/mood_display.dart';
import '../trip_summary_stats.dart';
import 'stat_tile.dart';

/// Row of glanceable [TripStats] tiles — shared between the homepage
/// wellness strip and the Trip View header, per
/// IMPLEMENTATION_PLAN_HOMEPAGE.md ("the same TripStats summary").
class WellnessStatsRow extends StatelessWidget {
  const WellnessStatsRow({
    super.key,
    required this.stats,
    this.compact = false,
    this.foregroundColor,
  });

  final TripStats stats;
  final bool compact;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final averageMood = stats.averageMood;
    final totalCaloriesBurned = stats.totalCaloriesBurned;
    final tiles = <Widget>[
      StatTile(
        icon: Icons.directions_walk,
        label: '${formatThousands(stats.totalSteps)} steps',
        foregroundColor: foregroundColor,
      ),
      StatTile(
        icon: averageMood == null ? Icons.mood : moodIcon(averageMood),
        label: averageMood == null ? 'No mood yet' : moodLabel(averageMood),
        foregroundColor: foregroundColor,
      ),
      if (!compact)
        StatTile(
          icon: Icons.restaurant,
          label: 'Eaten: ${formatThousands(stats.totalCaloriesEaten)} kcal',
          foregroundColor: foregroundColor,
        ),
      if (!compact)
        StatTile(
          icon: Icons.local_fire_department,
          label: totalCaloriesBurned != null
              ? 'Burned: ${formatThousands(totalCaloriesBurned)} kcal'
              : 'Burned: — (no health data)',
          foregroundColor: foregroundColor,
        ),
      StatTile(
        icon: Icons.calendar_today,
        label: stats.daysLoggedSummary,
        foregroundColor: foregroundColor,
      ),
    ];

    return Row(
      children: [
        for (var index = 0; index < tiles.length; index++) ...[
          Expanded(child: tiles[index]),
          if (index != tiles.length - 1)
            Container(
              width: 1,
              height: 36,
              color: foregroundColor?.withValues(alpha: 0.24),
            ),
        ],
      ],
    );
  }
}
