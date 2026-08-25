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

/// Rating is optional — a meal with no rating (`null`) is always valid.
/// The UI (5 tappable stars) can't produce anything outside 1–5, but this is
/// the same backstop `Meal`'s own constructor assert enforces, kept
/// consistent with how every other meal field is validated in this file.
String? validateMealRating(int? rating) {
  if (rating == null) return null;
  if (rating < 1 || rating > 5) return 'Rating must be between 1 and 5 stars.';
  return null;
}
