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