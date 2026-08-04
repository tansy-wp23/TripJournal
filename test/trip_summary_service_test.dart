import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripjournal/features/trip/ai/gemini_trip_summary_service.dart';
import 'package:tripjournal/features/trip/ai/trip_summary_service.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';
import 'package:tripjournal/models/trip.dart';

final _trip = Trip(
  id: 'trip-1',
  userId: 'user-1',
  title: 'Kyoto Escape',
  startDate: DateTime(2026, 4, 10),
  endDate: DateTime(2026, 4, 11),
  createdAt: DateTime(2026, 4, 1),
  updatedAt: DateTime(2026, 4, 1),
);

JournalEntry _entry({
  required String id,
  required String title,
  required Mood mood,
  required DateTime createdAt,
}) => JournalEntry(
  id: id,
  tripId: _trip.id,
  title: title,
  body: 'A memorable day.',
  mood: mood,
  photoPaths: const [],
  createdAt: createdAt,
  updatedAt: createdAt,
);

void main() {
  final entries = [
    _entry(
      id: 'late',
      title: 'Temple visit',
      mood: Mood.happy,
      createdAt: DateTime(2026, 4, 11),
    ),
    _entry(
      id: 'early',
      title: 'Arrival',
      mood: Mood.happy,
      createdAt: DateTime(2026, 4, 10),
    ),
  ];

  test('offline summary uses the selected trip and its chronological entries', () async {
    final summary = await MockTripSummaryService().summaryFor(
      trip: _trip,
      entries: entries,
    );

    expect(summary, contains('Kyoto Escape'));
    expect(summary, contains('Arrival, Temple visit'));
    expect(summary, contains('happy'));
  });

  test('Gemini summary sends selected-trip entry data and returns its text', () async {
    Map<String, dynamic>? requestBody;
    final service = GeminiTripSummaryService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'A thoughtful Kyoto recap.'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final summary = await service.summaryFor(trip: _trip, entries: entries);

    expect(summary, 'A thoughtful Kyoto recap.');
    final prompt =
        (requestBody!['contents'] as List<dynamic>)[0]['parts'][0]['text']
            as String;
    expect(prompt, contains('Kyoto Escape'));
    expect(prompt, contains('Arrival'));
    expect(prompt, contains('Temple visit'));
  });

  test('summary services reject an empty entry list', () async {
    await expectLater(
      MockTripSummaryService().summaryFor(trip: _trip, entries: const []),
      throwsArgumentError,
    );
  });
}
