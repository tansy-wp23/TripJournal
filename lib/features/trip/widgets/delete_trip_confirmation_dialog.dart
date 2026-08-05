import 'package:flutter/material.dart';

Future<bool> showDeleteTripConfirmationDialog(
  BuildContext context, {
  required String tripTitle,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Move "$tripTitle" to Recently Deleted?'),
      content: const Text('You can restore it for 30 days.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Move to Trash'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
