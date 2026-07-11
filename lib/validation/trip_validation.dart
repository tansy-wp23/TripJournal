const kTripTitleMaxLength = 100;

/// Model-level invariant, reused as both the form field's live validator and
/// the controller's save-time backstop — see
/// IMPLEMENTATION_PLAN_VALIDATION.md "Where Validation Lives".
String? validateTripTitle(String? title) {
  final trimmed = title?.trim() ?? '';
  if (trimmed.isEmpty) return 'Please enter a trip title.';
  if (trimmed.length > kTripTitleMaxLength) {
    return 'Trip title must be $kTripTitleMaxLength characters or fewer.';
  }
  return null;
}

String? validateTripDateRange(DateTime startDate, DateTime endDate) {
  if (endDate.isBefore(startDate)) {
    return 'End date must be on or after the start date.';
  }
  return null;
}

/// Same cap as a journal entry's body (kEntryBodyMaxLength) — notes are free
/// text with no reason to have a different budget. See
/// IMPLEMENTATION_PLAN_INLINE_PHOTO.md §1.
const kTripNotesMaxLength = 5000;

String? validateTripNotesLength(String notes) {
  if (notes.length > kTripNotesMaxLength) {
    return 'Notes must be $kTripNotesMaxLength characters or fewer.';
  }
  return null;
}
