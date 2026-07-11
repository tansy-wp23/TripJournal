import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_summary_stats.dart';
import 'package:tripjournal/features/trip/widgets/wellness_stats_row.dart';
import 'package:tripjournal/models/mood.dart';

Widget wrapped(TripStats stats) {
  return MaterialApp(home: Scaffold(body: WellnessStatsRow(stats: stats)));
}

void main() {
  testWidgets('shows both Eaten and Burned figures separately when burned data exists', (tester) async {
    const stats = TripStats(
      totalSteps: 12000,
      totalCaloriesEaten: 5950,
      totalCaloriesBurned: 5450,
      averageMood: Mood.happy,
      daysLogged: 3,
      totalDays: 5,
    );

    await tester.pumpWidget(wrapped(stats));

    expect(find.text('Eaten: 5,950 kcal'), findsOneWidget);
    expect(find.text('Burned: 5,450 kcal'), findsOneWidget);
    // No net/combined figure anywhere — the two must stay visually separate.
    expect(find.textContaining('Net'), findsNothing);
  });

  testWidgets('shows a graceful "no health data" placeholder when burned is null, never 0', (tester) async {
    const stats = TripStats(
      totalSteps: 4000,
      totalCaloriesEaten: 1800,
      totalCaloriesBurned: null,
      averageMood: Mood.neutral,
      daysLogged: 1,
      totalDays: 3,
    );

    await tester.pumpWidget(wrapped(stats));

    expect(find.text('Eaten: 1,800 kcal'), findsOneWidget);
    expect(find.text('Burned: — (no health data)'), findsOneWidget);
    expect(find.text('Burned: 0 kcal'), findsNothing);
  });

  testWidgets('shows "No mood yet" when averageMood is null (no entries logged)', (tester) async {
    const stats = TripStats(
      totalSteps: 0,
      totalCaloriesEaten: 0,
      totalCaloriesBurned: null,
      averageMood: null,
      daysLogged: 0,
      totalDays: 5,
    );

    await tester.pumpWidget(wrapped(stats));

    expect(find.text('No mood yet'), findsOneWidget);
    expect(find.text('0 of 5 days logged'), findsOneWidget);
  });
}
