import 'package:flutter/material.dart';

import '../../../models/mood.dart';
import 'mood_display.dart';

class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.selected, required this.onSelected});

  final Mood selected;
  final ValueChanged<Mood> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final mood in Mood.values)
          ChoiceChip(
            avatar: Icon(moodIcon(mood), size: 18),
            label: Text(moodLabel(mood)),
            selected: mood == selected,
            onSelected: (_) => onSelected(mood),
          ),
      ],
    );
  }
}
