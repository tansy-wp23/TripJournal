import '../models/geo_tag.dart';
import '../models/health_log.dart';
import '../models/journal_entry.dart';
import '../models/meal.dart';
import '../models/meal_type.dart';
import '../models/mood.dart';
import '../models/portion_size.dart';
import 'journal_repository.dart';

class MockJournalRepository implements JournalRepository {
  final List<JournalEntry> _entries = _seedEntries();

  @override
  Future<List<JournalEntry>> getEntries(String tripId) async {
    return _entries.where((e) => e.tripId == tripId).toList();
  }

  @override
  Future<JournalEntry?> getEntry(String id) async {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addEntry(JournalEntry entry) async {
    _entries.add(entry);
  }

  @override
  Future<void> updateEntry(JournalEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
    }
  }

  @override
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
  }

  static List<JournalEntry> _seedEntries() {
    return [
      JournalEntry(
        id: 'entry-1',
        tripId: 'trip-001',
        title: 'Arrival in Kyoto',
        body:
            'Landed in Kansai and took the train straight to Kyoto. Checked '
            'into the ryokan and wandered around Gion before dinner. Feet '
            'are already tired but the streets at dusk were worth it.',
        mood: Mood.excited,
        photoPaths: ['assets/mock/kyoto_arrival_1.jpg', 'assets/mock/gion_evening.jpg'],
        location: const GeoTag(
          latitude: 35.0116,
          longitude: 135.7681,
          placeName: 'Gion, Kyoto',
        ),
        createdAt: DateTime(2026, 4, 10, 19, 30),
        updatedAt: DateTime(2026, 4, 10, 19, 30),
        healthLog: HealthLog(
          id: 'health-1',
          entryId: 'entry-1',
          steps: 8200,
          caloriesEaten: 1950,
          caloriesBurned: 2350,
          meals: const [
            Meal(
              id: 'meal-1a',
              name: 'Onigiri set',
              calories: 350,
              mealType: MealType.breakfast,
              portion: PortionSize.small,
            ),
            Meal(
              id: 'meal-1b',
              name: 'Ramen',
              calories: 650,
              mealType: MealType.lunch,
              // Seeded so the food-photo path (meal thumbnails, the trip
              // carousel's food pictures, and the toggle that hides them) is
              // visible without picking from the device gallery.
              photoPath: 'assets/mock/ramen_lunch.jpg',
              // Seeded so the star-rating display path is visible without
              // rating a meal by hand.
              rating: 5,
            ),
            Meal(
              id: 'meal-1c',
              name: 'Kaiseki dinner',
              calories: 950,
              mealType: MealType.dinner,
              portion: PortionSize.large,
              rating: 4,
            ),
          ],
          aiAdvice:
              'Solid balance today. Try adding a vegetable side at dinner '
              'tomorrow to round things out.',
        ),
      ),
      JournalEntry(
        id: 'entry-2',
        tripId: 'trip-001',
        title: 'Fushimi Inari hike',
        body:
            'Climbed through the torii gates at Fushimi Inari all the way '
            'up. Legs are done for the day but the view over the city near '
            'the top was unreal.',
        mood: Mood.tired,
        photoPaths: ['assets/mock/fushimi_inari_gates.jpg'],
        location: const GeoTag(
          latitude: 34.9671,
          longitude: 135.7727,
          placeName: 'Fushimi Inari Taisha',
        ),
        createdAt: DateTime(2026, 4, 11, 17, 45),
        updatedAt: DateTime(2026, 4, 11, 17, 45),
        healthLog: HealthLog(
          id: 'health-2',
          entryId: 'entry-2',
          steps: 15600,
          caloriesEaten: 2400,
          caloriesBurned: 3100,
          meals: const [
            Meal(
              id: 'meal-2a',
              name: 'Convenience store rice ball',
              calories: 180,
              mealType: MealType.breakfast,
              portion: PortionSize.small,
            ),
            Meal(id: 'meal-2b', name: 'Udon', calories: 520, mealType: MealType.lunch),
            Meal(id: 'meal-2c', name: 'Yakitori skewers', calories: 700, mealType: MealType.dinner),
            Meal(
              id: 'meal-2d',
              name: 'Matcha soft serve',
              calories: 250,
              mealType: MealType.snack,
              portion: PortionSize.small,
            ),
          ],
          aiAdvice:
              'Big step count today — make sure to rehydrate and get some '
              'protein in before bed to help recovery.',
        ),
      ),
      JournalEntry(
        id: 'entry-3',
        tripId: 'trip-001',
        title: 'Rainy day at the museum',
        body:
            'Rained all morning so we stayed indoors at the Kyoto National '
            'Museum. Quiet, restful day compared to yesterday.',
        mood: Mood.neutral,
        photoPaths: [],
        location: const GeoTag(
          latitude: 34.9942,
          longitude: 135.7716,
          placeName: 'Kyoto National Museum',
        ),
        createdAt: DateTime(2026, 4, 12, 15, 0),
        updatedAt: DateTime(2026, 4, 12, 15, 0),
        healthLog: HealthLog(
          id: 'health-3',
          entryId: 'entry-3',
          steps: 3100,
          caloriesEaten: 1600,
          caloriesBurned: null,
          meals: const [
            Meal(
              id: 'meal-3a',
              name: 'Toast and coffee',
              calories: 300,
              mealType: MealType.breakfast,
              portion: PortionSize.small,
            ),
            Meal(id: 'meal-3b', name: 'Curry rice', calories: 700, mealType: MealType.lunch),
            Meal(id: 'meal-3c', name: 'Miso soup and grilled fish', calories: 600, mealType: MealType.dinner),
          ],
          aiAdvice:
              'Lower activity today — a lighter dinner would sit better '
              'given the reduced step count.',
        ),
      ),
      JournalEntry(
        id: 'entry-4',
        tripId: 'trip-002',
        title: 'Osaka street food crawl',
        body:
            'First night in Osaka, went straight to Dotonbori for takoyaki '
            'and okonomiyaki. Overwhelming in the best way.',
        mood: Mood.happy,
        photoPaths: ['assets/mock/dotonbori_night.jpg'],
        location: const GeoTag(
          latitude: 34.6687,
          longitude: 135.5013,
          placeName: 'Dotonbori, Osaka',
        ),
        createdAt: DateTime(2026, 3, 20, 20, 15),
        updatedAt: DateTime(2026, 3, 20, 20, 15),
        healthLog: HealthLog(
          id: 'health-4',
          entryId: 'entry-4',
          steps: 9800,
          caloriesEaten: 2600,
          caloriesBurned: 2900,
          meals: const [
            Meal(id: 'meal-4a', name: 'Takoyaki (8pc)', calories: 500, mealType: MealType.dinner),
            Meal(
              id: 'meal-4b',
              name: 'Okonomiyaki',
              calories: 750,
              mealType: MealType.dinner,
              portion: PortionSize.large,
            ),
            Meal(id: 'meal-4c', name: 'Kushikatsu', calories: 600, mealType: MealType.dinner),
            Meal(
              id: 'meal-4d',
              name: 'Sake tasting',
              calories: 250,
              mealType: MealType.snack,
              portion: PortionSize.small,
            ),
          ],
          aiAdvice:
              'Calorie-dense evening — consider a lighter, veggie-forward '
              'breakfast tomorrow to balance it out.',
        ),
      ),
    ];
  }
}
