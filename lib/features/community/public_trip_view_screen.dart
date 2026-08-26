import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/repository_locator.dart';
import '../../models/journal_entry.dart';
import '../../models/meal.dart';
import '../../models/trip.dart';
import '../journal/screens/photo_viewer_screen.dart';
import '../journal/widgets/format_utils.dart';
import '../journal/widgets/meal_display.dart';
import '../journal/widgets/meal_rating_stars.dart';
import '../journal/widgets/mood_display.dart';
import '../journal/widgets/photo_thumbnail.dart';
import '../trip/trip_day_groups.dart';
import '../trip/trip_summary_stats.dart';
import '../trip/widgets/trip_cover_photo.dart';
import '../trip/widgets/trip_photo_carousel.dart';
import '../trip/widgets/wellness_stats_row.dart';

/// Read-only view of a public trip. No edit/add/delete actions.
class PublicTripViewScreen extends ConsumerStatefulWidget {
  const PublicTripViewScreen({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<PublicTripViewScreen> createState() =>
      _PublicTripViewScreenState();
}

class _PublicTripViewScreenState extends ConsumerState<PublicTripViewScreen> {
  List<JournalEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _entries = await journalRepository.getEntries(widget.trip.id);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _shareTripLink() {
    final trip = widget.trip;
    final shareText =
        'Check out this trip "${trip.title}" on TripJournal!\n\n'
        'Open the app → Community → Search by ID:\n${trip.id}';
    Share.share(shareText, subject: 'TripJournal: ${trip.title}');
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.title),
        actions: [
          IconButton(
            key: const Key('public-trip-share-button'),
            icon: const Icon(Icons.share),
            tooltip: 'Share trip',
            onPressed: _shareTripLink,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : ListView(
              padding: const EdgeInsets.all(0),
              children: [
                Container(
                  color: colorScheme.primaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: trip.publisherAvatarUrl != null
                            ? NetworkImage(trip.publisherAvatarUrl!)
                            : null,
                        child: trip.publisherAvatarUrl == null
                            ? const Icon(Icons.person, size: 18)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Shared by ${trip.publisherDisplayName ?? 'Anonymous'}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: colorScheme.onPrimaryContainer),
                        ),
                      ),
                      Icon(
                        Icons.public,
                        size: 18,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),

                if (trip.coverPhotoPath != null)
                  TripCoverPhoto(
                    photoPath: trip.coverPhotoPath,
                    height: TripPhotoCarousel.resolveHeight(context, max: 180),
                    width: double.infinity,
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      if (trip.destination != null &&
                          trip.destination!.trim().isNotEmpty)
                        Text(
                          trip.destination!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.outline),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatDate(trip.startDate)} – ${formatDate(trip.endDate)} · ${trip.durationDays} days',
                      ),
                      if (trip.summary != null &&
                          trip.summary!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Card(
                          color: colorScheme.secondaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trip Summary',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Text(trip.summary!),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (_entries.isNotEmpty) ...[
                        WellnessStatsRow(
                          stats: computeTripStats(
                            entries: _entries,
                            totalDays: trip.durationDays,
                          ),
                        ),
                        const Divider(height: 24),
                      ],
                    ],
                  ),
                ),

                if (_entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No entries in this trip yet.')),
                  )
                else
                  ..._buildDayGroups(context, trip),
              ],
            ),
    );
  }

  List<Widget> _buildDayGroups(BuildContext context, Trip trip) {
    final dayGroups = buildDayGroups(trip, _entries);
    final colorScheme = Theme.of(context).colorScheme;
    final widgets = <Widget>[];

    for (final group in dayGroups) {
      if (group.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day ${group.dayNumber} — ${formatDate(group.date)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              for (final entry in group.entries)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(moodIcon(entry.mood), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.displayTitle,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        if (entry.body.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(entry.body),
                        ],
                        if (entry.photoPaths.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (
                                var i = 0;
                                i < entry.photoPaths.length;
                                i++
                              )
                                PhotoThumbnail(
                                  key: Key('public-entry-photo-${entry.id}-$i'),
                                  photoPath: entry.photoPaths[i],
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PhotoViewerScreen(
                                        photoPaths: entry.photoPaths,
                                        initialIndex: i,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (entry.healthLog != null) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.directions_walk, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${formatThousands(entry.healthLog!.steps)} steps',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${entry.healthLog!.caloriesEaten} kcal eaten',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (entry.healthLog!.meals.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Meals',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            for (final meal in entry.healthLog!.meals)
                              _PublicMealTile(meal: meal),
                          ],
                        ],
                        if (entry.location?.locationTag != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                entry.location!.locationTag!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colorScheme.primary),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }
}

/// One meal's full detail — photo, name, type/portion/calories, restaurant,
/// review, and rating — read-only. Mirrors the meal row on
/// `EntryDetailScreen`, since a public trip should show a visitor everything
/// the owner logged, not just a name.
class _PublicMealTile extends StatelessWidget {
  const _PublicMealTile({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meal.photoPath != null) ...[
            PhotoThumbnail(
              key: Key('public-meal-photo-${meal.id}'),
              photoPath: meal.photoPath!,
              size: 56,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoViewerScreen(
                    photoPaths: [meal.photoPath!],
                    initialIndex: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.name, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  '${mealTypeLabel(meal.mealType)} · ${portionSizeLabel(meal.portion)} · '
                  '~${meal.calories} kcal',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
                if (meal.restaurantName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      meal.restaurantName!,
                      key: Key('public-meal-restaurant-${meal.id}'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (meal.foodReview != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      meal.foodReview!,
                      key: Key('public-meal-review-${meal.id}'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (meal.rating != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: MealRatingStars(
                      key: Key('public-meal-rating-${meal.id}'),
                      rating: meal.rating,
                      size: 14,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
