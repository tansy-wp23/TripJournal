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

  group('validateMealRating', () {
    test('null (not rated) is always accepted', () {
      expect(validateMealRating(null), isNull);
    });

    test('1 through 5 are accepted', () {
      for (var rating = 1; rating <= 5; rating++) {
        expect(validateMealRating(rating), isNull);
      }
    });

    test('0 and 6 are rejected', () {
      expect(validateMealRating(0), isNotNull);
      expect(validateMealRating(6), isNotNull);
    });
  });

  group('validateMealRestaurantName', () {
    test('null or blank is always accepted', () {
      expect(validateMealRestaurantName(null), isNull);
      expect(validateMealRestaurantName(''), isNull);
      expect(validateMealRestaurantName('   '), isNull);
    });

    test('exactly at the cap is accepted', () {
      expect(validateMealRestaurantName('a' * kMealRestaurantNameMaxLength), isNull);
    });

    test('over the cap is rejected', () {
      expect(
        validateMealRestaurantName('a' * (kMealRestaurantNameMaxLength + 1)),
        'Restaurant name must be $kMealRestaurantNameMaxLength characters or fewer.',
      );
    });
  });

  group('validateMealReview', () {
    test('null or blank is always accepted', () {
      expect(validateMealReview(null), isNull);
      expect(validateMealReview(''), isNull);
      expect(validateMealReview('   '), isNull);
    });

    test('exactly at the cap is accepted', () {
      expect(validateMealReview('a' * kMealReviewMaxLength), isNull);
    });

    test('over the cap is rejected', () {
      expect(
        validateMealReview('a' * (kMealReviewMaxLength + 1)),
        'Review must be $kMealReviewMaxLength characters or fewer.',
      );
    });
  });
}
