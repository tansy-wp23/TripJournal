import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

// A trip id the seeded demo data never uses, so these assertions see only the
// entries each test adds.
const _tripId = 'draft-filter-trip';

JournalEntry _entry({
  required String id,
  required bool isDraft,
  String tripId = _tripId,
}) {
  final now = DateTime(2026, 9, 8, 10);
  return JournalEntry(
    id: id,
    tripId: tripId,
    title: id,
    body: '',
    mood: Mood.neutral,
    photoPaths: const [],
    createdAt: now,
    updatedAt: now,
    isDraft: isDraft,
  );
}

void main() {
  group('getEntries draft filtering', () {
    test('excludes drafts by default', () async {
      final repository = MockJournalRepository();
      await repository.addEntry(_entry(id: 'published', isDraft: false));
      await repository.addEntry(_entry(id: 'parked', isDraft: true));

      final entries = await repository.getEntries(_tripId);

      expect(entries.map((e) => e.id), ['published']);
    });

    test('includes drafts only when asked', () async {
      final repository = MockJournalRepository();
      await repository.addEntry(_entry(id: 'published', isDraft: false));
      await repository.addEntry(_entry(id: 'parked', isDraft: true));

      final entries = await repository.getEntries(
        _tripId,
        includeDrafts: true,
      );

      expect(entries.map((e) => e.id), ['published', 'parked']);
    });

    test('the trip filter still applies when drafts are included', () async {
      final repository = MockJournalRepository();
      await repository.addEntry(_entry(id: 'mine', isDraft: true));
      await repository.addEntry(
        _entry(id: 'other-trip', isDraft: true, tripId: 'some-other-trip'),
      );

      final entries = await repository.getEntries(
        _tripId,
        includeDrafts: true,
      );

      expect(entries.map((e) => e.id), ['mine']);
    });
  });
}
