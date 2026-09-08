import 'package:flutter_test/flutter_test.dart';
import 'package:tripjournal/features/journal/ai/gemini_function_invoker.dart';
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

  // Prompt wording and the system instruction live in the gemini-proxy Edge
  // Function now (with the API key), so what this asserts is the data handed
  // over — including the chronological ordering, which the summary depends on
  // and which the function cannot recover on its own.
  test('Gemini summary sends the trip and its entries oldest-first', () async {
    String? seenAction;
    Map<String, dynamic>? seenBody;
    final service = GeminiTripSummaryService(
      invoke: (action, body) async {
        seenAction = action;
        seenBody = body;
        return {'summary': '  A thoughtful Kyoto recap. '};
      },
    );

    final summary = await service.summaryFor(trip: _trip, entries: entries);

    expect(summary, 'A thoughtful Kyoto recap.');
    expect(seenAction, 'trip_summary');
    expect((seenBody!['trip'] as Map)['title'], 'Kyoto Escape');

    final sent = seenBody!['entries'] as List;
    expect(sent.map((e) => (e as Map)['title']), ['Arrival', 'Temple visit']);
    expect((sent.first as Map)['mood'], 'happy');
  });

  test('Gemini summary throws when the proxy returns nothing usable', () async {
    final service = GeminiTripSummaryService(
      invoke: (_, _) async => const <String, dynamic>{'summary': '  '},
    );

    await expectLater(
      service.summaryFor(trip: _trip, entries: entries),
      throwsA(isA<GeminiProxyException>()),
    );
  });

  test('summary services reject an empty entry list', () async {
    await expectLater(
      MockTripSummaryService().summaryFor(trip: _trip, entries: const []),
      throwsArgumentError,
    );
    // The Gemini one rejects it client-side too, without a wasted round trip.
    var called = false;
    final service = GeminiTripSummaryService(
      invoke: (_, _) async {
        called = true;
        return {'summary': 'never'};
      },
    );
    await expectLater(
      service.summaryFor(trip: _trip, entries: const []),
      throwsArgumentError,
    );
    expect(called, isFalse);
  });
}
