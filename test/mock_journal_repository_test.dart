import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/mood.dart';

JournalEntry _newEntry({String id = 'entry-new', String tripId = 'trip-001'}) {
  return JournalEntry(
    id: id,
    tripId: tripId,
    title: 'New entry',
    body: 'Body',
    mood: Mood.neutral,
    photoPaths: const [],
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
  );
}

void main() {
  late MockJournalRepository repository;

  setUp(() {
    repository = MockJournalRepository();
  });

  group('MockJournalRepository seed data', () {
    test('getEntries filters by tripId', () async {
      final trip001 = await repository.getEntries('trip-001');
      final trip002 = await repository.getEntries('trip-002');

      expect(trip001, hasLength(3));
      expect(trip001.every((e) => e.tripId == 'trip-001'), isTrue);
      expect(trip002, hasLength(1));
      expect(trip002.single.id, 'entry-4');
    });

    test('getEntries returns empty list for an unknown tripId', () async {
      final result = await repository.getEntries('trip-does-not-exist');
      expect(result, isEmpty);
    });

    test('getEntry finds a seeded entry by id', () async {
      final entry = await repository.getEntry('entry-2');
      expect(entry, isNotNull);
      expect(entry!.title, 'Fushimi Inari hike');
    });

    test('getEntry returns null for an unknown id', () async {
      final entry = await repository.getEntry('does-not-exist');
      expect(entry, isNull);
    });
  });

  group('MockJournalRepository CRUD', () {
    test('addEntry makes the entry retrievable via getEntry and getEntries', () async {
      final entry = _newEntry();
      await repository.addEntry(entry);

      final fetched = await repository.getEntry(entry.id);
      expect(fetched?.title, 'New entry');

      final tripEntries = await repository.getEntries('trip-001');
      expect(tripEntries.any((e) => e.id == entry.id), isTrue);
    });

    test('updateEntry replaces the entry with matching id', () async {
      final entry = _newEntry();
      await repository.addEntry(entry);

      final updated = entry.copyWith(title: 'Renamed entry');
      await repository.updateEntry(updated);

      final fetched = await repository.getEntry(entry.id);
      expect(fetched?.title, 'Renamed entry');
    });

    test('updateEntry is a no-op when the id does not exist', () async {
      final before = await repository.getEntries('trip-001');
      await repository.updateEntry(_newEntry(id: 'not-in-repo'));
      final after = await repository.getEntries('trip-001');
      expect(after.length, before.length);
    });

    test('deleteEntry removes the entry', () async {
      final entry = _newEntry();
      await repository.addEntry(entry);
      expect(await repository.getEntry(entry.id), isNotNull);

      await repository.deleteEntry(entry.id);
      expect(await repository.getEntry(entry.id), isNull);
    });

    test('deleteEntry is a no-op when the id does not exist', () async {
      final before = await repository.getEntries('trip-001');
      await repository.deleteEntry('not-in-repo');
      final after = await repository.getEntries('trip-001');
      expect(after.length, before.length);
    });

    test('addEntry preserves a full health log with meals', () async {
      final entry = _newEntry(id: 'entry-with-health').copyWith(
        healthLog: const HealthLog(
          id: 'health-new',
          entryId: 'entry-with-health',
          steps: 5000,
          caloriesEaten: 1800,
          meals: [Meal(id: 'meal-new', name: 'Salad', calories: 400, mealType: MealType.lunch)],
        ),
      );
      await repository.addEntry(entry);

      final fetched = await repository.getEntry('entry-with-health');
      expect(fetched?.healthLog?.steps, 5000);
      expect(fetched?.healthLog?.meals.single.name, 'Salad');
    });
  });
}
