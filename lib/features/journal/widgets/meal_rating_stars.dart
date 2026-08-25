import 'package:flutter/material.dart';

/// A row of 5 stars showing (and, if [onChanged] is given, editing) a meal's
/// 1–5 rating. One widget serves both the editable meal dialog and every
/// read-only meal row — see `health_log_form.dart`, `entry_detail_screen.dart`.
class MealRatingStars extends StatelessWidget {
  const MealRatingStars({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 20,
  });

  final int? rating;

  /// Null makes the stars read-only display. When given, tapping star N sets
  /// the rating to N; tapping the currently-selected star again clears it
  /// (`IMPLEMENTATION_PLAN_RATING_LOCATION_SHOWCASE.md` §1 — "fixable
  /// mis-tap").
  final ValueChanged<int?>? onChanged;

  final double size;

  bool get _isEditable => onChanged != null;

  @override
  Widget build(BuildContext context) {
    final filledColor = Theme.of(context).colorScheme.primary;
    final outlineColor = Theme.of(context).colorScheme.outline;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          _star(
            star: star,
            filledColor: filledColor,
            outlineColor: outlineColor,
          ),
      ],
    );
  }

  Widget _star({
    required int star,
    required Color filledColor,
    required Color outlineColor,
  }) {
    final filled = rating != null && star <= rating!;
    final icon = Icon(
      filled ? Icons.star : Icons.star_border,
      size: size,
      color: filled ? filledColor : outlineColor,
    );

    if (!_isEditable) return icon;

    return InkWell(
      key: Key('meal-rating-star-$star'),
      customBorder: const CircleBorder(),
      onTap: () => onChanged!(rating == star ? null : star),
      child: Padding(padding: const EdgeInsets.all(2), child: icon),
    );
  }
}
