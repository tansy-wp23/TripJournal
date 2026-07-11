/// Derives the timestamp to stamp a NEW journal entry with, given the
/// calendar day the user is writing for.
///
/// - Today gets the real current time, so same-day entries still order
///   correctly by time-of-day (multiple entries per day is allowed).
/// - A backfilled past day has no "current time" to speak of, so it gets a
///   fixed noon default — arbitrary but consistent.
///
/// Future days are not special-cased here — the caller is responsible for
/// rejecting them before calling this (future days are blocked entirely,
/// see IMPLEMENTATION_PLAN_ENHANCEMENTS.md §5).
DateTime deriveEntryTimestamp(DateTime day, {DateTime? now}) {
  final effectiveNow = now ?? DateTime.now();
  final today = DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);
  final dayOnly = DateTime(day.year, day.month, day.day);
  if (dayOnly.isAtSameMomentAs(today)) return effectiveNow;
  return DateTime(dayOnly.year, dayOnly.month, dayOnly.day, 12);
}
