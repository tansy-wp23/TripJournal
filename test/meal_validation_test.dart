import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/validation/meal_validation.dart';

void main() {
  group('validateMealName', () {
    test('empty or whitespace-only name is rejected', () {
      expect(validateMealName(''), 'Please enter a meal name.');
      expect(validateMealName('   '), 'Please enter a meal name.');
    });

    test('a real name is accepted', () {
      expect(validateMealName('Ramen'), isNull);
    });
  });

  group('validateMealCalories', () {
    test('0 calories is accepted', () {
      expect(validateMealCalories(0), isNull);
    });

    test('a positive value is accepted', () {
      expect(validateMealCalories(650), isNull);
    });

    test('a negative value is rejected', () {
      expect(validateMealCalories(-1), 'Please enter a valid number.');
    });
  });
}
