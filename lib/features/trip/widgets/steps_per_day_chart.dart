import 'package:flutter/material.dart';

import '../../journal/widgets/format_utils.dart';

/// Simple styled-bar chart of steps per trip day — deliberately not a chart
/// library dependency (none is already in the project; see
/// IMPLEMENTATION_PLAN_EXTRA_FEATURES.md #1, "avoid a new dependency").
class StepsPerDayChart extends StatelessWidget {
  const StepsPerDayChart({
    super.key,
    required this.tripDays,
    required this.stepsPerDay,
  });

  /// Every calendar day of the trip, in order (Trip.dayList).
  final List<DateTime> tripDays;

  /// Date-only keys -> summed steps that day. A missing key means no data
  /// that day, rendered as an empty/placeholder bar, not a zero-height one.
  final Map<DateTime, int> stepsPerDay;

  static const double _maxBarHeight = 100;

  @override
  Widget build(BuildContext context) {
    final maxSteps = stepsPerDay.values.isEmpty
        ? 0
        : stepsPerDay.values.reduce((a, b) => a > b ? a : b);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < tripDays.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Bar(
                    key: Key('steps-bar-$i'),
                    steps: stepsPerDay[tripDays[i]],
                    maxSteps: maxSteps,
                    maxHeight: _maxBarHeight,
                    color: colorScheme.primary,
                    emptyColor: colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'D${i + 1}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.steps,
    required this.maxSteps,
    required this.maxHeight,
    required this.color,
    required this.emptyColor,
  });

  final int? steps;
  final int maxSteps;
  final double maxHeight;
  final Color color;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    final hasData = steps != null;
    final height = !hasData || maxSteps == 0
        ? 4.0
        : (steps! / maxSteps) * maxHeight;
    return Tooltip(
      message: hasData ? '${formatThousands(steps!)} steps' : 'No data',
      child: Container(
        width: 18,
        height: height.clamp(4.0, maxHeight),
        decoration: BoxDecoration(
          color: hasData ? color : emptyColor,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
