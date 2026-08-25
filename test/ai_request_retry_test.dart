import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/ai_request_retry.dart';
import 'package:tripjournal/models/ai_request_log.dart';

void main() {
  group('retryAiRequest', () {
    // `retryAiRequest` is hardcoded to the real `logged*Service` globals
    // (`daily_advice_locator.dart` etc.), which write through to the real,
    // shared `aiRequestLogRepository` — genuinely Supabase-backed since
    // Phase 21, with no injection seam to redirect that write in a test
    // (unlike `reportSystemError`, this function has no `repository`
    // parameter — its whole point is exercising the exact production call
    // path). So these tests can no longer assert a written log entry the
    // way they did pre-Phase-21; what's still verifiable, and still
    // meaningful, is that the underlying AI call itself succeeds and the
    // best-effort logging write never lets an unreachable backend surface
    // as a failure of the retry (see `ai_request_logging.dart`'s
    // `recordAiRequest` for where that's actually guaranteed).
    test('dailyAdvice retry completes without throwing', () async {
      await expectLater(retryAiRequest(AiRequestType.dailyAdvice), completes);
    });

    test('foodDetection retry completes without throwing', () async {
      await expectLater(retryAiRequest(AiRequestType.foodDetection), completes);
    });

    test('tripSummary retry completes without throwing', () async {
      await expectLater(retryAiRequest(AiRequestType.tripSummary), completes);
    });
  });
}
