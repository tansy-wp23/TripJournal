import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/journal_entry.dart';
import '../../models/trip.dart';
import '../journal/controller/journal_controller.dart';
import '../journal/screens/create_edit_entry_screen.dart';
import '../journal/screens/entry_detail_screen.dart';
import '../journal/widgets/format_utils.dart';
import '../journal/widgets/mood_display.dart';
import 'controller/trip_controller.dart';
import 'mock_user.dart';
import 'screens/trip_wellness_screen.dart';
import 'trip_day_groups.dart';
import 'trip_form_screen.dart';
import 'trip_notes_editor_screen.dart';
import 'trip_summary_stats.dart';
import 'widgets/delete_trip_confirmation_dialog.dart';
import 'widgets/journal_search_bar.dart';
import 'widgets/trip_cover_photo.dart';
import 'widgets/wellness_stats_row.dart';

/// The "journey" screen (IMPLEMENTATION_PLAN_HOMEPAGE.md Phase 5) — a
/// vertical day-by-day timeline for one trip, reached from the homepage.
class TripViewScreen extends ConsumerStatefulWidget {
  const TripViewScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripViewScreen> createState() => _TripViewScreenState();
}

class _TripViewScreenState extends ConsumerState<TripViewScreen> {
  bool _searchVisible = false;

  /// First-use hint dismissal, in-memory only for this screen instance --
  /// reappears next time the trip is opened, which is fine for a low-stakes
  /// discoverability nudge (IMPLEMENTATION_PLAN_EXTRA_FEATURES.md #4).
  bool _tapToEditHintDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final tripController = ref.read(tripControllerProvider.notifier);
    if (ref.read(tripControllerProvider).trips.isEmpty) {
      await tripController.loadTrips(kMockUserId);
    }
    if (!mounted) return;
    await ref
        .read(journalControllerProvider.notifier)
        .loadEntries(widget.tripId);
  }

  Trip? _findTrip(List<Trip> trips) {
    for (final trip in trips) {
      if (trip.id == widget.tripId) return trip;
    }
    return null;
  }

  Future<void> _confirmAndDeleteTrip(Trip trip) async {
    final tripController = ref.read(tripControllerProvider.notifier);
    final entryCount = await tripController.countEntriesForTrip(trip.id);
    if (!mounted) return;

    final confirmed = await showDeleteTripConfirmationDialog(
      context,
      tripTitle: trip.title,
      entryCount: entryCount,
    );
    if (!confirmed || !mounted) return;

    await tripController.deleteTrip(trip.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tripController = ref.watch(tripControllerProvider);
    final journalController = ref.watch(journalControllerProvider);
    final trip = _findTrip(tripController.trips);

    if (trip == null) {
      return const Scaffold(body: Center(child: Text('Trip not found.')));
    }

    final stats = computeTripStats(
      entries: journalController.entries,
      totalDays: trip.durationDays,
    );
    final dayGroups = buildDayGroups(trip, journalController.entries);

    final filter = journalController.filter;
    final displayDayGroups = filter.isActive
        ? buildDayGroups(
            trip,
            journalController.filteredEntries,
          ).where((g) => !g.isEmpty).toList()
        : dayGroups;

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.title),
        actions: [
          IconButton(
            key: const Key('trip-view-search-toggle'),
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            onPressed: () {
              setState(() => _searchVisible = !_searchVisible);
              if (!_searchVisible) {
                ref.read(journalControllerProvider.notifier).clearFilter();
              }
            },
          ),
          IconButton(
            key: const Key('trip-view-edit-button'),
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TripFormScreen(existingTrip: trip),
              ),
            ),
          ),
          IconButton(
            key: const Key('trip-view-delete-button'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmAndDeleteTrip(trip),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchVisible)
            JournalSearchBar(
              filter: filter,
              onChanged: (f) =>
                  ref.read(journalControllerProvider.notifier).setFilter(f),
            ),
          Expanded(
            child: filter.isActive && displayDayGroups.isEmpty
                ? ListView(
                    children: [
                      _buildHeader(
                        context,
                        trip,
                        stats,
                        journalController.entries,
                      ),
                      _NoMatchingEntriesState(
                        onClearFilters: () => ref
                            .read(journalControllerProvider.notifier)
                            .clearFilter(),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: displayDayGroups.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildHeader(
                          context,
                          trip,
                          stats,
                          journalController.entries,
                        );
                      }
                      return _DayGroupTile(
                        trip: trip,
                        group: displayDayGroups[index - 1],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Trip trip,
    TripStats stats,
    List<JournalEntry> entries,
  ) {
    final notes = trip.notes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TripCoverPhoto(
          photoPath: trip.coverPhotoPath,
          height: 160,
          width: double.infinity,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${formatDate(trip.startDate)} - ${formatDate(trip.endDate)}',
              ),
              const SizedBox(height: 12),
              InkWell(
                key: const Key('trip-wellness-link'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TripWellnessScreen(trip: trip, entries: entries),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: WellnessStatsRow(stats: stats)),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ),
              if (entries.isEmpty) ...[
                const SizedBox(height: 12),
                _NoEntriesYetHint(
                  tripHasStarted: !trip.startDate.isAfter(DateTime.now()),
                ),
              ] else if (!_tapToEditHintDismissed) ...[
                const SizedBox(height: 12),
                _TapToEditHint(
                  onDismiss: () =>
                      setState(() => _tapToEditHintDismissed = true),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('trip-notes-card'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TripNotesEditorScreen(trip: trip),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sticky_note_2_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Notes & Reminders',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notes != null && notes.trim().isNotEmpty
                              ? notes
                              : 'No notes yet — tap to add.',
                          style: notes != null && notes.trim().isNotEmpty
                              ? null
                              : TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _DayGroupTile extends StatelessWidget {
  const _DayGroupTile({required this.trip, required this.group});

  final Trip trip;
  final DayGroup group;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = group.date.isAtSameMomentAs(today);
    final isFuture = group.date.isAfter(today);
    final isWritable = !isFuture;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: isToday
            ? Border.all(color: colorScheme.primary, width: 2)
            : null,
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day ${group.dayNumber} — ${formatWeekday(group.date)} ${formatDate(group.date)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
          if (isFuture)
            Text(
              'Upcoming',
              style: TextStyle(
                color: colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (group.isEmpty)
            Text(
              'No entry logged',
              style: TextStyle(color: colorScheme.outline),
            )
          else
            for (final entry in group.entries)
              _EntryTile(
                entry: entry,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EntryDetailScreen(entryId: entry.id),
                  ),
                ),
              ),
          if (isWritable) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              key: Key('add-entry-day-${group.dayNumber}'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateEditEntryScreen(
                    tripId: trip.id,
                    initialDate: group.date,
                    trip: trip,
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add entry'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single entry within a day group — deliberately its own visually
/// separated, elevated card so it doesn't blend into the day container
/// around it (IMPLEMENTATION_PLAN_UX_POLISH.md §4). The day stays the
/// grouping header; this is the clearly-tappable item within it.
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final healthLog = entry.healthLog;
    final colorScheme = Theme.of(context).colorScheme;
    final quickStats = healthLog != null
        ? '${formatThousands(healthLog.steps)} steps · ${moodLabel(entry.mood)}'
        : moodLabel(entry.mood);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('entry-tile-${entry.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(moodIcon(entry.mood), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayTitle,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        quickStats,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoEntriesYetHint extends StatelessWidget {
  const _NoEntriesYetHint({required this.tripHasStarted});

  /// Whether at least one day of the trip is today or in the past. A future
  /// trip has no writable day yet, so the hint must not claim there's an
  /// action to take right now (also avoids the literal text "Add entry" --
  /// see trip_view_screen_test.dart's "no Add entry action" assertion for
  /// fully-future trips, which this text must not accidentally satisfy).
  final bool tripHasStarted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = tripHasStarted
        ? 'No entries yet — tap a day below to start journaling this trip.'
        : "No entries yet — you'll be able to journal once this trip begins.";
    return Container(
      key: const Key('no-entries-yet-hint'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 20,
            color: colorScheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _TapToEditHint extends StatelessWidget {
  const _TapToEditHint({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('tap-to-edit-hint'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: colorScheme.outline),
          const SizedBox(width: 10),
          const Expanded(child: Text('Tip: tap an entry to view or edit it.')),
          IconButton(
            key: const Key('dismiss-tap-to-edit-hint'),
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _NoMatchingEntriesState extends StatelessWidget {
  const _NoMatchingEntriesState({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'No matching entries',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term, mood, or date range.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            key: const Key('clear-journal-filters-button'),
            onPressed: onClearFilters,
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}
