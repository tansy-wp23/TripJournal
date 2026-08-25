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
  const CommunityScreen({super.key});

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
          content: Text('Trip not found. It may not be public or may not exist.'),
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
      return Center(child: Text('Error: ${controller.error}'));
    }
    if (controller.trips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public, size: 64),
              const SizedBox(height: 16),
              Text(
                'No trips published yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Be the first to share a trip with the community!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
        padding: const EdgeInsets.all(16),
        children: [
          if (_destinationSearchVisible) ...[
            TextField(
              key: const Key('community-destination-search-field'),
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search by destination...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _destinationQuery = value),
            ),
            const SizedBox(height: 8),
          ],
          if (filteredTrips.isEmpty)
            TripListNoMatchesState(
              onClearFilter: () => setState(() => _destinationQuery = ''),
            )
          else
            for (final trip in filteredTrips)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PublicTripCard(
                  trip: trip,
                  onTap: () => _openPublicTrip(trip),
                ),
              ),
        ],
      ),
    );
  }
}
