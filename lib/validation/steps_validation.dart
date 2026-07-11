/// "Trust the user" — permissive up to this threshold; the Confirmed
/// Validation Rules table calls it a "soft cap" but is explicit that
/// exceeding it should reject the save, so it's enforced the same way as
/// any other blocking inline validation (see IMPLEMENTATION_PLAN_VALIDATION.md).
const kStepsSoftCap = 100000;

String? validateSteps(int steps) {
  if (steps < 0) return 'Please enter a valid number.';
  if (steps > kStepsSoftCap) return 'That step count seems unusually high — please check.';
  return null;
}
