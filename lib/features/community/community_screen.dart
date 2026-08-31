import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/trip.dart';
import '../trip/widgets/trip_list_controls.dart';
import 'controller/community_controller.dart';
import 'public_trip_search.dart';
import 'public_trip_view_screen.dart';
import 'widgets/public_trip_card.dart';

/// The community feed — public trips from all users.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, this.onSignIn});

  /// Non-null only when [GuestHomeScreen] embeds this screen for an
  /// unauthenticated visitor (Guest Mode plan) — shows a "Sign in" AppBar
  /// action and a guest-specific empty state. Null (the default, used by the
  /// signed-in Home screen's Community entry point) leaves both unchanged.
  final VoidCallback? onSignIn;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  bool _destinationSearchVisible = false;
  String _destinationQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(communityControllerProvider.notifier).loadPublicTrips();
    });
  }

  Future<void> _openPublicTrip(Trip trip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicTripViewScreen(trip: trip)),
    );
    if (!mounted) return;
    // Reload in case the user unpublished their own trip from there
    ref.read(communityControllerProvider.notifier).loadPublicTrips();
  }

  Future<void> _searchByTripId() async {
    final tripId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Open Trip by ID'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Paste the trip ID here',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Open'),
            ),
          ],
        );
      },
    );
    if (tripId == null || tripId.isEmpty || !mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Looking up trip…')));

    final trip = await ref
        .read(communityControllerProvider.notifier)
        .fetchPublicTrip(tripId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (trip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Trip not found. It may not be public or may not exist.',
          ),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicTripViewScreen(trip: trip)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(communityControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          if (widget.onSignIn != null)
            TextButton.icon(
              key: const Key('guest-sign-in-button'),
              onPressed: widget.onSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Sign in'),
            ),
          IconButton(
            key: const Key('community-destination-search-toggle'),
            icon: Icon(
              _destinationSearchVisible ? Icons.search_off : Icons.search,
            ),
            tooltip: 'Filter by destination',
            onPressed: () => setState(() {
              _destinationSearchVisible = !_destinationSearchVisible;
              if (!_destinationSearchVisible) _destinationQuery = '';
            }),
          ),
          IconButton(
            key: const Key('community-search-by-id'),
            icon: const Icon(Icons.travel_explore),
            tooltip: 'Open trip by ID',
            onPressed: _searchByTripId,
          ),
        ],
      ),
      body: _buildBody(context, controller),
    );
  }

  Widget _buildBody(BuildContext context, CommunityController controller) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null) {
      return _CommunityMessageState(
        icon: Icons.cloud_off_outlined,
        title: 'Couldn’t load journeys',
        message: '${controller.error}',
        action: FilledButton.icon(
          onPressed: () =>
              ref.read(communityControllerProvider.notifier).loadPublicTrips(),
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }
    if (controller.trips.isEmpty) {
      return _CommunityMessageState(
        icon: Icons.travel_explore_outlined,
        title: 'No trips published yet',
        message: widget.onSignIn != null
            ? 'Sign in to create and share your own trips!'
            : 'Be the first to share a trip with the community!',
        action: widget.onSignIn == null
            ? null
            : FilledButton.icon(
                key: const Key('guest-empty-state-sign-in-button'),
                onPressed: widget.onSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
              ),
      );
    }

    final filteredTrips = filterPublicTripsByDestination(
      controller.trips,
      _destinationQuery,
    );

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(communityControllerProvider.notifier).loadPublicTrips(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _DiscoveryHeader(),
                  if (_destinationSearchVisible) ...[
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('community-destination-search-field'),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        hintText: 'Search city, region, or country',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) =>
                          setState(() => _destinationQuery = value),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (filteredTrips.isEmpty)
                    TripListNoMatchesState(
                      onClearFilter: () =>
                          setState(() => _destinationQuery = ''),
                    )
                  else
                    for (final trip in filteredTrips)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PublicTripCard(
                          trip: trip,
                          onTap: () => _openPublicTrip(trip),
                        ),
                      ),
                  if (widget.onSignIn != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('guest-create-first-trip-button'),
                      onPressed: widget.onSignIn,
                      icon: const Icon(Icons.add),
                      label: const Text('Create your first trip'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.public, color: colors.onPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover journeys',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Stories shared by fellow travellers.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityMessageState extends StatelessWidget {
  const _CommunityMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: colors.primary),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  if (action case final action?) ...[
                    const SizedBox(height: 20),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
