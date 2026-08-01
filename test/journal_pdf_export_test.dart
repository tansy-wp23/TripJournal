import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/journal/pdf/journal_pdf_export.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/mood.dart';
import 'package:tripjournal/models/trip.dart';

JournalEntry _entry({
  required String id,
  String title = 'Test entry',
  String body = 'Some body text.',
  Mood mood = Mood.happy,
  List<String> photoPaths = const [],
  HealthLog? healthLog,
  DateTime? createdAt,
}) {
  final date = createdAt ?? DateTime(2026, 4, 10);
  return JournalEntry(
    id: id,
    tripId: 't',
    title: title,
    body: body,
    mood: mood,
    photoPaths: photoPaths,
    createdAt: date,
    updatedAt: date,
    healthLog: healthLog,
  );
}

Trip _trip({String? notes}) {
  final start = DateTime(2026, 4, 10);
  final end = DateTime(2026, 4, 12);
  return Trip(
    id: 't',
    userId: 'u',
    title: 'Kyoto Trip',
    startDate: start,
    endDate: end,
    notes: notes,
    createdAt: start,
    updatedAt: start,
  );
}

bool _looksLikePdf(List<int> bytes) {
  // Every valid PDF starts with the "%PDF" magic bytes.
  return bytes.length > 4 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;
}

void main() {
  group('pdfFileNameFor', () {
    test('sanitises punctuation and spaces into a safe filename', () {
      expect(pdfFileNameFor('Georgetown: Day 1!'), 'Georgetown_Day_1.pdf');
    });

    test('falls back to a generic name when the title has nothing usable', () {
      expect(pdfFileNameFor('???'), 'export.pdf');
    });

    test('collapses repeated whitespace', () {
      expect(pdfFileNameFor('My   Trip'), 'My_Trip.pdf');
    });
  });

  group('buildEntryPdf', () {
    test(
      'produces valid, non-empty PDF bytes for a fully-populated entry',
      () async {
        final entry = _entry(
          id: 'e1',
          photoPaths: const [
            'C:/nonexistent/photo.jpg',
          ], // deliberately unreadable -- must not throw
          healthLog: const HealthLog(
            id: 'h1',
            entryId: 'e1',
            steps: 5000,
            caloriesEaten: 1200,
            caloriesBurned: 1800,
            meals: [
              Meal(
                id: 'm1',
                name: 'Ramen',
                calories: 600,
                mealType: MealType.lunch,
              ),
            ],
            aiAdvice: 'Add a vegetable side tomorrow.',
          ),
        );

        final bytes = await buildEntryPdf(entry);

        expect(bytes, isNotEmpty);
        expect(_looksLikePdf(bytes), isTrue);
      },
    );

    test(
      'handles an entry with no health log, no photos, and an empty body without throwing',
      () async {
        final entry = _entry(id: 'e2', title: '', body: '');

        final bytes = await buildEntryPdf(entry);

        expect(bytes, isNotEmpty);
        expect(_looksLikePdf(bytes), isTrue);
      },
    );
  });

  group('buildTripPdf', () {
    test(
      'produces valid PDF bytes for a trip with entries across multiple days',
      () async {
        final trip = _trip(notes: 'Renew rail pass.');
        final entries = [
          _entry(id: 'e1', createdAt: DateTime(2026, 4, 10)),
          _entry(id: 'e2', createdAt: DateTime(2026, 4, 11)),
        ];

        final bytes = await buildTripPdf(trip, entries);

        expect(bytes, isNotEmpty);
        expect(_looksLikePdf(bytes), isTrue);
      },
    );

    test(
      'a trip with zero entries still produces a valid header-only PDF',
      () async {
        final bytes = await buildTripPdf(_trip(), const []);

        expect(bytes, isNotEmpty);
        expect(_looksLikePdf(bytes), isTrue);
      },
    );
  });
}
