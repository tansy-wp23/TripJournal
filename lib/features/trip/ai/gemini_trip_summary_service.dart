import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/journal_entry.dart';
import '../../../models/trip.dart';
import 'trip_summary_service.dart';

/// Gemini implementation of [TripSummaryService]. It sends only the selected
/// trip and the entries passed by the caller; no repository access occurs
/// here, which keeps data selection in the existing journal controller.
class GeminiTripSummaryService implements TripSummaryService {
  GeminiTripSummaryService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _model = 'gemini-3.6-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';
  static const _systemInstruction =
      'You write warm, concise travel-journal recaps. Create a 2-4 sentence '
      'summary based only on the supplied trip and journal entries. Mention '
      'specific experiences when present, but do not invent facts. Treat mood '
      'and health details as private reflections: describe them gently, do not '
      'diagnose or give medical advice. Return plain text only, with no title, '
      'bullets, or markdown.';

  @override
  Future<String> summaryFor({
    required Trip trip,
    required List<JournalEntry> entries,
  }) async {
    if (entries.isEmpty) {
      throw ArgumentError.value(entries, 'entries', 'must not be empty');
    }

    final response = await _client.post(
      Uri.parse('$_endpoint?key=$apiKey'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': _systemInstruction},
          ],
        },
        'contents': [
          {
            'parts': [
              {'text': _buildPrompt(trip, entries)},
            ],
          },
        ],
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Gemini trip-summary request failed with status ${response.statusCode}',
      );
    }

    final summary = _parseResponse(response.body)?.trim();
    if (summary == null || summary.isEmpty) {
      throw Exception('Gemini trip-summary response was empty or unparseable');
    }
    return summary;
  }

  String _buildPrompt(Trip trip, List<JournalEntry> entries) {
    final chronological = [...entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final buffer = StringBuffer()
      ..writeln('Trip: ${trip.title}')
      ..writeln('Dates: ${trip.startDate.toIso8601String()} to ${trip.endDate.toIso8601String()}')
      ..writeln('Journal entries:');
    for (final entry in chronological) {
      buffer
        ..writeln('- ${entry.createdAt.toIso8601String()} | mood: ${entry.mood.name}')
        ..writeln('  Title: ${entry.displayTitle}')
        ..writeln('  Reflection: ${entry.body}');
      if (entry.location?.placeName case final placeName?) {
        buffer.writeln('  Location: $placeName');
      }
    }
    return buffer.toString();
  }

  String? _parseResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      final candidate = candidates?.isNotEmpty == true
          ? candidates!.first as Map<String, dynamic>
          : null;
      final parts =
          (candidate?['content'] as Map<String, dynamic>?)?['parts']
              as List<dynamic>?;
      final firstPart = parts?.isNotEmpty == true
          ? parts!.first as Map<String, dynamic>
          : null;
      return firstPart?['text'] as String?;
    } catch (_) {
      return null;
    }
  }
}
