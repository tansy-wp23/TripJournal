import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/entry_timestamp.dart';

void main() {
  test('a day matching "now" returns the exact current moment (not midnight)', () {
    final now = DateTime(2026, 4, 10, 19, 45, 30);
    final result = deriveEntryTimestamp(DateTime(2026, 4, 10), now: now);
    expect(result, now);
  });

  test('a past day returns noon of that day, regardless of the input time-of-day', () {
    final now = DateTime(2026, 4, 12, 9, 0);
    final result = deriveEntryTimestamp(DateTime(2026, 4, 10, 23, 59), now: now);
    expect(result, DateTime(2026, 4, 10, 12));
  });

  test('only the calendar date of the day argument matters for the "is it today" check', () {
    final now = DateTime(2026, 4, 10, 8, 0);
    // Same calendar day as `now`, but a different time-of-day on the input —
    // must still be treated as "today" and return the real current moment.
    final result = deriveEntryTimestamp(DateTime(2026, 4, 10, 23, 0), now: now);
    expect(result, now);
  });
}
