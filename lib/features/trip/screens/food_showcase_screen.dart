import 'package:flutter/material.dart';

import '../../journal/screens/entry_detail_screen.dart';
import '../../journal/widgets/photo_thumbnail.dart';
import '../trip_photos.dart';

/// Every food-section photo in a trip, grouped by day — a browsable index
/// into the trip's meals (`IMPLEMENTATION_PLAN_RATING_LOCATION_SHOWCASE.md`
/// §3). Read-only: it surfaces photos already logged through the meal
/// dialog's "Detect from photo" flow, it doesn't add new ones. Reuses
/// [PhotoThumbnail] (the same tile the meal rows and entry detail screen
/// already use) rather than a new gallery widget.
///
/// [photos] must already be filtered to `TripPhotoKind.meal` — the caller
/// (Trip View's header button) does that from the same `tripPhotos` list the
/// header carousel and slideshow already built, so day numbering can never
/// disagree between the three.
class FoodShowcaseScreen extends StatelessWidget {
  const FoodShowcaseScreen({super.key, required this.photos});

  final List<TripPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Showcase')),
      body: photos.isEmpty
          ? const _EmptyState()
          : _DayGroupedGrid(photos: photos),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            const Text(
              'No food photos yet',
              key: Key('food-showcase-empty-title'),
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Photos attached to a meal (via "Detect from photo") will '
              'show up here, grouped by day.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayGroupedGrid extends StatelessWidget {
  const _DayGroupedGrid({required this.photos});

  final List<TripPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final byDay = <int, List<TripPhoto>>{};
    for (final photo in photos) {
      byDay.putIfAbsent(photo.dayNumber, () => []).add(photo);
    }
    final days = byDay.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final day in days) ...[
          Text(
            'Day $day',
            key: Key('food-showcase-day-header-$day'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final photo in byDay[day]!)
                _FoodShowcaseTile(key: ValueKey(photo.path), photo: photo),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _FoodShowcaseTile extends StatelessWidget {
  const _FoodShowcaseTile({super.key, required this.photo});

  final TripPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhotoThumbnail(
          key: Key('food-showcase-photo-${photo.path}'),
          photoPath: photo.path,
          size: 96,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EntryDetailScreen(entryId: photo.entryId),
            ),
          ),
        ),
        if (photo.caption != null)
          SizedBox(
            width: 96,
            child: Text(
              photo.caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
