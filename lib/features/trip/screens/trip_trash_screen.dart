import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/trip.dart';
import '../../journal/widgets/format_utils.dart';
import '../controller/trip_trash_controller.dart';
import '../trip_form_screen.dart';

class TripTrashScreen extends ConsumerStatefulWidget {
  const TripTrashScreen({super.key});

  @override
  ConsumerState<TripTrashScreen> createState() => _TripTrashScreenState();
}

class _TripTrashScreenState extends ConsumerState<TripTrashScreen> {
  TripTrashController? _listenedController;
  Timer? _expiryTimer;
  DateTime? _scheduledExpiry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(tripTrashControllerProvider.notifier);
      _listenedController = controller;
      controller.addListener(_scheduleNextExpiry);
      controller.load();
    });
  }

  void _scheduleNextExpiry() {
    if (!mounted) return;
    final controller = _listenedController;
    if (controller == null) return;

    final now = controller.now;
    DateTime? nextExpiry;
    for (final trip in controller.trips) {
      final expiry = trip.trashExpiresAt;
      if (expiry == null || !expiry.isAfter(now)) continue;
      if (nextExpiry == null || expiry.isBefore(nextExpiry)) {
        nextExpiry = expiry;
      }
    }

    if (nextExpiry == null) {
      _expiryTimer?.cancel();
      _expiryTimer = null;
      _scheduledExpiry = null;
      return;
    }
    if (_scheduledExpiry == nextExpiry && _expiryTimer?.isActive == true) {
      return;
    }

    _expiryTimer?.cancel();
    _scheduledExpiry = nextExpiry;
    _expiryTimer = Timer(nextExpiry.difference(now), _handleExpiry);
  }

  void _handleExpiry() {
    _expiryTimer = null;
    _scheduledExpiry = null;
    if (!mounted) return;
    setState(() {});
    _scheduleNextExpiry();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _listenedController?.removeListener(_scheduleNextExpiry);
    super.dispose();
  }

  Future<void> _confirmRestore(Trip trip) async {
    final controller = ref.read(tripTrashControllerProvider.notifier);
    if (controller.isRestoring(trip.id)) {
      return;
    }
    if (!trip.isRecoverableAt(controller.now)) {
      setState(() {});
      _scheduleNextExpiry();
      _showMessage('This trip\'s recovery period has expired.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Restore "${trip.title}"?'),
        content: const Text(
          'Restore this trip and all of its journal entries?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-restore-trip-button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await controller.restore(trip);
    if (!mounted) return;
    switch (result.status) {
      case TripRestoreStatus.restored:
        Navigator.pop(context, true);
      case TripRestoreStatus.conflict:
        final restored = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TripFormScreen(existingTrip: trip, restoreOnSave: true),
          ),
        );
        if (restored == true && mounted) Navigator.pop(context, true);
      case TripRestoreStatus.expired:
        await controller.load();
        if (mounted) _showMessage(result.message);
      case TripRestoreStatus.failed:
        _showMessage(result.message);
    }
  }

  void _showMessage(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(tripTrashControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recently Deleted')),
      body: _buildBody(controller),
    );
  }

  Widget _buildBody(TripTrashController controller) {
    if (controller.loading && controller.trips.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null && controller.trips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load recently deleted trips.\n${controller.error}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: controller.load,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (controller.trips.isEmpty) {
      return const Center(child: Text('No recently deleted trips.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.trips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final trip = controller.trips[index];
        return _DeletedTripCard(
          trip: trip,
          now: controller.now,
          restoring: controller.isRestoring(trip.id),
          onRestore: () => _confirmRestore(trip),
        );
      },
    );
  }
}

class _DeletedTripCard extends StatelessWidget {
  const _DeletedTripCard({
    required this.trip,
    required this.now,
    required this.restoring,
    required this.onRestore,
  });

  final Trip trip;
  final DateTime now;
  final bool restoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final deletedAt = trip.deletedAt!;
    final expiresAt = trip.trashExpiresAt!;
    final recoverable = trip.isRecoverableAt(now);
    final remainingDays = trip.remainingRecoveryDaysAt(now);
    final remainingText = recoverable
        ? remainingDays == 1
              ? '1 day remaining'
              : '$remainingDays days remaining'
        : 'Recovery period expired';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trip.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Deleted ${formatDate(deletedAt.toLocal())}'),
            Text('Expires ${formatDate(expiresAt.toLocal())}'),
            const SizedBox(height: 4),
            Text(remainingText),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: Key('restore-trip-${trip.id}'),
                onPressed: recoverable && !restoring ? onRestore : null,
                icon: const Icon(Icons.restore),
                label: Text(restoring ? 'Restoring...' : 'Restore'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
