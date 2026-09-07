import 'package:flutter_test/flutter_test.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

void main() {
  test('JSON round-trip preserves the logical entry calendar date', () {
    final entry = JournalEntry(
      id: 'entry-1',
      tripId: 'trip-1',
      title: 'Morning',
      body: '',
      mood: Mood.happy,
      photoPaths: const [],
      entryDate: DateTime(2026, 9, 7),
      createdAt: DateTime.utc(2026, 9, 6, 10, 2, 38),
      updatedAt: DateTime.utc(2026, 9, 6, 10, 2, 38),
    );

    final restored = JournalEntry.fromJson(entry.toJson());

    expect(restored.calendarDate, DateTime(2026, 9, 7));
    expect(restored.createdAt, DateTime.utc(2026, 9, 6, 10, 2, 38));
  });

  test('legacy JSON without entryDate falls back to the timestamp day', () {
    final json = {
      'id': 'legacy',
      'tripId': 'trip-1',
      'title': 'Legacy',
      'body': '',
      'mood': 'neutral',
      'photoPaths': <String>[],
      'location': null,
      'createdAt': '2026-09-07T12:00:00.000',
      'updatedAt': '2026-09-07T12:00:00.000',
      'healthLog': null,
    };

    final restored = JournalEntry.fromJson(json);

    expect(restored.calendarDate, DateTime(2026, 9, 7));
  });
}
