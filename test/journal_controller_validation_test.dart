import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/features/journal/ai/daily_advice_service.dart';
import 'package:tripjournal/features/journal/controller/journal_controller.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/mood.dart';
import 'package:tripjournal/models/trip.dart';

void main() {
  late JournalController controller;

  setUp(() {
    controller = JournalController(MockJournalRepository(), MockDailyAdviceService());
  });

  JournalEntry entry({
    String id = 'entry-new',
    String title = 'A title',
    String body = 'A body',
    DateTime? createdAt,
    HealthLog? healthLog,
  }) {
    final now = createdAt ?? DateTime.now();
    return JournalEntry(
      id: id,
      tripId: 'trip-001',
      title: title,
      body: body,
      mood: Mood.neutral,
      photoPaths: const [],
      createdAt: now,
      updatedAt: now,
      healthLog: healthLog,
    );
  }

  test('create rejects a title over 100 chars — validation lives in the controller, not just the screen', () async {
    final error = await controller.create(entry(title: 'a' * 101));
    expect(error, 'Title must be 100 characters or fewer.');
  });

  test('create rejects a body over 5000 chars', () async {
    final error = await controller.create(entry(title: '', body: 'a' * 5001));
    expect(error, 'Entry body must be 5,000 characters or fewer.');
  });

  test('create rejects no title and no body, but accepts title-only or body-only', () async {
    expect(
      await controller.create(entry(title: '', body: '')),
      'Please add a title or write something in your entry.',
    );
    expect(await controller.create(entry(id: 'e2', title: 'Just a title', body: '')), isNull);
    expect(await controller.create(entry(id: 'e3', title: '', body: 'Just a body')), isNull);
  });

  test('create rejects a negative step count', () async {
    final log = HealthLog(id: 'h', entryId: 'entry-new', steps: -5, caloriesEaten: 0, meals: const []);
    final error = await controller.create(entry(healthLog: log));
    expect(error, 'Please enter a valid number.');
  });

  test('create rejects a meal with no name', () async {
    final log = HealthLog(
      id: 'h',
      entryId: 'entry-new',
      steps: 1000,
      caloriesEaten: 200,
      meals: const [Meal(id: 'm1', name: '', calories: 200, mealType: MealType.lunch)],
    );
    final error = await controller.create(entry(healthLog: log));
    expect(error, 'Please enter a meal name.');
  });

  test('create rejects a meal with negative calories', () async {
    final log = HealthLog(
      id: 'h',
      entryId: 'entry-new',
      steps: 1000,
      caloriesEaten: -50,
      meals: const [Meal(id: 'm1', name: 'Snack', calories: -50, mealType: MealType.snack)],
    );
    final error = await controller.create(entry(healthLog: log));
    expect(error, 'Please enter a valid number.');
  });

  test('create rejects a future day', () async {
    final future = DateTime.now().add(const Duration(days: 5));
    final error = await controller.create(entry(createdAt: future));
    expect(error, "You can't add an entry for a future day.");
  });

  test('create rejects a day outside the given trip range', () async {
    final trip = Trip(
      id: 'trip-001',
      userId: 'u',
      title: 'Kyoto Trip',
      startDate: DateTime(2026, 4, 10),
      endDate: DateTime(2026, 4, 12),
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
    );
    final error = await controller.create(entry(createdAt: DateTime(2026, 3, 1)), trip: trip);
    expect(error, 'This date is outside your trip dates.');
  });

  test('edit does not re-check the date range — editing an unrelated field must not break on old entries', () async {
    // A date far outside any trip range would fail create()'s date check,
    // but edit() must not re-validate a field it isn't changing.
    final oldEntry = entry(createdAt: DateTime(2020, 1, 1));
    final error = await controller.edit(oldEntry.copyWith(title: 'Updated title'));
    expect(error, isNull);
  });

  test('create succeeds and persists when everything is valid', () async {
    await controller.loadEntries('trip-001');
    final error = await controller.create(entry(id: 'entry-valid'));
    expect(error, isNull);
    expect(controller.entries.any((e) => e.id == 'entry-valid'), isTrue);
  });
}
