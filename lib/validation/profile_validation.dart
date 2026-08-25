const kProfileDisplayNameMaxLength = 50;

/// Model-level invariant for the profile's display name, reused as both the
/// form field's live validator and the controller's save-time backstop —
/// see IMPLEMENTATION_PLAN_VALIDATION.md "Where Validation Lives".
///
/// `email` is deliberately NOT validated here — it's owned by Google/Supabase
/// Auth and is not independently editable (Phase 3 decision, noted in
/// `docs/user-management/PROGRESS.md`).
String? validateProfileDisplayName(String? displayName) {
  final trimmed = displayName?.trim() ?? '';
  if (trimmed.isEmpty) return 'Please enter a display name.';
  if (trimmed.length > kProfileDisplayNameMaxLength) {
    return 'Display name must be $kProfileDisplayNameMaxLength characters or fewer.';
  }
  return null;
}

/// The fixed set of travel-interest tags offered on the onboarding and
/// profile-edit screens. A `List`, not a `Set` — display order on the chip
/// grid should stay stable and match this declaration order.
const List<String> kTravelInterestOptions = [
  'Scenery',
  'History',
  'Culture',
  'Food',
  'Adventure',
  'Relaxation',
  'Nature',
  'Nightlife',
];

/// Optional field — a `null` date of birth is always valid (Profile
/// Onboarding is skippable; nothing here is mandatory). When a date is
/// given, only rejects a physically impossible value: in the future, or
/// before anyone alive today could have been born.
String? validateDateOfBirth(DateTime? dateOfBirth) {
  if (dateOfBirth == null) return null;
  final now = DateTime.now();
  if (dateOfBirth.isAfter(now)) {
    return 'Date of birth cannot be in the future.';
  }
  if (dateOfBirth.isBefore(DateTime(1900))) {
    return 'Please enter a valid date of birth.';
  }
  return null;
}