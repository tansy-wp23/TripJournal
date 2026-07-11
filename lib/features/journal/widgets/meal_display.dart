import '../../../models/meal_type.dart';
import '../../../models/portion_size.dart';

String mealTypeLabel(MealType type) {
  switch (type) {
    case MealType.breakfast:
      return 'Breakfast';
    case MealType.lunch:
      return 'Lunch';
    case MealType.dinner:
      return 'Dinner';
    case MealType.snack:
      return 'Snack';
  }
}

String portionSizeLabel(PortionSize portion) {
  switch (portion) {
    case PortionSize.small:
      return 'Small';
    case PortionSize.regular:
      return 'Regular';
    case PortionSize.large:
      return 'Large';
  }
}
