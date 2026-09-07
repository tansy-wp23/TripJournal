import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/journal_filter.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

JournalEntry _entry({
  required String id,
  String title = '',
  String body = '',
  required Mood mood,
  required DateTime createdAt,
  DateTime? entryDate,
}) {
  return JournalEntry(
    id: id,
    tripId: 't',
    title: title,
    body: body,
    mood: mood,
    photoPaths: const [],
    entryDate: entryDate,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  group('filterJournalEntries', () {
    final entries = [
      _entry(
        id: 'e1',
        title: 'Beach day',
        body: 'Swam at the beach, saw dolphins',
        mood: Mood.happy,
        createdAt: DateTime(2026, 4, 10),
      ),
      _entry(
        id: 'e2',
        title: 'Rainy hike',
        body: 'Got soaked on the trail',
        mood: Mood.tired,
        createdAt: DateTime(2026, 4, 11),
      ),
      _entry(
        id: 'e3',
        title: '',
        body: 'Long flight delay at the airport',
        mood: Mood.stressed,
        createdAt: DateTime(2026, 4, 12),
      ),
    ];

    test('an inactive (default) filter returns entries unchanged', () {
      const filter = JournalFilter();
      expect(filter.isActive, isFalse);
      expect(filterJournalEntries(entries, filter), same(entries));
    });

    test('matches text against title OR body, case-insensitively', () {
      final byTitle = filterJournalEntries(
        entries,
        const JournalFilter(query: 'BEACH'),
      );
      expect(byTitle.map((e) => e.id), ['e1']);

      final byBody = filterJournalEntries(
        entries,
        const JournalFilter(query: 'dolphins'),
      );
      expect(byBody.map((e) => e.id), ['e1']);

      final noMatch = filterJournalEntries(
        entries,
        const JournalFilter(query: 'volcano'),
      );
      expect(noMatch, isEmpty);
    });

    test('filters by exact mood', () {
      final result = filterJournalEntries(
        entries,
        const JournalFilter(mood: Mood.tired),
      );
      expect(result.map((e) => e.id), ['e2']);
    });

    test('filters by inclusive date range', () {
      final result = filterJournalEntries(
        entries,
        JournalFilter(
          startDate: DateTime(2026, 4, 11),
          endDate: DateTime(2026, 4, 11),
        ),
      );
      expect(result.map((e) => e.id), ['e2']);
    });

    test('filters by logical entry date rather than UTC timestamp date', () {
      final boundary = _entry(
        id: 'boundary',
        mood: Mood.happy,
        createdAt: DateTime.utc(2026, 9, 6, 10, 2, 38),
        entryDate: DateTime(2026, 9, 7),
      );

      final result = filterJournalEntries(
        [boundary],
        JournalFilter(
          startDate: DateTime(2026, 9, 7),
          endDate: DateTime(2026, 9, 7),
        ),
      );

      expect(result.map((entry) => entry.id), ['boundary']);
    });

    test('combines query, mood, and date range with AND semantics', () {
      final result = filterJournalEntries(
        entries,
        JournalFilter(
          query: 'trail',
          mood: Mood.tired,
          startDate: DateTime(2026, 4, 11),
          endDate: DateTime(2026, 4, 11),
        ),
      );
      expect(result.map((e) => e.id), ['e2']);

      final mismatchedMood = filterJournalEntries(
        entries,
        JournalFilter(query: 'trail', mood: Mood.happy),
      );
      expect(mismatchedMood, isEmpty);
    });
  });
}
