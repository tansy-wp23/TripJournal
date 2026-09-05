import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/journal_repository.dart';
import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/features/journal/ai/daily_advice_service.dart';
import 'package:tripjournal/features/journal/controller/journal_controller.dart';
import 'package:tripjournal/models/geo_tag.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

/// Always fails on write — simulates an offline/save-failure scenario so
/// [JournalController.generateAndAttachAdvice] has something to degrade
/// gracefully from.
class _FailingJournalRepository implements JournalRepository {
  _FailingJournalRepository(this._entries);

  final List<JournalEntry> _entries;

  @override
  Future<List<JournalEntry>> getEntries(String tripId) async =>
      _entries.where((e) => e.tripId == tripId).toList();

  @override
  Future<JournalEntry?> getEntry(String id) async {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addEntry(JournalEntry entry) async => throw Exception('offline');

  @override
  Future<void> updateEntry(JournalEntry entry) async => throw Exception('offline');

  @override
  Future<void> deleteEntry(String id) async => throw Exception('offline');
}

JournalEntry _entry({HealthLog? healthLog}) {
  final now = DateTime(2026, 4, 10);
  return JournalEntry(
    id: 'entry-1',
    tripId: 'trip-001',
    title: 'A title',
    body: 'A body',
    mood: Mood.happy,
    photoPaths: const [],
    createdAt: now,
    updatedAt: now,
    healthLog: healthLog,
  );
}

void main() {
  test('generateAndAttachAdvice returns the generated advice and persists it into the entry', () async {
    final controller = JournalController(MockJournalRepository(), MockDailyAdviceService());
    await controller.loadEntries('trip-001');

    final log = const HealthLog(id: 'h', entryId: 'entry-1', steps: 6000, caloriesEaten: 1600, meals: []);
    final entry = _entry(healthLog: log).copyWith(id: 'entry-new-advice');
    await controller.create(entry);

    final advice = await controller.generateAndAttachAdvice(entry);

    expect(advice, isNotNull);
    expect(advice, isNotEmpty);
    final persisted = controller.entries.firstWhere((e) => e.id == 'entry-new-advice');
    expect(persisted.healthLog?.aiAdvice, advice);
  });

  test(
    'generateAndAttachAdvice does not clobber the location tag with a stale, '
    'pre-enrichment snapshot of the entry (the create/edit screen only ever '
    'holds the un-enriched copy it built locally, never what create()/edit() '
    'actually persisted)',
    () async {
      final controller = JournalController(
        MockJournalRepository(),
        MockDailyAdviceService(),
      );
      await controller.loadEntries('trip-001');

      final log = const HealthLog(
        id: 'h',
        entryId: 'entry-1',
        steps: 6000,
        caloriesEaten: 1600,
        meals: [],
      );
      final staleEntry = _entry(healthLog: log).copyWith(
        id: 'entry-location-tag',
        location: const GeoTag(
          latitude: 35.0,
          longitude: 135.7,
          placeName: 'Kyoto',
        ),
      );
      await controller.create(staleEntry);
      final justCreated = controller.entries.firstWhere(
        (e) => e.id == 'entry-location-tag',
      );
      expect(justCreated.location?.locationTag, '#Kyoto');

      // The screen hands this the same pre-enrichment `staleEntry` it built
      // locally, not the enriched copy create() actually persisted.
      await controller.generateAndAttachAdvice(staleEntry);

      final afterAdvice = controller.entries.firstWhere(
        (e) => e.id == 'entry-location-tag',
      );
      expect(afterAdvice.location?.locationTag, '#Kyoto');
    },
  );

  test('generateAndAttachAdvice returns null when the entry has no health log', () async {
    final controller = JournalController(MockJournalRepository(), MockDailyAdviceService());
    final advice = await controller.generateAndAttachAdvice(_entry(healthLog: null));
    expect(advice, isNull);
  });

  test('generateAndAttachAdvice returns null (not an exception) when persistence fails', () async {
    final log = const HealthLog(id: 'h', entryId: 'entry-1', steps: 6000, caloriesEaten: 1600, meals: []);
    final controller = JournalController(
      _FailingJournalRepository([]),
      MockDailyAdviceService(),
    );

    final advice = await controller.generateAndAttachAdvice(_entry(healthLog: log));

    expect(advice, isNull);
  });
}
