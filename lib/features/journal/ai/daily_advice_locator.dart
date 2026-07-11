import 'daily_advice_service.dart';

/// The one place the app resolves its [DailyAdviceService] from — mirrors
/// `data/repository_locator.dart` so the later swap to a real API call is a
/// one-line change here.
final DailyAdviceService dailyAdviceService = MockDailyAdviceService();
