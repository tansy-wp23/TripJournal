/// Reads steps + calories-burned from the phone's health platform (Apple
/// HealthKit / Android Health Connect) — never from a watch directly. The
/// watch syncs to the platform; this only reads from it.
///
/// Every value is nullable: permission may be denied, the platform may be
/// unavailable (e.g. desktop/emulator), or no data may exist for the date.
/// Callers MUST treat null as "fall back to manual entry" — steps and
/// calories-burned stay manually editable always, per
/// IMPLEMENTATION_PLAN_ENHANCEMENTS.md §1.
abstract class HealthDataSource {
  Future<int?> getStepsForDate(DateTime date);
  Future<int?> getCaloriesBurnedForDate(DateTime date);
  Future<bool> requestPermissions();
  Future<bool> hasPermissions();
}
