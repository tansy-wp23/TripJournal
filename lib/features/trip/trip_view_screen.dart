import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/current_user_id_provider.dart';
import '../../data/trip_repository_locator.dart';
import '../../models/journal_entry.dart';
import '../../models/trip.dart';
import '../../widgets/app_action_menu.dart';
import '../../widgets/app_content_toolbar.dart';
import '../admin/widgets/report_issue_button.dart';
import '../auth/controller/auth_controller.dart';
import '../journal/controller/journal_controller.dart';
import '../journal/journal_filter.dart';
import '../journal/pdf/journal_pdf_export.dart';
import '../journal/screens/create_edit_entry_screen.dart';
import '../journal/screens/entry_detail_screen.dart';
import '../journal/widgets/format_utils.dart';
import '../journal/widgets/mood_display.dart';
import '../journal/widgets/photo_thumbnail.dart';
import '../settings/settings_providers.dart';
import 'controller/trip_controller.dart';
import 'map/osm_trip_map_surface.dart';
import 'map/trip_map_view.dart';
import 'screens/food_showcase_screen.dart';
import 'screens/trip_photo_slideshow_screen.dart';
import 'screens/trip_wellness_screen.dart';
import 'trip_day_groups.dart';
import 'trip_entry_date_range.dart';
import 'trip_photos.dart';
import 'trip_form_screen.dart';
import 'trip_link.dart';
import 'trip_notes_editor_screen.dart';
import 'trip_summary_stats.dart';
import 'widgets/delete_trip_confirmation_dialog.dart';
import 'widgets/journal_search_bar.dart';
import 'widgets/journal_filter_sheet.dart';
import 'widgets/trip_photo_carousel.dart';
import 'widgets/wellness_stats_row.dart';
import 'ai/trip_summary_locator.dart';

/// The "journey" screen (IMPLEMENTATION_PLAN_HOMEPAGE.md Phase 5) — a
/// vertical day-by-day timeline for one trip, reached from the homepage.
class TripViewScreen extends ConsumerStatefulWidget {
  const TripViewScreen({super.key, required this.tripId, this.userIdProvider});

  final String tripId;
  final CurrentUserIdProvider? userIdProvider;

  @override
  ConsumerState<TripViewScreen> createState() => _TripViewScreenState();
}

class _TripViewScreenState extends ConsumerState<TripViewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedTabIndex = 0;
  bool _searchVisible = false;
  bool _dataLoadInProgress = false;
  bool _identityResolved = false;
  String? _resolvedUserId;
  String? _identityError;
  bool _generatingSummary = false;
  bool _editingSummary = false;
  String? _tripSummary;
  String? _summaryError;
  TextEditingController? _summaryController;

  /// First-use hint dismissal, in-memory only for this screen instance --
  /// reappears next time the trip is opened, which is fine for a low-stakes
  /// discoverability nudge (IMPLEMENTATION_PLAN_EXTRA_FEATURES.md #4).
  bool _tapToEditHintDismissed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabSelection)
      ..dispose();
    _summaryController?.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!mounted || _selectedTabIndex == _tabController.index) return;
    setState(() => _selectedTabIndex = _tabController.index);
  }

  void _showEntriesForLocation() {
    _tabController.animateTo(0);
  }

  Future<void> _loadData() async {
    if (_dataLoadInProgress) return;
    _dataLoadInProgress = true;
    try {
      await _loadDataOnce();
    } finally {
      _dataLoadInProgress = false;
    }
  }

  Future<void> _loadDataOnce() async {
    if (!mounted) return;
    final tripController = ref.read(tripControllerProvider.notifier);
    setState(() {
      _identityResolved = false;
      _resolvedUserId = null;
      _identityError = null;
    });

    String? stableUserId;
    for (var attempt = 0; attempt < 3; attempt++) {
      late final String userId;
      try {
        userId = (widget.userIdProvider ?? currentUserIdProvider)
            .requireUserId();
      } on UnauthenticatedTripUserException catch (e) {
        _showIdentityError(tripController, e.toString());
        return;
      }

      if (tripController.loadedUserId != userId) {
        await tripController.loadTrips(userId);
      }
      if (!mounted) return;

      late final String verifiedUserId;
      try {
        verifiedUserId = (widget.userIdProvider ?? currentUserIdProvider)
            .requireUserId();
      } on UnauthenticatedTripUserException catch (e) {
        _showIdentityError(tripController, e.toString());
        return;
      }
      if (verifiedUserId == userId &&
          tripController.loadedUserId == verifiedUserId) {
        stableUserId = verifiedUserId;
        break;
      }
    }

    if (stableUserId == null) {
      _showIdentityError(
        tripController,
        'Your account changed while this trip was loading. Please try again.',
      );
      return;
    }

    final trip = _findTrip(tripController.trips, stableUserId);
    if (trip == null) {
      setState(() {
        _identityResolved = true;
        _resolvedUserId = stableUserId;
      });
      return;
    }

    await ref
        .read(journalControllerProvider.notifier)
        .loadEntries(widget.tripId);
    if (!mounted) return;
    setState(() {
      _identityResolved = true;
      _resolvedUserId = stableUserId;
    });
  }

  void _showIdentityError(TripController controller, String message) {
    controller.clearLoadedTrips();
    if (!mounted) return;
    setState(() {
      _identityResolved = true;
      _resolvedUserId = null;
      _identityError = message;
    });
  }

  Trip? _findTrip(List<Trip> trips, String? userId) {
    if (userId == null) return null;
    for (final trip in trips) {
      if (trip.id == widget.tripId && trip.userId == userId) return trip;
    }
    return null;
  }

  Future<void> _confirmAndDeleteTrip(Trip trip) async {
    final tripController = ref.read(tripControllerProvider.notifier);
    final confirmed = await showDeleteTripConfirmationDialog(
      context,
      tripTitle: trip.title,
    );
    if (!confirmed || !mounted) return;

    final error = await tripController.moveToTrash(trip.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context, true);
  }

  Future<void> _publishTrip(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publish to Community?'),
        content: const Text(
          'This trip will be visible to all TripJournal users, '
          'including your journal entries, health data, and photos. '
          'You can unpublish it at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final profile = ref.read(authControllerProvider).profile;
    final error = await ref
        .read(tripControllerProvider.notifier)
        .publishTrip(
          trip,
          publisherDisplayName: profile?.displayName ?? 'Unknown',
          publisherAvatarUrl: profile?.avatarUrl,
        );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip published to Community!')),
      );
    }
  }

  Future<void> _unpublishTrip(Trip trip) async {
    final error = await ref
        .read(tripControllerProvider.notifier)
        .unpublishTrip(trip);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip unpublished.')));
    }
  }

  void _shareTripLink(Trip trip) {
    final shareText =
        'Check out my trip "${trip.title}" on TripJournal!\n\n'
        'Open this link on a phone with TripJournal installed (paste into '
        "your browser's address bar if it doesn't open automatically):\n"
        '${tripLinkFor(trip.id)}';
    Share.share(shareText, subject: 'TripJournal: ${trip.title}');
  }

  Future<void> _openEditTrip(Trip trip) async {
    final movedToTrash = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TripFormScreen(
          existingTrip: trip,
          userIdProvider: widget.userIdProvider,
        ),
      ),
    );
    if (movedToTrash == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _exportTripPdf(Trip trip, List<JournalEntry> entries) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await buildTripPdf(trip, entries);
      if (mounted) Navigator.pop(context); // close the loading dialog
      await Printing.sharePdf(
        bytes: bytes,
        filename: pdfFileNameFor(trip.title),
      );
    } catch (_) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export this trip as a PDF.')),
        );
      }
    }
  }

  Future<void> _generateTripSummary(
    Trip trip,
    List<JournalEntry> entries,
  ) async {
    if (entries.isEmpty) return;
    setState(() {
      _generatingSummary = true;
      _summaryError = null;
    });
    try {
      final summary = await loggedTripSummaryService.summaryFor(
        trip: trip,
        entries: entries,
      );
      if (!mounted) return;
      final error = await ref
          .read(tripControllerProvider.notifier)
          .editTrip(trip.copyWith(summary: summary, updatedAt: DateTime.now()));
      if (!mounted) return;
      if (error != null) {
        setState(() => _summaryError = error);
        return;
      }
      setState(() => _tripSummary = summary);
    } catch (_) {
      if (!mounted) return;
      setState(() => _summaryError = 'Could not generate the trip summary.');
    } finally {
      if (mounted) setState(() => _generatingSummary = false);
    }
  }

  Future<void> _openEntryFilters(JournalFilter filter) async {
    final selected = await showModalBottomSheet<JournalFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => JournalFilterSheet(initialFilter: filter),
    );
    if (selected != null && mounted) {
      ref.read(journalControllerProvider.notifier).setFilter(selected);
    }
  }

  void _startEditingSummary(String summary) {
    _summaryController?.dispose();
    setState(() {
      _summaryController = TextEditingController(text: summary);
      _editingSummary = true;
      _summaryError = null;
    });
  }

  void _cancelEditingSummary() {
    _summaryController?.dispose();
    setState(() {
      _summaryController = null;
      _editingSummary = false;
    });
  }

  Future<void> _saveEditedSummary(Trip trip) async {
    final summary = _summaryController?.text.trim() ?? '';
    if (summary.isEmpty) {
      setState(() => _summaryError = 'Trip summary cannot be empty.');
      return;
    }

    final updatedTrip = trip.copyWith(
      summary: summary,
      updatedAt: DateTime.now(),
    );
    final error = await ref
        .read(tripControllerProvider.notifier)
        .editTrip(updatedTrip);
    if (!mounted) return;
    if (error != null) {
      setState(() => _summaryError = error);
      return;
    }

    _summaryController?.dispose();
    setState(() {
      _summaryController = null;
      _tripSummary = summary;
      _editingSummary = false;
      _summaryError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripController = ref.watch(tripControllerProvider);
    final journalController = ref.watch(journalControllerProvider);

    if (!_identityResolved) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_identityError != null) {
      return Scaffold(body: Center(child: Text(_identityError!)));
    }

    final trip = _findTrip(tripController.trips, _resolvedUserId);

    if (trip == null) {
      return const Scaffold(body: Center(child: Text('Trip not found.')));
    }

    final tripEntries = entriesWithinTrip(trip, journalController.entries);
    final stats = computeTripStats(
      entries: tripEntries,
      totalDays: trip.durationDays,
    );
    final dayGroups = buildDayGroups(trip, tripEntries);

    // Deliberately built from the UNFILTERED entries, and built once here so
    // the header and every day tile share one list. A day tile that derived
    // its own photos from the filtered groups would produce indices that don't
    // line up with the slideshow's, opening the wrong photo whenever a filter
    // is active. It is also what makes "entering a day shows the whole trip"
    // work: the day strip is a view onto this list, not a list of its own.
    final tripPhotos = buildTripPhotos(trip, tripEntries);

    final filter = journalController.filter;
    final filteredTripEntries = filterJournalEntries(tripEntries, filter);
    final displayDayGroups = filter.isActive
        ? buildDayGroups(
            trip,
            filteredTripEntries,
          ).where((g) => !g.isEmpty).toList()
        : dayGroups;
    final activeFilterCount =
        (filter.mood == null ? 0 : 1) +
        (filter.startDate == null && filter.endDate == null ? 0 : 1);

    // Built once and placed as the entries list's own first item(s) below,
    // rather than pinned above it in a Column+Expanded — that older
    // structure kept this fixed on screen while only the list beneath it
    // scrolled. As a list item it scrolls away with everything else.
    final toolbarSection = Column(
      // Stretch, not the Column default (center) — center gives the Padding
      // below loose width constraints, so the Card inside AppContentToolbar
      // shrink-wraps to its buttons' width instead of spanning the same
      // width as the header/stats cards beneath it.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: AppContentToolbar(
            resultLabel:
                '${filteredTripEntries.length} ${filteredTripEntries.length == 1 ? 'entry' : 'entries'}',
            activeFilterLabel: activeFilterCount == 0
                ? null
                : '$activeFilterCount ${activeFilterCount == 1 ? 'filter' : 'filters'} active',
            children: [
              OutlinedButton.icon(
                key: const Key('trip-view-search-toggle'),
                icon: Icon(
                  _searchVisible
                      ? Icons.search_off_rounded
                      : Icons.search_rounded,
                ),
                label: Text(_searchVisible ? 'Close search' : 'Search'),
                onPressed: () {
                  setState(() => _searchVisible = !_searchVisible);
                  if (!_searchVisible) {
                    ref
                        .read(journalControllerProvider.notifier)
                        .setFilter(filter.copyWith(query: ''));
                  }
                },
              ),
              OutlinedButton.icon(
                key: const Key('trip-view-filter-button'),
                onPressed: () => _openEntryFilters(filter),
                icon: Badge(
                  key: Key('journal-filter-count-$activeFilterCount'),
                  isLabelVisible: activeFilterCount > 0,
                  label: Text('$activeFilterCount'),
                  child: const Icon(Icons.filter_alt_outlined),
                ),
                label: const Text('Filters'),
              ),
            ],
          ),
        ),
        if (_searchVisible)
          JournalSearchBar(
            filter: filter,
            onChanged: (f) =>
                ref.read(journalControllerProvider.notifier).setFilter(f),
          ),
        // The toolbar's own Padding only insets left/right/top (see above) —
        // without this the cover photo carousel right below it in the list
        // butts straight up against it with no gap.
        const SizedBox(height: 12),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  key: Key('trip-view-entries-tab'),
                  text: 'Entries',
                  height: 44,
                ),
                Tab(key: Key('trip-view-map-tab'), text: 'Map', height: 44),
              ],
            ),
          ),
        ),
        actions: [
          AppActionMenu<_TripViewMenuAction>(
            key: const Key('trip-view-more-menu'),
            tooltip: 'More trip actions',
            onSelected: (action) {
              switch (action) {
                case _TripViewMenuAction.edit:
                  _openEditTrip(trip);
                case _TripViewMenuAction.exportPdf:
                  _exportTripPdf(trip, tripEntries);
                case _TripViewMenuAction.foodShowcase:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FoodShowcaseScreen(
                        photos: tripPhotos
                            .where((photo) => photo.kind == TripPhotoKind.meal)
                            .toList(),
                      ),
                    ),
                  );
                case _TripViewMenuAction.publish:
                  _publishTrip(trip);
                case _TripViewMenuAction.unpublish:
                  _unpublishTrip(trip);
                case _TripViewMenuAction.shareLink:
                  _shareTripLink(trip);
                case _TripViewMenuAction.reportIssue:
                  showReportIssueSheet(
                    context,
                    page: 'TripViewScreen',
                    userIdProvider: widget.userIdProvider,
                  );
                case _TripViewMenuAction.moveToTrash:
                  _confirmAndDeleteTrip(trip);
              }
            },
            items: [
              const AppActionMenuItem(
                key: Key('trip-view-edit-button'),
                value: _TripViewMenuAction.edit,
                label: 'Edit trip',
                icon: Icons.edit_outlined,
              ),
              if (trip.isPublic) ...[
                const AppActionMenuItem(
                  key: Key('trip-view-unpublish-button'),
                  value: _TripViewMenuAction.unpublish,
                  label: 'Unpublish',
                  icon: Icons.public_off_outlined,
                ),
                const AppActionMenuItem(
                  key: Key('trip-view-share-link-button'),
                  value: _TripViewMenuAction.shareLink,
                  label: 'Share link',
                  icon: Icons.share_outlined,
                ),
              ] else
                const AppActionMenuItem(
                  key: Key('trip-view-publish-button'),
                  value: _TripViewMenuAction.publish,
                  label: 'Publish to Community',
                  icon: Icons.public_outlined,
                ),
              const AppActionMenuItem(
                key: Key('trip-view-export-pdf-button'),
                value: _TripViewMenuAction.exportPdf,
                label: 'Export trip as PDF',
                icon: Icons.picture_as_pdf_outlined,
              ),
              const AppActionMenuItem(
                key: Key('trip-view-food-showcase-button'),
                value: _TripViewMenuAction.foodShowcase,
                label: 'Food showcase',
                icon: Icons.restaurant_outlined,
              ),
              const AppActionMenuItem(
                key: Key('report-issue-button'),
                value: _TripViewMenuAction.reportIssue,
                label: 'Report an issue',
                icon: Icons.report_problem_outlined,
                startsSection: true,
              ),
              const AppActionMenuItem(
                key: Key('trip-view-delete-button'),
                value: _TripViewMenuAction.moveToTrash,
                label: 'Move to Trash',
                icon: Icons.delete_outline,
                destructive: true,
                startsSection: true,
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          filter.isActive && displayDayGroups.isEmpty
              ? ListView(
                  key: const PageStorageKey<String>('trip-view-entries-list'),
                  children: [
                    toolbarSection,
                    _buildHeader(context, trip, stats, tripEntries, tripPhotos),
                    _NoMatchingEntriesState(
                      onClearFilters: () => ref
                          .read(journalControllerProvider.notifier)
                          .clearFilter(),
                    ),
                  ],
                )
              : ListView.builder(
                  key: const PageStorageKey<String>('trip-view-entries-list'),
                  itemCount: displayDayGroups.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) return toolbarSection;
                    if (index == 1) {
                      return _buildHeader(
                        context,
                        trip,
                        stats,
                        tripEntries,
                        tripPhotos,
                      );
                    }
                    return _DayGroupTile(
                      trip: trip,
                      group: displayDayGroups[index - 2],
                      tripPhotos: tripPhotos,
                    );
                  },
                ),
          TripMapView(
            entries: tripEntries,
            tripStartDate: trip.startDate,
            tripEndDate: trip.endDate,
            mapBuilder: buildConfiguredTripMapSurface,
            onOpenEntry: (entry) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EntryDetailScreen(entryId: entry.id),
              ),
            ),
            onAddLocation: _showEntriesForLocation,
          ),
        ],
      ),
    );
  }

  /// Opens the slideshow on [photo], resolving its position in the full list
  /// by identity rather than by the position it occupied in whatever subset
  /// the caller was showing.
  void _openSlideshow(
    BuildContext context,
    List<TripPhoto> photos,
    TripPhoto photo,
  ) {
    final index = photos.indexWhere((candidate) => identical(candidate, photo));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripPhotoSlideshowScreen(
          photos: photos,
          initialIndex: index == -1 ? 0 : index,
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Trip trip,
    TripStats stats,
    List<JournalEntry> entries,
    List<TripPhoto> tripPhotos,
  ) {
    final notes = trip.notes;

    final showFoodPhotos = ref
        .watch(settingsControllerProvider)
        .preferences
        .showFoodPhotosInCarousel;
    final hasFoodPhotos = tripPhotos.any((p) => p.kind == TripPhotoKind.meal);
    // The carousel may show a subset; the slideshow is always opened over the
    // full list, which is why the tap hands back the photo rather than a page
    // number.
    final carouselPhotos = showFoodPhotos
        ? tripPhotos
        : tripPhotos.where((p) => p.kind != TripPhotoKind.meal).toList();
    final summary = _tripSummary ?? trip.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TripPhotoCarousel(
          photos: carouselPhotos,
          coverPhotoPath: trip.coverPhotoPath,
          height: 160,
          onPhotoTap: (photo) => _openSlideshow(context, tripPhotos, photo),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    trip.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (trip.isPublic)
                    Chip(
                      key: const Key('trip-view-public-chip'),
                      avatar: const Icon(Icons.public, size: 14),
                      label: const Text('Public'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                key: const Key('trip-header-facts'),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      if (trip.destination?.trim().isNotEmpty == true) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                trip.destination!.trim(),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${formatDate(trip.startDate)} – ${formatDate(trip.endDate)}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${trip.durationDays} days',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Hidden when there is nothing to toggle — a switch that can't
              // change anything is just noise.
              if (hasFoodPhotos) ...[
                const SizedBox(height: 8),
                FilterChip(
                  key: const Key('trip-food-photos-toggle'),
                  avatar: const Icon(Icons.restaurant, size: 18),
                  label: Text(
                    showFoodPhotos ? 'Food photos shown' : 'Food photos hidden',
                  ),
                  selected: showFoodPhotos,
                  onSelected: (selected) => ref
                      .read(settingsControllerProvider.notifier)
                      .setShowFoodPhotosInCarousel(selected),
                ),
              ],
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('trip-wellness-link'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TripWellnessScreen(trip: trip, entries: entries),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: WellnessStatsRow(stats: stats)),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ],
                    ),
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
              _TripSummaryCard(
                hasEntries: entries.isNotEmpty,
                isGenerating: _generatingSummary,
                summary: summary,
                error: _summaryError,
                isEditing: _editingSummary,
                summaryController: _summaryController,
                onGenerate: () => _generateTripSummary(trip, entries),
                onEdit: summary == null
                    ? null
                    : () => _startEditingSummary(summary),
                onSaveEdit: () => _saveEditedSummary(trip),
                onCancelEdit: _cancelEditingSummary,
              ),
              const SizedBox(height: 16),
              Card(
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
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
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
  const _DayGroupTile({
    required this.trip,
    required this.group,
    required this.tripPhotos,
  });

  final Trip trip;
  final DayGroup group;

  /// Every photo in the trip, not just this day's. The strip below filters it
  /// down for display, but the slideshow is opened over the whole list so the
  /// user can keep swiping into the neighbouring days.
  final List<TripPhoto> tripPhotos;

  void _openSlideshow(BuildContext context, TripPhoto photo) {
    final index = tripPhotos.indexWhere(
      (candidate) => identical(candidate, photo),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripPhotoSlideshowScreen(
          photos: tripPhotos,
          initialIndex: index == -1 ? 0 : index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayPhotos = tripPhotos
        .where((photo) => photo.dayNumber == group.dayNumber)
        .toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = group.date.isAtSameMomentAs(today);
    final isFuture = group.date.isAfter(today);
    final isWritable = !isFuture;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: Key('day-group-${group.dayNumber}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isToday ? colorScheme.primary : colorScheme.outlineVariant,
          width: isToday ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            label:
                'Day ${group.dayNumber}, ${formatWeekday(group.date)}, ${formatDate(group.date)}',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday
                          ? colorScheme.primary
                          : colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${group.dayNumber}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isToday
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Day ${group.dayNumber}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatWeekday(group.date)} · ${formatDate(group.date)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (isToday || isFuture)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isToday
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant)
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isToday ? 'Today' : 'Upcoming',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isToday
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Omitted entirely rather than reserved as empty space, so days
          // without photos keep exactly the height they had before.
          if (dayPhotos.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: ListView.separated(
                key: Key('day-photo-strip-${group.dayNumber}'),
                scrollDirection: Axis.horizontal,
                itemCount: dayPhotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => PhotoThumbnail(
                  key: Key('day-photo-${group.dayNumber}-$index'),
                  photoPath: dayPhotos[index].path,
                  size: 64,
                  onTap: () => _openSlideshow(context, dayPhotos[index]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (isFuture)
            Text(
              'Entries open when this travel day arrives.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            )
          else if (group.isEmpty)
            Text(
              'No entry logged',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
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
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
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
    final locationLabel = entry.location?.locationTag;

    return Semantics(
      container: true,
      button: true,
      label:
          'Open entry ${entry.displayTitle}. $quickStats${locationLabel == null ? '' : '. $locationLabel'}',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('entry-tile-${entry.id}'),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        moodIcon(entry.mood),
                        size: 20,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            quickStats,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          if (locationLabel case final tag?)
                            Text(
                              tag,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.primary),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({
    required this.hasEntries,
    required this.isGenerating,
    required this.summary,
    required this.error,
    required this.isEditing,
    required this.summaryController,
    required this.onGenerate,
    required this.onEdit,
    required this.onSaveEdit,
    required this.onCancelEdit,
  });

  final bool hasEntries;
  final bool isGenerating;
  final String? summary;
  final String? error;
  final bool isEditing;
  final TextEditingController? summaryController;
  final VoidCallback onGenerate;
  final VoidCallback? onEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('trip-summary-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Trip Summary',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!hasEntries)
              Text(
                'Add a journal entry to generate a summary of this trip.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else if (isGenerating)
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Generating your trip summary...'),
                ],
              )
            else ...[
              if (summary != null && !isEditing)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(summary!)),
                    IconButton(
                      key: const Key('edit-trip-summary-button'),
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit summary',
                      onPressed: onEdit,
                    ),
                  ],
                ),
              if (isEditing)
                TextField(
                  key: const Key('trip-summary-editor-field'),
                  controller: summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Trip Summary',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  minLines: 4,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    error!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              const SizedBox(height: 4),
              if (isEditing)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const Key('cancel-edit-trip-summary-button'),
                      onPressed: onCancelEdit,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('save-trip-summary-button'),
                      onPressed: onSaveEdit,
                      child: const Text('Save'),
                    ),
                  ],
                )
              else
                TextButton.icon(
                  key: const Key('generate-trip-summary-button'),
                  onPressed: onGenerate,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    summary == null ? 'Generate summary' : 'Regenerate summary',
                  ),
                ),
            ],
          ],
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

enum _TripViewMenuAction {
  edit,
  exportPdf,
  foodShowcase,
  publish,
  unpublish,
  shareLink,
  reportIssue,
  moveToTrash,
}
