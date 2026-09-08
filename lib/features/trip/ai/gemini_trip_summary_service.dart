import '../../../models/journal_entry.dart';
import '../../../models/trip.dart';
import '../../journal/ai/gemini_function_invoker.dart';
import 'trip_summary_service.dart';

/// Real implementation, backed by the `gemini-proxy` Edge Function.
///
/// Sends only the selected trip and the entries the caller passed; no
/// repository access happens here, so data selection stays in the journal
/// controller (which is also what keeps drafts out of a summary). The prompt
/// and system instruction live in the function alongside the API key.
class GeminiTripSummaryService implements TripSummaryService {
  const GeminiTripSummaryService({required GeminiFunctionInvoker invoke})
    : this._(invoke);

  const GeminiTripSummaryService._(this._invoke);

  final GeminiFunctionInvoker _invoke;

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

    final payload = await _invoke('trip_summary', {
      'trip': {
        'title': trip.title,
        'startDate': trip.startDate.toIso8601String(),
        'endDate': trip.endDate.toIso8601String(),
      },
      'entries': [
        for (final entry in chronological)
          {
            'createdAt': entry.createdAt.toIso8601String(),
            'mood': entry.mood.name,
            'title': entry.displayTitle,
            'body': entry.body,
            'placeName': entry.location?.placeName,
          },
      ],
    });

    final summary = payload['summary'];
    if (summary is! String || summary.trim().isEmpty) {
      throw const GeminiProxyException(
        'The AI service returned an empty response.',
        code: 'invalid_response',
      );
    }
    return summary.trim();
  }
}
