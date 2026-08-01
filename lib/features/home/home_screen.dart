import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../journal/controller/journal_controller.dart';
import '../journal/screens/create_edit_entry_screen.dart';
import '../journal/widgets/format_utils.dart';
import '../journal/widgets/mood_display.dart';
import '../trip/controller/trip_controller.dart';
import '../trip/mock_user.dart';
import '../trip/trip_summary_stats.dart';
import '../trip/trip_form_screen.dart';
import '../trip/trip_list_sort.dart';
import '../trip/trip_view_screen.dart';
import '../trip/widgets/trip_cover_photo.dart';
import '../trip/widgets/trip_list_controls.dart';
import '../trip/widgets/wellness_stats_row.dart';
import '../../models/journal_entry.dart';
import '../../models/trip.dart';

/// The screen shown after login (see IMPLEMENTATION_PLAN_HOMEPAGE.md Phase
/// 4). NOTE: not yet wired as the app's actual home route — that's Phase 7.
/// Settings/Log out remain "coming soon" placeholders (Auth isn't built).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, int> _entryCounts = {};
  TripSortOption _sort = TripSortOption.defaultOrder;
  TripStatusFilter _statusFilter = TripStatusFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboardData());
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    final tripController = ref.read(tripControllerProvider.notifier);
    await tripController.loadTrips(kMockUserId);
    if (!mounted) return;

    final trips = ref.read(tripControllerProvider).trips;
    final counts = <String, int>{};
    for (final trip in trips) {
      counts[trip.id] = await tripController.countEntriesForTrip(trip.id);
    }
    if (!mounted) return;
    setState(() => _entryCounts = counts);

    final activeTrip = ref.read(tripControllerProvider).activeTrip;
    if (activeTrip != null) {
      await ref
          .read(journalControllerProvider.notifier)
          .loadEntries(activeTrip.id);
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is not wired up yet.')));
  }

  void _openTripView(Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripViewScreen(tripId: trip.id)),
    );
  }

  void _openCreateTrip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TripFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripController = ref.watch(tripControllerProvider);
    final journalController = ref.watch(journalControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TripJournal'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) =>
                _showComingSoon(value == 'settings' ? 'Settings' : 'Log out'),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(child: Text(kMockUserDisplayName[0])),
            ),
          ),
        ],
      ),
      body: _buildBody(context, tripController, journalController),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTrip,
        icon: const Icon(Icons.add),
        label: const Text('Create Trip'),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TripController tripController,
    JournalController journalController,
  ) {
    if (tripController.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tripController.error != null) {
      return Center(child: Text('Error: ${tripController.error}'));
    }
    if (tripController.trips.isEmpty) {
      return _buildEmptyState(context);
    }

    final activeTrip = tripController.activeTrip;
    final orderedTrips = sortAndFilterTrips(
      tripController.trips,
      sort: _sort,
      statusFilter: _statusFilter,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activeTrip != null) ...[
          _buildActiveTripCard(context, activeTrip, journalController),
          const SizedBox(height: 24),
        ],
        Text('Your Trips', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        TripListControls(
          sort: _sort,
          statusFilter: _statusFilter,
          onSortChanged: (sort) => setState(() => _sort = sort),
          onStatusFilterChanged: (filter) =>
              setState(() => _statusFilter = filter),
        ),
        const SizedBox(height: 8),
        if (orderedTrips.isEmpty)
          TripListNoMatchesState(
            onClearFilter: () =>
                setState(() => _statusFilter = TripStatusFilter.all),
          )
        else
          for (final trip in orderedTrips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TripCard(
                trip: trip,
                entryCount: _entryCounts[trip.id] ?? 0,
                onTap: () => _openTripView(trip),
              ),
            ),
      ],
    );
  }

  /// The whole card is one tap target → opens the trip. The wellness stats
  /// inside are plain, non-interactive widgets — they were previously their
  /// own separately-tappable card underneath; merging them in here removes
  /// that dead-zone-prone split (decision (b) in
  /// IMPLEMENTATION_PLAN_UX_AI.md §4: tapping anywhere on the card, stats
  /// included, opens the trip). "Write today's entry" stays its own
  /// explicit action — nesting a button inside an InkWell is enough for
  /// Flutter to route a tap on the button to the button alone, without also
  /// firing the card's tap.
  Widget _buildActiveTripCard(
    BuildContext context,
    Trip trip,
    JournalController journalController,
  ) {
    final today = DateTime.now();
    final dayNumber =
        DateTime(today.year, today.month, today.day)
            .difference(
              DateTime(
                trip.startDate.year,
                trip.startDate.month,
                trip.startDate.day,
              ),
            )
            .inDays +
        1;
    final todaysEntry = _findTodaysEntry(journalController.entries);
    final stats = computeTripStats(
      entries: journalController.entries,
      totalDays: trip.durationDays,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('active-trip-card'),
        onTap: () => _openTripView(trip),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TripCoverPhoto(photoPath: trip.coverPhotoPath, height: 140),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('Day $dayNumber of ${trip.durationDays}'),
                  const SizedBox(height: 12),
                  if (todaysEntry == null) ...[
                    const Text("You haven't written today's entry yet."),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const Key('write-today-entry-button'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateEditEntryScreen(
                            tripId: trip.id,
                            initialDate: today,
                            trip: trip,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.edit_note),
                      label: const Text("Write today's entry"),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Today's entry: ${todaysEntry.displayTitle}",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (todaysEntry.healthLog != null) ...[
                          const Icon(Icons.directions_walk, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${formatThousands(todaysEntry.healthLog!.steps)} steps',
                          ),
                          const SizedBox(width: 16),
                        ],
                        Icon(moodIcon(todaysEntry.mood), size: 18),
                        const SizedBox(width: 4),
                        Text(moodLabel(todaysEntry.mood)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  WellnessStatsRow(stats: stats),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.card_travel, size: 64),
            const SizedBox(height: 16),
            Text('No trips yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Start a trip to begin journaling your journey.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openCreateTrip,
              icon: const Icon(Icons.add),
              label: const Text('Create your first trip'),
            ),
          ],
        ),
      ),
    );
  }

  JournalEntry? _findTodaysEntry(List<JournalEntry> entries) {
    final today = DateTime.now();
    for (final entry in entries) {
      if (entry.createdAt.year == today.year &&
          entry.createdAt.month == today.month &&
          entry.createdAt.day == today.day) {
        return entry;
      }
    }
    return null;
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.entryCount,
    required this.onTap,
  });

  final Trip trip;
  final int entryCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TripCoverPhoto(
                photoPath: trip.coverPhotoPath,
                width: 88,
                height: 88,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        trip.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatDate(trip.startDate)} - ${formatDate(trip.endDate)}',
                      ),
                      const SizedBox(height: 4),
                      Text(entryCount == 1 ? '1 entry' : '$entryCount entries'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
