import 'package:flutter/material.dart';

import '../../../models/mood.dart';

IconData moodIcon(Mood mood) {
  switch (mood) {
    case Mood.happy:
      return Icons.sentiment_satisfied_alt;
    case Mood.excited:
      return Icons.emoji_emotions;
    case Mood.tired:
      return Icons.bedtime;
    case Mood.stressed:
      return Icons.sentiment_very_dissatisfied;
    case Mood.neutral:
      return Icons.sentiment_neutral;
  }
}

String moodLabel(Mood mood) {
  switch (mood) {
    case Mood.happy:
      return 'Happy';
    case Mood.excited:
      return 'Excited';
    case Mood.tired:
      return 'Tired';
    case Mood.stressed:
      return 'Stressed';
    case Mood.neutral:
      return 'Neutral';
  }
}
