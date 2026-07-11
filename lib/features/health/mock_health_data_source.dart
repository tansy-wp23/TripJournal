import 'health_data_source.dart';

/// Returns plausible, deterministic values with no real device or platform
/// dependency — this is the default [HealthDataSource] so the app (and its
/// tests) run the same in an emulator, on Windows desktop, or on CI.
///
/// Values are derived from the date (not random) so the same date always
/// yields the same reading, which keeps tests reproducible.
class MockHealthDataSource implements HealthDataSource {
  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> hasPermissions() async => true;

  @override
  Future<int?> getStepsForDate(DateTime date) async {
    return 4000 + (_daySeed(date) % 9) * 900; // 4000..11600
  }

  @override
  Future<int?> getCaloriesBurnedForDate(DateTime date) async {
    return 1800 + (_daySeed(date) % 7) * 150; // 1800..2700
  }

  int _daySeed(DateTime date) => date.year * 372 + date.month * 31 + date.day;
}
