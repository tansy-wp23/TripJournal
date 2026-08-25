import 'package:flutter/material.dart';

import '../../../validation/profile_validation.dart';

/// Multi-select chip grid over [kTravelInterestOptions]. Used by both the
/// onboarding screen and the profile edit screen — kept as one widget rather
/// than duplicated so the two never drift.
class TravelInterestSelector extends StatelessWidget {
  const TravelInterestSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final interest in kTravelInterestOptions)
          FilterChip(
            key: Key('travel-interest-chip-$interest'),
            label: Text(interest),
            selected: selected.contains(interest),
            onSelected: (isSelected) {
              final next = Set<String>.from(selected);
              if (isSelected) {
                next.add(interest);
              } else {
                next.remove(interest);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}
