import 'package:flutter/material.dart';

/// PB-05: confirms intent to reactivate [targetDisplayName]. No reason
/// captured — `AdminAccountActionsRepository.reactivateUser` takes none,
/// and unlike suspension there's no Phase 5 decision requiring one.
/// Mirrors `showDeleteTripConfirmationDialog`'s `Future<bool> show...`
/// pattern directly (no reason field, so no need for
/// `SuspendConfirmationDialog`'s stateful text-input handling).
Future<bool> showReactivateConfirmationDialog(
  BuildContext context, {
  required String targetDisplayName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Reactivate $targetDisplayName?'),
      content: const Text('They will be able to sign in again immediately.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('reactivate-confirm-button'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Reactivate'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
