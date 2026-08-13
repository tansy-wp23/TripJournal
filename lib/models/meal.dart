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

  /// Local path to the photo this meal was logged from, when the user took
  /// one. Kept whether or not AI detection actually recognised the food — the
  /// photo is the user's, and a failed guess is no reason to throw it away.
  /// Null for a meal typed in by hand.
  final String? photoPath;

  const Meal({
    required this.id,
    required this.name,
    required this.calories,
    required this.mealType,
    this.portion = PortionSize.regular,
    this.photoPath,
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
      photoPath: json['photoPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'mealType': mealType.name,
      'portion': portion.name,
      'photoPath': photoPath,
    };
  }

  /// [clearPhotoPath] removes an existing photo — without it a null
  /// [photoPath] means "leave unchanged", the same convention as
  /// `HealthLog.clearCaloriesBurned` and `Profile.clearAvatarUrl`.
  Meal copyWith({
    String? id,
    String? name,
    int? calories,
    MealType? mealType,
    PortionSize? portion,
    String? photoPath,
    bool clearPhotoPath = false,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      mealType: mealType ?? this.mealType,
      portion: portion ?? this.portion,
      photoPath: clearPhotoPath ? null : (photoPath ?? this.photoPath),
    );
  }
}
