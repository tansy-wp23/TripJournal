import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/current_user_id_provider.dart';
import '../../data/trip_repository_locator.dart';
import '../admin/widgets/report_issue_button.dart';
import '../auth/controller/auth_controller.dart';
import '../community/community_screen.dart';
import '../profile/screens/profile_view_screen.dart';
import '../profile/widgets/profile_avatar.dart';
import '../settings/settings_providers.dart';
import '../settings/settings_screen.dart';
import '../journal/controller/journal_controller.dart';
import '../journal/screens/create_edit_entry_screen.dart';
import '../journal/widgets/format_utils.dart';
import '../journal/widgets/mood_display.dart';
import '../trip/controller/trip_controller.dart';
import '../trip/screens/trip_trash_screen.dart';
import '../trip/trip_summary_stats.dart';
import '../trip/trip_form_screen.dart';
import '../trip/trip_list_sort.dart';
import '../trip/trip_view_screen.dart';
import '../trip/widgets/trip_cover_photo.dart';
import '../trip/widgets/trip_photo_carousel.dart';
import '../trip/widgets/trip_list_controls.dart';
import '../trip/widgets/wellness_stats_row.dart';
import '../../models/journal_entry.dart';
import '../../models/profile.dart';
import '../../models/trip.dart';
import '../../theme/aurora_theme.dart';
import '../../widgets/aurora_panel.dart';

/// The screen shown after login (see IMPLEMENTATION_PLAN_HOMEPAGE.md Phase
/// 4), reached via `AuthGate` once `authControllerProvider.status` is
/// `authenticated`. Log out calls `AuthController.signOut()` directly —
/// `AuthGate` reacts to the resulting `signedOut` status and swaps back to
/// `LoginScreen` on its own, so no navigation happens here. Settings remains
/// a "coming soon" placeholder.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.userIdProvider,
    this.embeddedInRootShell = false,
  });

  final CurrentUserIdProvider? userIdProvider;
  final bool embeddedInRootShell;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, int> _entryCounts = {};
  TripSortOption _sort = TripSortOption.defaultOrder;
  TripStatusFilter _statusFilter = TripStatusFilter.all;
  bool _tripSearchVisible = false;
  String _tripQuery = '';
  String? _identityError;
  bool _dashboardLoadInProgress = false;
  bool _dashboardReloadRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboardData());
  }

  Future<void> _loadDashboardData() async {
    if (_dashboardLoadInProgress) {
      _dashboardReloadRequested = true;
      return;
    }

    _dashboardLoadInProgress = true;
    try {
      do {
        _dashboardReloadRequested = false;
        await _loadDashboardOnce();
      } while (mounted && _dashboardReloadRequested);
    } finally {
      _dashboardLoadInProgress = false;
    }
  }

  Future<void> _loadDashboardOnce() async {
    if (!mounted) return;
    late final String userId;
    try {
      userId = (widget.userIdProvider ?? currentUserIdProvider).requireUserId();
    } on UnauthenticatedTripUserException catch (e) {
      if (!mounted) return;
      ref.read(tripControllerProvider.notifier).clearLoadedTrips();
      setState(() {
        _identityError = e.toString();
        _entryCounts = {};
      });
      return;
    }

    final tripController = ref.read(tripControllerProvider.notifier);
    await tripController.loadTrips(userId);
    if (!mounted) return;

    final trips = ref.read(tripControllerProvider).trips;
    final counts = <String, int>{};
    for (final trip in trips) {
      counts[trip.id] = await tripController.countEntriesForTrip(trip.id);
      if (!mounted) return;
    }
    setState(() {
      _identityError = null;
      _entryCounts = counts;
    });

    final activeTrip = ref.read(tripControllerProvider).activeTrip;
    if (activeTrip != null) {
      await ref
          .read(journalControllerProvider.notifier)
          .loadEntries(activeTrip.id);
    }
    unawaited(ref.read(journalReminderCoordinatorProvider).reconcile(trips));
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is not wired up yet.')));
  }

  Future<void> _openTripView(Trip trip) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TripViewScreen(
          tripId: trip.id,
          userIdProvider: widget.userIdProvider,
        ),
      ),
    );
    if (!mounted) return;
    await _loadDashboardData();
  }

  Future<void> _openCreateTrip() async {
    final movedToTrash = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TripFormScreen(userIdProvider: widget.userIdProvider),
      ),
    );
    if (movedToTrash == true) {
      await _loadDashboardData();
    }
  }

  Future<void> _onProfileMenuSelected(String value) async {
    if (value == 'recently-deleted') {
      final restored = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const TripTrashScreen()),
      );
      if (restored == true) await _loadDashboardData();
      return;
    }
    if (value == 'profile') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileViewScreen()),
      );
      return;
    }
    if (value == 'logout') {
      await ref.read(authControllerProvider.notifier).signOut();
      // AuthGate watches authControllerProvider and swaps to LoginScreen
      // once status flips to signedOut — no navigation needed here.
      return;
    }
    if (value == 'settings') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      return;
    }
    _showComingSoon(value);
  }

  @override
  Widget build(BuildContext context) {
    final tripController = ref.watch(tripControllerProvider);
    final journalController = ref.watch(journalControllerProvider);
    // AuthController already caches the Profile (populated at sign-in /
    // session restore), and ProfileController.refreshProfile() is called by
    // every profile write, so this stays fresh after avatar/name edits —
    // no extra fetch needed here. See the note in
    // profile_controller.dart's updateDisplayName().
    final authController = ref.watch(authControllerProvider);
    ref.listen(tripControllerProvider, (_, next) {
      unawaited(
        ref.read(journalReminderCoordinatorProvider).reconcile(next.trips),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.embeddedInRootShell ? 'My journeys' : 'TripJournal'),
        actions: [
          if (!widget.embeddedInRootShell)
            IconButton(
              key: const Key('community-button'),
              icon: const Icon(Icons.public),
              tooltip: 'Community',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CommunityScreen()),
              ),
            ),
          ReportIssueButton(
            page: 'HomeScreen',
            userIdProvider: widget.userIdProvider,
          ),
          PopupMenuButton<String>(
            onSelected: _onProfileMenuSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'recently-deleted',
                child: Text('Recently Deleted'),
              ),
              PopupMenuItem(value: 'profile', child: Text('Profile')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildProfileMenuAvatar(context, authController.profile),
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

  /// The profile button in the app bar: the user's actual picture once
  /// their profile is cached by [AuthController] (falling back to their
  /// initial when no photo is set or the image fails to load), or a generic
  /// person icon while no profile is available. A missing profile must
  /// never break the dashboard — the profile screens own any load-error UI.
  Widget _buildProfileMenuAvatar(BuildContext context, Profile? profile) {
    if (profile == null) {
      return const CircleAvatar(child: Icon(Icons.person));
    }
    return ProfileAvatar(
      radius: 20,
      avatarUrl: profile.avatarUrl,
      initial: profile.displayName.isNotEmpty
          ? profile.displayName[0].toUpperCase()
          : '?',
      initialStyle: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _buildBody(
    BuildContext context,
    TripController tripController,
    JournalController journalController,
  ) {
    if (_identityError != null) {
      return Center(child: Text(_identityError!));
    }
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
      query: _tripQuery,
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
          searchVisible: _tripSearchVisible,
          onSearchToggle: () => setState(() {
            _tripSearchVisible = !_tripSearchVisible;
            if (!_tripSearchVisible) _tripQuery = '';
          }),
        ),
        if (_tripSearchVisible) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('trip-search-field'),
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search trips by title or destination...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _tripQuery = value),
          ),
        ],
        const SizedBox(height: 8),
        if (orderedTrips.isEmpty)
          TripListNoMatchesState(
            onClearFilter: () => setState(() {
              _statusFilter = TripStatusFilter.all;
              _tripQuery = '';
              _tripSearchVisible = false;
            }),
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
    final currentDay = dayNumber.clamp(1, trip.durationDays);
    final todaysEntry = _findTodaysEntry(journalController.entries);
    final stats = computeTripStats(
      entries: journalController.entries,
      totalDays: trip.durationDays,
    );
    final theme = Theme.of(context);
    final aurora = AuroraTheme.of(context);

    return AuroraPanel(
      key: const Key('active-trip-card'),
      semanticLabel: 'Open active trip ${trip.title}',
      padding: EdgeInsets.zero,
      onTap: () => _openTripView(trip),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TripCoverPhoto(
            photoPath: trip.coverPhotoPath,
            height: TripPhotoCarousel.resolveHeight(context, max: 152),
            width: double.infinity,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: aurora.onHero.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: aurora.onHero.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Text(
                          'ACTIVE TRIP',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: aurora.onHero,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Day $currentDay of ${trip.durationDays}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: aurora.onHero,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  trip.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: aurora.onHero,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (trip.destination?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trip.destination!.trim(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: aurora.onHero.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: currentDay / trip.durationDays,
                    backgroundColor: aurora.onHero.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(aurora.onHero),
                  ),
                ),
                const SizedBox(height: 18),
                if (todaysEntry == null) ...[
                  Text(
                    "You haven't written today's entry yet.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: aurora.onHero.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const Key('write-today-entry-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.tertiary,
                      foregroundColor: theme.colorScheme.onTertiary,
                    ),
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
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text("Write today's entry"),
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Today's entry: ${todaysEntry.displayTitle}",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: aurora.onHero,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
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
                const SizedBox(height: 20),
                WellnessStatsRow(
                  stats: stats,
                  compact: true,
                  foregroundColor: aurora.onHero,
                ),
              ],
            ),
          ),
        ],
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
