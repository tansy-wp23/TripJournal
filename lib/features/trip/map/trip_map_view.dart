import 'package:flutter/material.dart';

import '../../../models/geo_tag.dart';
import '../../../models/journal_entry.dart';
import '../../journal/widgets/format_utils.dart';
import '../../journal/widgets/mood_display.dart';
import '../../journal/widgets/photo_thumbnail.dart';
import 'trip_map_model.dart';

/// Builds a platform-specific map surface from the current marker groups.
///
/// Keeping the map behind this small callback lets the trip UI work without a
/// map SDK. A future Google Maps surface can implement this contract, while
/// tests provide a lightweight fake.
typedef TripMapBuilder =
    Widget Function({
      required TripMapModel model,
      required ValueChanged<TripMapMarkerGroup> onSelected,
    });

/// Displays trip entry locations, day filters, and entry previews.
class TripMapView extends StatefulWidget {
  const TripMapView({
    super.key,
    required this.entries,
    required this.tripStartDate,
    required this.tripEndDate,
    required this.mapBuilder,
    required this.onOpenEntry,
    required this.onAddLocation,
  });

  final List<JournalEntry> entries;
  final DateTime tripStartDate;
  final DateTime tripEndDate;
  final TripMapBuilder mapBuilder;
  final ValueChanged<JournalEntry> onOpenEntry;
  final VoidCallback onAddLocation;

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView> {
  int? _selectedDay;
  TripMapMarkerGroup? _selectedGroup;

  @override
  void didUpdateWidget(TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedDay = _selectedDay;
    if (selectedDay == null) return;
    final updatedDays = buildTripMapModel(
      entries: widget.entries,
      tripStartDate: widget.tripStartDate,
      tripEndDate: widget.tripEndDate,
    ).availableDays;
    if (!updatedDays.contains(selectedDay)) {
      _selectedDay = null;
      _selectedGroup = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = buildTripMapModel(
      entries: widget.entries,
      tripStartDate: widget.tripStartDate,
      tripEndDate: widget.tripEndDate,
      selectedDay: _selectedDay,
    );
    final selectedGroup = _visibleSelectedGroup(model);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '${model.mappedEntryCount} mapped · ${model.unmappedEntryCount} without location',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (model.groups.isEmpty)
          _EmptyMapState(onAddLocation: widget.onAddLocation)
        else ...[
          _DayFilterBar(
            availableDays: model.availableDays,
            selectedDay: _selectedDay,
            onSelected: _selectDay,
          ),
          if (model.previousDayHasNoMappedEntry)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Previous day has no mapped entry',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Lines show journal order only — not roads or navigation.',
              key: const Key('trip-map-route-disclaimer'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.mapBuilder(
                  model: model,
                  onSelected: _selectGroup,
                ),
              ),
            ),
          ),
          if (selectedGroup != null)
            Flexible(
              fit: FlexFit.loose,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: _EntryPreviewList(
                  group: selectedGroup,
                  onOpenEntry: widget.onOpenEntry,
                ),
              ),
            ),
        ],
      ],
    );
  }

  TripMapMarkerGroup? _visibleSelectedGroup(TripMapModel model) {
    final key = _selectedGroup?.key;
    if (key == null) return null;
    for (final group in model.groups) {
      if (group.key == key) return group;
    }
    return null;
  }

  void _selectDay(int? day) {
    setState(() {
      _selectedDay = day;
      _selectedGroup = null;
    });
  }

  void _selectGroup(TripMapMarkerGroup group) {
    setState(() => _selectedGroup = group);
  }
}

class _DayFilterBar extends StatelessWidget {
  const _DayFilterBar({
    required this.availableDays,
    required this.selectedDay,
    required this.onSelected,
  });

  final List<int> availableDays;
  final int? selectedDay;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ChoiceChip(
            key: const Key('trip-map-day-all'),
            label: const Text('All'),
            selected: selectedDay == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final day in availableDays) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              key: Key('trip-map-day-$day'),
              label: Text('Day $day'),
              selected: selectedDay == day,
              onSelected: (_) => onSelected(day),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyMapState extends StatelessWidget {
  const _EmptyMapState({required this.onAddLocation});

  final VoidCallback onAddLocation;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'No locations yet',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Add a location to an entry to see it on your trip map.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('trip-map-add-location'),
                onPressed: onAddLocation,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add location to an entry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryPreviewList extends StatelessWidget {
  const _EntryPreviewList({required this.group, required this.onOpenEntry});

  final TripMapMarkerGroup group;
  final ValueChanged<JournalEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView.separated(
        key: const Key('trip-map-preview-list'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: group.entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _EntryPreview(
          entry: group.entries[index],
          onTap: () => onOpenEntry(group.entries[index]),
        ),
      ),
    );
  }
}

class _EntryPreview extends StatelessWidget {
  const _EntryPreview({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final location = entry.location!;
    return InkWell(
      key: Key('trip-map-preview-${entry.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: entry.photoPaths.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Icon(Icons.location_on_outlined),
                    )
                  : PhotoThumbnail(photoPath: entry.photoPaths.first, size: 56),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDate(entry.createdAt),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_locationLabel(location)} · ${moodLabel(entry.mood)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

String _locationLabel(GeoTag location) {
  final placeName = location.placeName?.trim();
  if (placeName != null && placeName.isNotEmpty) return placeName;
  final address = location.formattedAddress?.trim();
  if (address != null && address.isNotEmpty) return address;
  return '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
}

/// A map-SDK-free surface for unavailable platforms or map initialization
/// failures. Every visible marker group remains selectable.
class TripMapUnavailableSurface extends StatelessWidget {
  const TripMapUnavailableSurface({
    super.key,
    required this.model,
    required this.onSelected,
    this.onRetry,
  });

  final TripMapModel model;
  final ValueChanged<TripMapMarkerGroup> onSelected;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.map_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Map unavailable',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Locations are still available as a list.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final connector in model.connectors)
            Card(
              child: ListTile(
                key: Key('trip-map-fallback-connector-${connector.id}'),
                leading: const Icon(Icons.arrow_forward_outlined),
                title: Text(
                  'Day ${connector.fromDay} last stop → '
                  'Day ${connector.toDay} first stop',
                ),
                subtitle: Text('${connector.fromLabel} → ${connector.toLabel}'),
              ),
            ),
          for (final group in model.groups)
            Card(
              child: ListTile(
                key: Key('trip-map-fallback-${group.key}'),
                onTap: () => onSelected(group),
                leading: Icon(
                  group.isPreviousDayContext
                      ? Icons.history_outlined
                      : Icons.location_on_outlined,
                  color: group.isPreviousDayContext
                      ? Theme.of(context).colorScheme.outline
                      : null,
                ),
                title: Text(
                  _locationLabel(group.entries.first.location!),
                  style: group.isPreviousDayContext
                      ? TextStyle(color: Theme.of(context).colorScheme.outline)
                      : null,
                ),
                subtitle: Text(
                  'Day ${group.dayNumber}${group.isPreviousDayContext ? ' · Previous day context' : ''} · '
                  '${group.entries.length} ${group.entries.length == 1 ? 'entry' : 'entries'}',
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
        ],
      ),
    );
  }
}
