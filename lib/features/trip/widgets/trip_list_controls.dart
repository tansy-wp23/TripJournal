import 'package:flutter/material.dart';

import '../trip_list_sort.dart';

String _statusLabel(TripStatusFilter filter) {
  switch (filter) {
    case TripStatusFilter.all:
      return 'All';
    case TripStatusFilter.active:
      return 'Active';
    case TripStatusFilter.upcoming:
      return 'Upcoming';
    case TripStatusFilter.past:
      return 'Past';
  }
}

String _sortLabel(TripSortOption sort) {
  switch (sort) {
    case TripSortOption.defaultOrder:
      return 'Default';
    case TripSortOption.startDateNewest:
      return 'Start date (newest)';
    case TripSortOption.startDateOldest:
      return 'Start date (oldest)';
    case TripSortOption.titleAZ:
      return 'Title (A-Z)';
  }
}

/// Sort dropdown + status filter chips above the home-screen trip list
/// (IMPLEMENTATION_PLAN_EXTRA_FEATURES.md #3). View-only controls; the
/// actual reordering/filtering is the pure `sortAndFilterTrips`.
class TripListControls extends StatelessWidget {
  const TripListControls({
    super.key,
    required this.sort,
    required this.statusFilter,
    required this.onSortChanged,
    required this.onStatusFilterChanged,
  });

  final TripSortOption sort;
  final TripStatusFilter statusFilter;
  final ValueChanged<TripSortOption> onSortChanged;
  final ValueChanged<TripStatusFilter> onStatusFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in TripStatusFilter.values) ...[
                  ChoiceChip(
                    key: Key('trip-status-filter-${filter.name}'),
                    label: Text(_statusLabel(filter)),
                    selected: statusFilter == filter,
                    onSelected: (_) => onStatusFilterChanged(filter),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        PopupMenuButton<TripSortOption>(
          key: const Key('trip-sort-menu'),
          tooltip: 'Sort trips',
          initialValue: sort,
          onSelected: onSortChanged,
          itemBuilder: (context) => [
            for (final option in TripSortOption.values)
              PopupMenuItem(
                key: Key('trip-sort-option-${option.name}'),
                value: option,
                child: Text(_sortLabel(option)),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort),
                const SizedBox(width: 4),
                Text(
                  _sortLabel(sort),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown instead of the trip list when a status filter narrows the result
/// to zero trips (IMPLEMENTATION_PLAN_EXTRA_FEATURES.md #4 — empty state
/// with a friendly message and a clear action).
class TripListNoMatchesState extends StatelessWidget {
  const TripListNoMatchesState({super.key, required this.onClearFilter});

  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('trip-list-no-matches'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            const Text('No trips match this filter.'),
            TextButton(
              key: const Key('clear-trip-status-filter-button'),
              onPressed: onClearFilter,
              child: const Text('Clear filter'),
            ),
          ],
        ),
      ),
    );
  }
}
