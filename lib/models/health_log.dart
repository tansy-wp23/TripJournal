import 'meal.dart';

class HealthLog {
  final String id;
  final String entryId;
  final int steps;

  /// Sum of logged meals' calories. Auto-summed — never entered directly.
  final int caloriesEaten;

  /// Energy burned that day, from the health platform. Null when no health
  /// data is available (denied permission, no device, unsynced watch) —
  /// steps/caloriesBurned must never block journaling, see
  /// IMPLEMENTATION_PLAN_ENHANCEMENTS.md.
  final int? caloriesBurned;

  final List<Meal> meals;
  final String? aiAdvice;

  const HealthLog({
    required this.id,
    required this.entryId,
    required this.steps,
    required this.caloriesEaten,
    this.caloriesBurned,
    required this.meals,
    this.aiAdvice,
  });

  factory HealthLog.fromJson(Map<String, dynamic> json) {
    return HealthLog(
      id: json['id'] as String,
      entryId: json['entryId'] as String,
      steps: json['steps'] as int,
      caloriesEaten: json['caloriesEaten'] as int,
      caloriesBurned: json['caloriesBurned'] as int?,
      meals: (json['meals'] as List<dynamic>)
          .map((m) => Meal.fromJson(m as Map<String, dynamic>))
          .toList(),
      aiAdvice: json['aiAdvice'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entryId': entryId,
      'steps': steps,
      'caloriesEaten': caloriesEaten,
      'caloriesBurned': caloriesBurned,
      'meals': meals.map((m) => m.toJson()).toList(),
      'aiAdvice': aiAdvice,
    };
  }

  HealthLog copyWith({
    String? id,
    String? entryId,
    int? steps,
    int? caloriesEaten,
    int? caloriesBurned,
    bool clearCaloriesBurned = false,
    List<Meal>? meals,
    String? aiAdvice,
  }) {
    return HealthLog(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      steps: steps ?? this.steps,
      caloriesEaten: caloriesEaten ?? this.caloriesEaten,
      caloriesBurned: clearCaloriesBurned ? null : (caloriesBurned ?? this.caloriesBurned),
      meals: meals ?? this.meals,
      aiAdvice: aiAdvice ?? this.aiAdvice,
    );
  }
}
