import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/models/geo_tag.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/mood.dart';
import 'package:tripjournal/models/portion_size.dart';

void main() {
  group('Meal', () {
    const meal = Meal(id: 'meal-1', name: 'Ramen', calories: 650, mealType: MealType.lunch);

    test('portion defaults to regular when not specified', () {
      expect(meal.portion, PortionSize.regular);
    });

    test('toJson/fromJson round-trip preserves portion', () {
      const large = Meal(
        id: 'meal-2',
        name: 'Kaiseki dinner',
        calories: 950,
        mealType: MealType.dinner,
        portion: PortionSize.large,
      );
      final restored = Meal.fromJson(large.toJson());
      expect(restored.id, large.id);
      expect(restored.name, large.name);
      expect(restored.calories, large.calories);
      expect(restored.mealType, large.mealType);
      expect(restored.portion, PortionSize.large);
    });

    test('fromJson defaults to regular when portion is missing (backward compatibility)', () {
      final json = meal.toJson()..remove('portion');
      final restored = Meal.fromJson(json);
      expect(restored.portion, PortionSize.regular);
    });

    test('photoPath defaults to null for a meal typed in by hand', () {
      expect(meal.photoPath, isNull);
    });

    test('toJson/fromJson round-trip preserves photoPath', () {
      const photographed = Meal(
        id: 'meal-3',
        name: 'Nasi lemak',
        calories: 600,
        mealType: MealType.breakfast,
        photoPath: '/data/photos/abc.jpg',
      );
      final restored = Meal.fromJson(photographed.toJson());
      expect(restored.photoPath, '/data/photos/abc.jpg');
    });

    test('fromJson tolerates a missing photoPath (meals saved before photos existed)', () {
      final json = meal.toJson()..remove('photoPath');
      expect(Meal.fromJson(json).photoPath, isNull);
    });

    test('copyWith keeps an existing photo unless clearPhotoPath is set', () {
      const photographed = Meal(
        id: 'meal-4',
        name: 'Ramen',
        calories: 650,
        mealType: MealType.lunch,
        photoPath: '/data/photos/ramen.jpg',
      );
      expect(photographed.copyWith(calories: 700).photoPath, '/data/photos/ramen.jpg');
      expect(photographed.copyWith(clearPhotoPath: true).photoPath, isNull);
    });

    test('copyWith overrides only given fields', () {
      final updated = meal.copyWith(calories: 700);
      expect(updated.id, meal.id);
      expect(updated.name, meal.name);
      expect(updated.mealType, meal.mealType);
      expect(updated.calories, 700);
      expect(updated.portion, meal.portion);
    });

    test('copyWith overrides portion', () {
      final updated = meal.copyWith(portion: PortionSize.small);
      expect(updated.portion, PortionSize.small);
      expect(updated.calories, meal.calories);
    });

    test('rating defaults to null (not rated)', () {
      expect(meal.rating, isNull);
    });

    test('constructor rejects a rating outside 1-5', () {
      expect(
        () => Meal(
          id: 'meal-bad',
          name: 'Bad rating',
          calories: 100,
          mealType: MealType.snack,
          rating: 6,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => Meal(
          id: 'meal-bad',
          name: 'Bad rating',
          calories: 100,
          mealType: MealType.snack,
          rating: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('toJson/fromJson round-trip preserves rating', () {
      const rated = Meal(
        id: 'meal-5',
        name: 'Char kway teow',
        calories: 550,
        mealType: MealType.dinner,
        rating: 5,
      );
      final restored = Meal.fromJson(rated.toJson());
      expect(restored.rating, 5);
    });

    test('fromJson tolerates a missing rating (meals saved before ratings existed)', () {
      final json = meal.toJson()..remove('rating');
      expect(Meal.fromJson(json).rating, isNull);
    });

    test('copyWith keeps an existing rating unless clearRating is set', () {
      const rated = Meal(
        id: 'meal-6',
        name: 'Ramen',
        calories: 650,
        mealType: MealType.lunch,
        rating: 3,
      );
      expect(rated.copyWith(calories: 700).rating, 3);
      expect(rated.copyWith(clearRating: true).rating, isNull);
    });

    test('copyWith overrides rating', () {
      final updated = meal.copyWith(rating: 4);
      expect(updated.rating, 4);
      expect(updated.calories, meal.calories);
    });
  });

  group('PortionSize calorieMultiplier', () {
    test('small is 0.7, regular is 1.0, large is 1.4', () {
      expect(PortionSize.small.calorieMultiplier, 0.7);
      expect(PortionSize.regular.calorieMultiplier, 1.0);
      expect(PortionSize.large.calorieMultiplier, 1.4);
    });
  });

  group('GeoTag', () {
    const tag = GeoTag(latitude: 35.0116, longitude: 135.7681, placeName: 'Gion, Kyoto');

    test('loads old three-field JSON without optional location metadata', () {
      final restored = GeoTag.fromJson({
        'latitude': 3.139,
        'longitude': 101.6869,
        'placeName': 'Merdeka Square',
      });

      expect(restored.latitude, 3.139);
      expect(restored.longitude, 101.6869);
      expect(restored.placeName, 'Merdeka Square');
      expect(restored.formattedAddress, isNull);
      expect(restored.placeId, isNull);
    });

    test('round-trips full location metadata', () {
      const full = GeoTag(
        latitude: 3.139,
        longitude: 101.6869,
        placeName: 'Merdeka Square',
        formattedAddress: 'Jalan Raja, Kuala Lumpur',
        placeId: 'place-123',
      );

      final restored = GeoTag.fromJson(full.toJson());

      expect(restored.formattedAddress, 'Jalan Raja, Kuala Lumpur');
      expect(restored.placeId, 'place-123');
    });

    test('toJson/fromJson round-trip', () {
      final restored = GeoTag.fromJson(tag.toJson());
      expect(restored.latitude, tag.latitude);
      expect(restored.longitude, tag.longitude);
      expect(restored.placeName, tag.placeName);
    });

    test('fromJson tolerates integer-valued lat/lng (num, not double)', () {
      final restored = GeoTag.fromJson({'latitude': 35, 'longitude': 135, 'placeName': null});
      expect(restored.latitude, 35.0);
      expect(restored.longitude, 135.0);
      expect(restored.placeName, isNull);
    });

    test('copyWith overrides only given fields', () {
      final updated = tag.copyWith(placeName: 'Somewhere else');
      expect(updated.latitude, tag.latitude);
      expect(updated.longitude, tag.longitude);
      expect(updated.placeName, 'Somewhere else');
    });
  });

  group('HealthLog', () {
    const log = HealthLog(
      id: 'health-1',
      entryId: 'entry-1',
      steps: 8200,
      caloriesEaten: 1950,
      caloriesBurned: 2350,
      meals: [
        Meal(id: 'meal-1a', name: 'Onigiri set', calories: 350, mealType: MealType.breakfast),
        Meal(id: 'meal-1b', name: 'Ramen', calories: 650, mealType: MealType.lunch),
      ],
      aiAdvice: 'Solid balance today.',
    );

    test('toJson/fromJson round-trip', () {
      final restored = HealthLog.fromJson(log.toJson());
      expect(restored.id, log.id);
      expect(restored.entryId, log.entryId);
      expect(restored.steps, log.steps);
      expect(restored.caloriesEaten, log.caloriesEaten);
      expect(restored.caloriesBurned, log.caloriesBurned);
      expect(restored.meals.length, log.meals.length);
      expect(restored.meals.first.name, log.meals.first.name);
      expect(restored.aiAdvice, log.aiAdvice);
    });

    test('round-trip with null aiAdvice, null caloriesBurned, and empty meals', () {
      const noAdvice = HealthLog(id: 'h', entryId: 'e', steps: 0, caloriesEaten: 0, meals: []);
      final restored = HealthLog.fromJson(noAdvice.toJson());
      expect(restored.aiAdvice, isNull);
      expect(restored.caloriesBurned, isNull);
      expect(restored.meals, isEmpty);
    });

    test('copyWith overrides only given fields', () {
      final updated = log.copyWith(steps: 9000);
      expect(updated.steps, 9000);
      expect(updated.caloriesEaten, log.caloriesEaten);
      expect(updated.caloriesBurned, log.caloriesBurned);
      expect(updated.meals, log.meals);
      expect(updated.aiAdvice, log.aiAdvice);
    });

    test('copyWith clearCaloriesBurned sets it back to null', () {
      final updated = log.copyWith(clearCaloriesBurned: true);
      expect(updated.caloriesBurned, isNull);
      expect(updated.caloriesEaten, log.caloriesEaten);
    });
  });

  group('JournalEntry', () {
    final entry = JournalEntry(
      id: 'entry-1',
      tripId: 'trip-001',
      title: 'Arrival in Kyoto',
      body: 'Landed in Kansai and took the train straight to Kyoto.',
      mood: Mood.excited,
      photoPaths: const ['assets/mock/kyoto_arrival_1.jpg'],
      location: const GeoTag(latitude: 35.0116, longitude: 135.7681, placeName: 'Gion, Kyoto'),
      createdAt: DateTime(2026, 4, 10, 19, 30),
      updatedAt: DateTime(2026, 4, 10, 19, 30),
      healthLog: const HealthLog(
        id: 'health-1',
        entryId: 'entry-1',
        steps: 8200,
        caloriesEaten: 1950,
        meals: [Meal(id: 'meal-1a', name: 'Onigiri set', calories: 350, mealType: MealType.breakfast)],
        aiAdvice: 'Solid balance today.',
      ),
    );

    test('toJson/fromJson round-trip', () {
      final restored = JournalEntry.fromJson(entry.toJson());
      expect(restored.id, entry.id);
      expect(restored.tripId, entry.tripId);
      expect(restored.title, entry.title);
      expect(restored.body, entry.body);
      expect(restored.mood, entry.mood);
      expect(restored.photoPaths, entry.photoPaths);
      expect(restored.location?.placeName, entry.location?.placeName);
      expect(restored.createdAt, entry.createdAt);
      expect(restored.updatedAt, entry.updatedAt);
      expect(restored.healthLog?.steps, entry.healthLog?.steps);
      expect(restored.healthLog?.meals.length, entry.healthLog?.meals.length);
    });

    test('round-trip with null location and null healthLog', () {
      final noOptional = JournalEntry(
        id: entry.id,
        tripId: entry.tripId,
        title: entry.title,
        body: entry.body,
        mood: entry.mood,
        photoPaths: entry.photoPaths,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
      );
      final restored = JournalEntry.fromJson(noOptional.toJson());
      expect(restored.location, isNull);
      expect(restored.healthLog, isNull);
    });

    test('copyWith overrides only given fields', () {
      final updated = entry.copyWith(title: 'Updated title', mood: Mood.happy);
      expect(updated.title, 'Updated title');
      expect(updated.mood, Mood.happy);
      expect(updated.id, entry.id);
      expect(updated.body, entry.body);
      expect(updated.healthLog, entry.healthLog);
    });

    test('copyWith clearLocation removes an existing location', () {
      expect(entry.copyWith(clearLocation: true).location, isNull);
    });

    test('copyWith rejects providing a location while clearing it', () {
      expect(
        () => entry.copyWith(
          location: const GeoTag(latitude: 1, longitude: 2),
          clearLocation: true,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    group('displayTitle', () {
      test('uses the title when present', () {
        expect(entry.displayTitle, 'Arrival in Kyoto');
      });

      test('falls back to a body snippet for a body-only entry (title OR body rule)', () {
        final bodyOnly = entry.copyWith(title: '', body: 'Short body.');
        expect(bodyOnly.displayTitle, 'Short body.');
      });

      test('truncates a long body snippet to 40 chars plus an ellipsis', () {
        final longBody = 'a' * 60;
        final bodyOnly = entry.copyWith(title: '', body: longBody);
        expect(bodyOnly.displayTitle, '${'a' * 40}…');
      });

      test('falls back to a placeholder when both title and body are empty', () {
        final empty = entry.copyWith(title: '', body: '');
        expect(empty.displayTitle, '(Untitled entry)');
      });

      test('whitespace-only title is treated as empty', () {
        final whitespaceTitle = entry.copyWith(title: '   ', body: 'Real content.');
        expect(whitespaceTitle.displayTitle, 'Real content.');
      });
    });
  });
}
