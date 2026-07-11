enum PortionSize { small, regular, large }

/// Scales a base (regular-portion) calorie estimate into a suggested value
/// for the chosen portion. See IMPLEMENTATION_PLAN_UX_POLISH.md §1 — the
/// result is always an editable suggestion, never a locked figure.
extension PortionSizeCalorieMultiplier on PortionSize {
  double get calorieMultiplier {
    switch (this) {
      case PortionSize.small:
        return 0.7;
      case PortionSize.regular:
        return 1.0;
      case PortionSize.large:
        return 1.4;
    }
  }
}
