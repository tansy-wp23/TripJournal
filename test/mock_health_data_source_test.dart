import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/health/mock_health_data_source.dart';

void main() {
  final source = MockHealthDataSource();

  test('always reports permissions as granted', () async {
    expect(await source.hasPermissions(), isTrue);
    expect(await source.requestPermissions(), isTrue);
  });

  test('steps and calories burned are deterministic for a given date', () async {
    final date = DateTime(2026, 4, 10);
    final steps1 = await source.getStepsForDate(date);
    final steps2 = await source.getStepsForDate(date);
    final burned1 = await source.getCaloriesBurnedForDate(date);
    final burned2 = await source.getCaloriesBurnedForDate(date);

    expect(steps1, steps2);
    expect(burned1, burned2);
  });

  test('steps and calories burned fall within plausible ranges', () async {
    for (final date in [DateTime(2026, 4, 10), DateTime(2026, 4, 11), DateTime(2026, 5, 1)]) {
      final steps = await source.getStepsForDate(date);
      final burned = await source.getCaloriesBurnedForDate(date);

      expect(steps, inInclusiveRange(0, 30000));
      expect(burned, inInclusiveRange(0, 6000));
    }
  });

  test('different dates can yield different readings', () async {
    final steps = await Future.wait([
      source.getStepsForDate(DateTime(2026, 4, 10)),
      source.getStepsForDate(DateTime(2026, 4, 11)),
      source.getStepsForDate(DateTime(2026, 4, 12)),
    ]);

    expect(steps.toSet().length, greaterThan(1));
  });
}
