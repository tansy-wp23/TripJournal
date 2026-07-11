import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import 'package:tripjournal/features/health/platform_health_data_source.dart';

/// [Health] is a plain (non-final) class, so it can be subclassed to fake
/// every platform call [PlatformHealthDataSource] makes — no real HealthKit
/// / Health Connect channel is ever touched. `configure()` is overridden too,
/// so `DeviceInfoPlugin` (which the real [Health.configure] calls) is never
/// invoked either.
class _FakeHealth extends Health {
  _FakeHealth({
    this.configureThrows = false,
    this.hasPermissionsResult,
    this.hasPermissionsThrows = false,
    this.requestAuthorizationResult = true,
    this.requestAuthorizationThrows = false,
    this.totalSteps,
    this.stepsThrows = false,
    this.dataPoints = const [],
    this.dataThrows = false,
  });

  final bool configureThrows;
  final bool? hasPermissionsResult;
  final bool hasPermissionsThrows;
  final bool requestAuthorizationResult;
  final bool requestAuthorizationThrows;
  final int? totalSteps;
  final bool stepsThrows;
  final List<HealthDataPoint> dataPoints;
  final bool dataThrows;

  int configureCalls = 0;
  DateTime? lastStepsStart;
  DateTime? lastStepsEnd;
  DateTime? lastDataStart;
  DateTime? lastDataEnd;

  @override
  Future<void> configure() async {
    configureCalls++;
    if (configureThrows) throw Exception('Health Connect not available');
  }

  @override
  Future<bool?> hasPermissions(List<HealthDataType> types, {List<HealthDataAccess>? permissions}) async {
    if (hasPermissionsThrows) throw Exception('hasPermissions failed');
    return hasPermissionsResult;
  }

  @override
  Future<bool> requestAuthorization(List<HealthDataType> types, {List<HealthDataAccess>? permissions}) async {
    if (requestAuthorizationThrows) throw Exception('requestAuthorization failed');
    return requestAuthorizationResult;
  }

  @override
  Future<int?> getTotalStepsInInterval(
    DateTime startTime,
    DateTime endTime, {
    bool includeManualEntry = true,
  }) async {
    lastStepsStart = startTime;
    lastStepsEnd = endTime;
    if (stepsThrows) throw Exception('getTotalStepsInInterval failed');
    return totalSteps;
  }

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    lastDataStart = startTime;
    lastDataEnd = endTime;
    if (dataThrows) throw Exception('getHealthDataFromTypes failed');
    return dataPoints;
  }
}

HealthDataPoint _caloriesPoint(double value) => HealthDataPoint(
  uuid: 'point-$value',
  value: NumericHealthValue(numericValue: value),
  type: HealthDataType.TOTAL_CALORIES_BURNED,
  unit: HealthDataUnit.KILOCALORIE,
  dateFrom: DateTime(2026, 4, 10, 8),
  dateTo: DateTime(2026, 4, 10, 9),
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'device',
  sourceId: 'source',
  sourceName: 'Health Connect',
);

void main() {
  group('PlatformHealthDataSource — permissions (IMPLEMENTATION_PLAN_HEALTH.md §7)', () {
    test('hasPermissions returns the underlying result', () async {
      final source = PlatformHealthDataSource(health: _FakeHealth(hasPermissionsResult: true));
      expect(await source.hasPermissions(), isTrue);
    });

    test('hasPermissions returns false (not null) when the platform result is undetermined', () async {
      final source = PlatformHealthDataSource(health: _FakeHealth(hasPermissionsResult: null));
      expect(await source.hasPermissions(), isFalse);
    });

    test('hasPermissions returns false, never throws, when the platform call throws', () async {
      final source = PlatformHealthDataSource(health: _FakeHealth(hasPermissionsThrows: true));
      expect(await source.hasPermissions(), isFalse);
    });

    test('requestPermissions returns the underlying result', () async {
      final granted = PlatformHealthDataSource(health: _FakeHealth(requestAuthorizationResult: true));
      expect(await granted.requestPermissions(), isTrue);

      final denied = PlatformHealthDataSource(health: _FakeHealth(requestAuthorizationResult: false));
      expect(await denied.requestPermissions(), isFalse);
    });

    test('requestPermissions returns false, never throws, when the platform call throws', () async {
      final source = PlatformHealthDataSource(health: _FakeHealth(requestAuthorizationThrows: true));
      expect(await source.requestPermissions(), isFalse);
    });

    test(
      'a configure() failure (e.g. Health Connect not installed) degrades to false/null everywhere, never throws',
      () async {
        final fake = _FakeHealth(configureThrows: true);
        final source = PlatformHealthDataSource(health: fake);

        expect(await source.hasPermissions(), isFalse);
        expect(await source.requestPermissions(), isFalse);
        expect(await source.getStepsForDate(DateTime(2026, 4, 10)), isNull);
        expect(await source.getCaloriesBurnedForDate(DateTime(2026, 4, 10)), isNull);
      },
    );
  });

  group('PlatformHealthDataSource — getStepsForDate', () {
    test('returns the platform total for the day', () async {
      final source = PlatformHealthDataSource(health: _FakeHealth(totalSteps: 8342));
      expect(await source.getStepsForDate(DateTime(2026, 4, 10)), 8342);
    });

    test('returns null when the platform has no data for the day (not 0)', () async {
      final source = PlatformHealthDataSource(health: _FakeHealth(totalSteps: null));
      expect(await source.getStepsForDate(DateTime(2026, 4, 10)), isNull);
    });

    test('returns null, never throws, when the platform call throws', () async {
      final source = PlatformHealthDataSource(health: _FakeHealth(stepsThrows: true));
      expect(await source.getStepsForDate(DateTime(2026, 4, 10)), isNull);
    });

    test('queries the exact calendar day — midnight to 23:59:59 of the given date', () async {
      final fake = _FakeHealth(totalSteps: 100);
      final source = PlatformHealthDataSource(health: fake);
      await source.getStepsForDate(DateTime(2026, 4, 10));

      expect(fake.lastStepsStart, DateTime(2026, 4, 10, 0, 0, 0));
      expect(fake.lastStepsEnd, DateTime(2026, 4, 10, 23, 59, 59));
    });
  });

  group('PlatformHealthDataSource — getCaloriesBurnedForDate', () {
    test('sums multiple data points into a single rounded total', () async {
      final source = PlatformHealthDataSource(
        health: _FakeHealth(dataPoints: [_caloriesPoint(120.4), _caloriesPoint(80.4)]),
      );
      expect(await source.getCaloriesBurnedForDate(DateTime(2026, 4, 10)), 201); // 200.8 rounds to 201
    });

    test('returns null (not 0) when there are no data points for the day', () async {
      final source = PlatformHealthDataSource(health: _FakeHealth(dataPoints: const []));
      expect(await source.getCaloriesBurnedForDate(DateTime(2026, 4, 10)), isNull);
    });

    test('returns null, never throws, when the platform call throws', () async {
      final source = PlatformHealthDataSource(health: _FakeHealth(dataThrows: true));
      expect(await source.getCaloriesBurnedForDate(DateTime(2026, 4, 10)), isNull);
    });

    test('queries the exact calendar day — midnight to 23:59:59 of the given date', () async {
      final fake = _FakeHealth(dataPoints: [_caloriesPoint(100)]);
      final source = PlatformHealthDataSource(health: fake);
      await source.getCaloriesBurnedForDate(DateTime(2026, 4, 10));

      expect(fake.lastDataStart, DateTime(2026, 4, 10, 0, 0, 0));
      expect(fake.lastDataEnd, DateTime(2026, 4, 10, 23, 59, 59));
    });
  });

  test('configure() only runs once across multiple calls on the same instance', () async {
    final fake = _FakeHealth(totalSteps: 10);
    final source = PlatformHealthDataSource(health: fake);

    await source.getStepsForDate(DateTime(2026, 4, 10));
    await source.getCaloriesBurnedForDate(DateTime(2026, 4, 10));
    await source.hasPermissions();

    expect(fake.configureCalls, 1);
  });
}
