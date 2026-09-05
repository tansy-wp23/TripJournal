import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../community/controller/community_controller.dart';
import '../community/public_trip_view_screen.dart';
import 'trip_link.dart';

/// Wraps the app so a `tripjournal://trip/<id>` link - however the app was
/// launched or resumed - opens that trip on top of whatever's already
/// showing (the guest Community feed, or a signed-in user's Home). The
/// lookup (`fetchPublicTrip`) is the same anon-readable public-trip query
/// the "Open trip by ID" dialog already uses, so this works identically
/// whether the viewer is signed in or browsing as a guest.
class TripLinkListener extends ConsumerStatefulWidget {
  const TripLinkListener({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.linkStream,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// Defaults to `AppLinks().uriLinkStream`. Overridable so tests can feed
  /// in a fake stream without a real platform channel.
  final Stream<Uri>? linkStream;

  @override
  ConsumerState<TripLinkListener> createState() => _TripLinkListenerState();
}

class _TripLinkListenerState extends ConsumerState<TripLinkListener> {
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    final stream = widget.linkStream ?? AppLinks().uriLinkStream;
    _subscription = stream.listen(_openLink, onError: (_) {});
  }

  Future<void> _openLink(Uri uri) async {
    final tripId = tripIdFromLink(uri);
    if (tripId == null) return;

    final trip = await ref
        .read(communityControllerProvider.notifier)
        .fetchPublicTrip(tripId);
    if (!mounted) return;

    final navigatorState = widget.navigatorKey.currentState;
    if (navigatorState == null) return;

    if (trip == null) {
      showDialog<void>(
        context: navigatorState.context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Trip not found'),
          content: const Text(
            "This link's trip may be private, deleted, or no longer exists.",
          ),
          actions: [
            TextButton(
              key: const Key('trip-link-not-found-ok'),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    navigatorState.push(
      MaterialPageRoute(builder: (_) => PublicTripViewScreen(trip: trip)),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
