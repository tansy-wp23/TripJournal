/// A record of one call to a Gemini-backed AI service.
///
/// Owned by the Admin module (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md`, Sprint
/// 3, Phase 15). Entries are written by a logging decorator wrapping each of
/// the three existing AI locators (`daily_advice_locator.dart`,
/// `food_detection_locator.dart`, `trip_summary_locator.dart`) per
/// Architecture Decision 9 — the underlying `GeminiXService`/`MockXService`
/// classes are untouched. Backs PB-12 (monitor AI requests), PB-13 (monitor
/// failed AI requests), and feeds into PB-15's monitoring reports.
class AiRequestLog {
  final String logId;
  final String userId;
  final AiRequestType requestType;
  final AiRequestStatus status;
  final int executionTimeMs;
  final String? errorMessage;
  final DateTime createdAt;

  const AiRequestLog({
    required this.logId,
    required this.userId,
    required this.requestType,
    required this.status,
    required this.executionTimeMs,
    this.errorMessage,
    required this.createdAt,
  });

  factory AiRequestLog.fromJson(Map<String, dynamic> json) {
    return AiRequestLog(
      logId: json['logId'] as String,
      userId: json['userId'] as String,
      requestType: AiRequestType.values.firstWhere(
        (t) => t.name == json['requestType'],
      ),
      status: AiRequestStatus.values.firstWhere(
        (s) => s.name == json['status'],
      ),
      executionTimeMs: json['executionTimeMs'] as int,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'logId': logId,
      'userId': userId,
      'requestType': requestType.name,
      'status': status.name,
      'executionTimeMs': executionTimeMs,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Which of the three existing Gemini-backed services produced an
/// [AiRequestLog] entry — one value per AI locator
/// (`daily_advice_locator.dart`, `food_detection_locator.dart`,
/// `trip_summary_locator.dart`).
enum AiRequestType { dailyAdvice, foodDetection, tripSummary }

/// Whether an [AiRequestLog]'s underlying AI call succeeded or failed —
/// PB-13's "failed AI requests" view is [AiRequestStatus.failed] entries.
enum AiRequestStatus { succeeded, failed }
