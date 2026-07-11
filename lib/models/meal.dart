import 'meal_type.dart';
import 'portion_size.dart';

class Meal {
  final String id;
  final String name;
  final int calories;
  final MealType mealType;

  /// Portion eaten — the single biggest source of calorie variance, since
  /// only the user knows how much they actually ate. Defaults to regular so
  /// existing callers don't have to specify it. See
  /// IMPLEMENTATION_PLAN_UX_AI.md §1.
  final PortionSize portion;

  const Meal({
    required this.id,
    required this.name,
    required this.calories,
    required this.mealType,
    this.portion = PortionSize.regular,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'] as String,
      name: json['name'] as String,
      calories: json['calories'] as int,
      mealType: MealType.values.byName(json['mealType'] as String),
      portion: json['portion'] == null
          ? PortionSize.regular
          : PortionSize.values.byName(json['portion'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'mealType': mealType.name,
      'portion': portion.name,
    };
  }

  Meal copyWith({
    String? id,
    String? name,
    int? calories,
    MealType? mealType,
    PortionSize? portion,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      mealType: mealType ?? this.mealType,
      portion: portion ?? this.portion,
    );
  }
}
