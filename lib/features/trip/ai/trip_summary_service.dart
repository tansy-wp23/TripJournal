import '../../../models/journal_entry.dart';
import '../../../models/mood.dart';
import '../../../models/trip.dart';

/// Produces a concise recap from one trip and the journal entries already
/// associated with it. Implementations never persist the generated text;
/// the trip view owns the current, on-screen result.
abstract class TripSummaryService {
  Future<String> summaryFor({
    required Trip trip,
    required List<JournalEntry> entries,
  });
}

/// Offline recap used when an AI key is not configured. It is deliberately
/// based on the same trip entries supplied to the real service, so generating
/// a recap remains useful without network access.
class MockTripSummaryService implements TripSummaryService {
  @override
  Future<String> summaryFor({
    required Trip trip,
    required List<JournalEntry> entries,
  }) async {
    if (entries.isEmpty) {
      throw ArgumentError.value(entries, 'entries', 'must not be empty');
    }

    final chronological = [...entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final highlights = chronological
        .map((entry) => entry.displayTitle)
        .take(3)
        .join(', ');
    final moodCounts = <Mood, int>{};
    for (final entry in chronological) {
      moodCounts.update(entry.mood, (count) => count + 1, ifAbsent: () => 1);
    }
    final prevailingMood = moodCounts.entries.reduce(
      (current, candidate) =>
          candidate.value > current.value ? candidate : current,
    ).key;

    return '${trip.title} was captured across ${chronological.length} '
        '${chronological.length == 1 ? 'journal entry' : 'journal entries'}. '
        'Highlights included $highlights. '
        'The overall mood was ${prevailingMood.name}.';
  }
}
