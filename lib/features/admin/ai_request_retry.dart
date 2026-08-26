import '../../models/ai_request_log.dart';
import '../../models/journal_entry.dart';
import '../../models/mood.dart';
import '../../models/trip.dart';
import '../journal/ai/daily_advice_locator.dart';
import '../journal/ai/food_detection_locator.dart';
import '../trip/ai/trip_summary_locator.dart';

/// PB-13's retry action (Phase 18, `docs/admin/PROGRESS.md`, Architecture
/// Decision 10) — re-invokes the same [AiRequestType]'s underlying service
/// the original request used, but against a small, fixed representative
/// payload rather than the original request's real data.
///
/// Architecture Decision 10 explicitly allows this alternative to storing
/// original call parameters on [AiRequestLog]: "...or just 'try the action
/// again from the UI that triggered it'". Storing real parameters isn't
/// attempted here — `AiRequestLog` would need to hold whatever meals/photo
/// bytes/trip+entries the original request used, data that belongs to
/// whichever user made that request, not to a monitoring log an admin
/// reads. What this retry actually demonstrates is *whether the AI
/// capability itself is currently working* (a network/quota/API-key issue
/// would reproduce here; a request-specific data issue would not) — not a
/// replay of history. `FailedAiRequestsScreen`'s doc comment states this
/// plainly so it isn't mistaken for the latter.
///
/// Goes through the same `logged*Service` wrapper the real call sites use
/// (`daily_advice_locator.dart` etc.), so the retry attempt is itself
/// recorded as a new `AiRequestLog` entry — callers should reload after
/// this completes to see it. Lets the underlying call's exception (already
/// recorded by that wrapper) propagate to the caller rather than swallowing
/// it here.
Future<void> retryAiRequest(AiRequestType type) async {
  switch (type) {
    case AiRequestType.dailyAdvice:
      await loggedDailyAdviceService.adviceFor(
        meals: const [],
        steps: null,
        mood: Mood.neutral,
      );
    case AiRequestType.foodDetection:
      await loggedFoodDetectionService.detectFromImage(
        'admin-retry-placeholder.jpg',
      );
    case AiRequestType.tripSummary:
      final now = DateTime.now();
      await loggedTripSummaryService.summaryFor(
        trip: Trip(
          id: 'admin-retry-trip',
          userId: 'admin-retry',
          title: 'Retry check',
          startDate: now,
          endDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        entries: [
          JournalEntry(
            id: 'admin-retry-entry',
            tripId: 'admin-retry-trip',
            title: 'Retry check',
            body: 'Synthetic entry used only to re-check AI connectivity.',
            mood: Mood.neutral,
            photoPaths: const [],
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
  }
}
