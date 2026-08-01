import 'package:flutter/material.dart';

import '../../../models/mood.dart';
import '../../journal/widgets/mood_display.dart';

/// Mood distribution as a row of mini horizontal bars, one per [Mood],
/// each proportional to its share of [moodBreakdown]'s total.
class MoodBreakdownChart extends StatelessWidget {
  const MoodBreakdownChart({super.key, required this.moodBreakdown});

  final Map<Mood, int> moodBreakdown;

  @override
  Widget build(BuildContext context) {
    final total = moodBreakdown.values.fold<int>(0, (a, b) => a + b);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final mood in Mood.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(moodIcon(mood), size: 16),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: Text(
                    moodLabel(mood),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      key: Key('mood-bar-${mood.name}'),
                      value: total == 0 ? 0 : moodBreakdown[mood]! / total,
                      minHeight: 8,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  child: Text(
                    '${moodBreakdown[mood]}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
