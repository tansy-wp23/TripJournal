import 'package:flutter/material.dart';

/// PB-04: confirms intent to suspend [targetDisplayName], capturing a
/// **required** reason (`docs/admin/PROGRESS.md` Phase 5 decision —
/// free text, presence-only validation, no content review).
///
/// Returns the trimmed reason on confirm, or `null` if cancelled — since a
/// reason is mandatory, `null` unambiguously means "cancelled," the same
/// role `false` plays in `showDeleteTripConfirmationDialog`'s `Future<bool>`.
Future<String?> showSuspendConfirmationDialog(
  BuildContext context, {
  required String targetDisplayName,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _SuspendConfirmationDialog(targetDisplayName: targetDisplayName),
  );
}

class _SuspendConfirmationDialog extends StatefulWidget {
  const _SuspendConfirmationDialog({required this.targetDisplayName});

  final String targetDisplayName;

  @override
  State<_SuspendConfirmationDialog> createState() => _SuspendConfirmationDialogState();
}

class _SuspendConfirmationDialogState extends State<_SuspendConfirmationDialog> {
  final _reasonController = TextEditingController();

  bool get _canSubmit => _reasonController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Suspend ${widget.targetDisplayName}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'They will be unable to sign in until an administrator '
            'reactivates the account.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('suspend-reason-field'),
            controller: _reasonController,
            autofocus: true,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason (required)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          key: const Key('suspend-confirm-button'),
          style: FilledButton.styleFrom(foregroundColor: Colors.red),
          onPressed: _canSubmit
              ? () => Navigator.pop(context, _reasonController.text.trim())
              : null,
          child: const Text('Suspend'),
        ),
      ],
    );
  }
}
