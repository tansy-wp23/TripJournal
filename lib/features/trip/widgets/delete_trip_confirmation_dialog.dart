import 'package:flutter/material.dart';

/// Decision #3 (IMPLEMENTATION_PLAN_HOMEPAGE.md): prompt the user with the
/// entry count, cascade-delete on confirm.
Future<bool> showDeleteTripConfirmationDialog(
  BuildContext context, {
  required String tripTitle,
  required int entryCount,
}) async {
  final message = entryCount == 0
      ? 'This will permanently delete "$tripTitle". This cannot be undone.'
      : 'Delete "$tripTitle" and its $entryCount journal '
          '${entryCount == 1 ? 'entry' : 'entries'}? This cannot be undone.';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete trip?'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
