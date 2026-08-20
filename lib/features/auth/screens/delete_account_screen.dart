import 'package:flutter/material.dart';

import '../../../models/verification_code.dart';
import 'code_entry_screen.dart';

/// The permanent account-deletion warning/confirmation screen (Phase 9).
///
/// Deliberately more resistant than the deactivation flow: the user must
/// type "DELETE" into a field to unlock the "Send code" button, because this
/// action cannot be undone. Once unlocked, it routes to the shared
/// [CodeEntryScreen] with `purpose: VerificationPurpose.deletion`.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _confirmController = TextEditingController();

  bool get _canProceed => _confirmController.text.trim() == 'DELETE';

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          Icon(
            Icons.delete_forever,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            'This will permanently delete your account and all of your data.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'This action cannot be undone. Your trips, journal entries, '
            'health logs, and profile will be permanently removed. '
            'Deactivation is reversible — deletion is not.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            key: const Key('delete-confirm-field'),
            controller: _confirmController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Type DELETE to confirm',
              border: const OutlineInputBorder(),
              errorText: _confirmController.text.isNotEmpty &&
                      !_canProceed
                  ? 'Type DELETE exactly to continue'
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('delete-send-code-button'),
            onPressed: _canProceed ? () => _openCodeEntry(context) : null,
            icon: const Icon(Icons.send),
            label: const Text('Send code'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('delete-cancel-button'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCodeEntry(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CodeEntryScreen(purpose: VerificationPurpose.deletion),
      ),
    );
  }
}