import 'package:flutter/material.dart';

/// PB-09 follow-up (team decision, 2026-08-12): walking a report **out of**
/// `IssueReportStatus.resolved` — back to `open` or down to `inProgress` —
/// is an "undo" of a completed decision, not part of the routine forward
/// Open → In Progress → Resolved flow. It gets the same required-explanation
/// treatment `SuspendConfirmationDialog` gives account suspension, rather
/// than Sprint 2 Open Decision 6's general "issue remarks are optional"
/// default (`docs/admin/PROGRESS.md`), which still applies to every other
/// status transition.
///
/// Pre-fills from whatever's already typed in the screen's persistent
/// remarks field, so an admin who already explained themselves there isn't
/// forced to retype it — but the dialog still won't confirm on blank text.
///
/// Returns the trimmed remark on confirm, or `null` if cancelled — since a
/// remark is mandatory here, `null` unambiguously means "cancelled," the
/// same role `null` plays in `showSuspendConfirmationDialog`.
Future<String?> showLeavingResolvedRemarkDialog(
  BuildContext context, {
  required String targetStatusLabel,
  String initialRemarks = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _LeavingResolvedRemarkDialog(
      targetStatusLabel: targetStatusLabel,
      initialRemarks: initialRemarks,
    ),
  );
}

class _LeavingResolvedRemarkDialog extends StatefulWidget {
  const _LeavingResolvedRemarkDialog({
    required this.targetStatusLabel,
    required this.initialRemarks,
  });

  final String targetStatusLabel;
  final String initialRemarks;

  @override
  State<_LeavingResolvedRemarkDialog> createState() => _LeavingResolvedRemarkDialogState();
}

class _LeavingResolvedRemarkDialogState extends State<_LeavingResolvedRemarkDialog> {
  late final _remarkController = TextEditingController(text: widget.initialRemarks);

  bool get _canSubmit => _remarkController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Move back to ${widget.targetStatusLabel}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This report was already marked Resolved. Explain why it needs '
            'to change before continuing.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('leaving-resolved-remark-field'),
            controller: _remarkController,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Remark (required)',
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
        FilledButton(
          key: const Key('leaving-resolved-remark-confirm-button'),
          onPressed: _canSubmit
              ? () => Navigator.pop(context, _remarkController.text.trim())
              : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
