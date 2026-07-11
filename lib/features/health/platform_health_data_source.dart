import 'package:health/health.dart';

import 'health_data_source.dart';

/// Real implementation backed by the `health` package, which wraps Apple
/// HealthKit (iOS) and Health Connect (Android) behind one API.
///
/// HealthKit/Health Connect do not fully work on emulators or desktop — this
/// class needs a physical device to verify. Every method swallows platform
/// exceptions and returns null rather than throwing, so a denied permission
/// or unsupported platform degrades to "no data" instead of crashing the
/// entry form (manual entry must always remain available).
class PlatformHealthDataSource implements HealthDataSource {
  PlatformHealthDataSource({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<bool> hasPermissions() async {
    try {
      await _ensureConfigured();
      return await _health.hasPermissions(_types) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      await _ensureConfigured();
      return await _health.requestAuthorization(_types);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int?> getStepsForDate(DateTime date) async {
    try {
      await _ensureConfigured();
      return await _health.getTotalStepsInInterval(_startOfDay(date), _endOfDay(date));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int?> getCaloriesBurnedForDate(DateTime date) async {
    try {
      await _ensureConfigured();
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.TOTAL_CALORIES_BURNED],
        startTime: _startOfDay(date),
        endTime: _endOfDay(date),
      );
      if (points.isEmpty) return null;

      final total = points.fold<num>(0, (sum, point) {
        final value = point.value;
        return sum + (value is NumericHealthValue ? value.numericValue : 0);
      });
      return total.round();
    } catch (_) {
      return null;
    }
  }

  DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);
  DateTime _endOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59);
}
