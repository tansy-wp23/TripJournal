String? validateMealName(String name) {
  if (name.trim().isEmpty) return 'Please enter a meal name.';
  return null;
}

/// Meal calories may be 0 (left blank defaults to 0 automatically — see the
/// meal dialog) but never negative.
String? validateMealCalories(int calories) {
  if (calories < 0) return 'Please enter a valid number.';
  return null;
}
