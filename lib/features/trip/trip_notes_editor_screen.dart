import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/trip.dart';
import '../../validation/trip_validation.dart';
import 'controller/trip_controller.dart';

/// Focused, notes-only editor reached by tapping the Notes/Reminders card on
/// Trip View — distinct from the full trip-edit form (title/dates/cover),
/// which stays reachable only via the AppBar edit icon. Same Save-confirm +
/// dirty/discard-guard pattern as the entry editor
/// (IMPLEMENTATION_PLAN_UX_POLISH.md §5/§6). See
/// IMPLEMENTATION_PLAN_INLINE_PHOTO.md §1.
class TripNotesEditorScreen extends ConsumerStatefulWidget {
  const TripNotesEditorScreen({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripNotesEditorScreen> createState() =>
      _TripNotesEditorScreenState();
}

class _TripNotesEditorScreenState extends ConsumerState<TripNotesEditorScreen> {
  late final TextEditingController _notesController;
  bool _dirty = false;
  String? _lengthError;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.trip.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    final notes = _notesController.text.trim();
    final lengthError = validateTripNotesLength(notes);
    setState(() => _lengthError = lengthError);
    if (lengthError != null) return;

    final trip = widget.trip;
    final updated = Trip(
      id: trip.id,
      userId: trip.userId,
      title: trip.title,
      coverPhotoPath: trip.coverPhotoPath,
      startDate: trip.startDate,
      endDate: trip.endDate,
      notes: notes.isEmpty ? null : notes,
      summary: trip.summary,
      createdAt: trip.createdAt,
      updatedAt: DateTime.now(),
    );

    final controller = ref.read(tripControllerProvider.notifier);
    final validationError = controller.validate(
      updated,
      excludingTripId: updated.id,
    );
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final confirmed = await _confirmSave();
    if (!confirmed || !mounted) {
      return;
    }

    final error = await controller.editTrip(updated);
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (!mounted) return;

    // Reset before popping — belt-and-braces in case PopScope's canPop gate
    // ever ends up consulted for this programmatic pop too, not just user-
    // initiated back navigation.
    setState(() => _dirty = false);
    Navigator.pop(context);
  }

  Future<bool> _confirmSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save changes?'),
        actions: [
          TextButton(
            key: const Key('notes-save-confirm-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('notes-save-confirm-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _handleBackAttempt(bool didPop, Object? result) async {
    if (didPop) return;
    final discard = await _confirmDiscard();
    if (!mounted) return;
    if (discard) Navigator.pop(context);
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            key: const Key('notes-discard-keep-editing'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            key: const Key('notes-discard-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: _handleBackAttempt,
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Notes')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('trip-notes-editor-field'),
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes / Reminders (optional)',
                    hintText: 'Packing list, booking refs, addresses...',
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                    errorText: _lengthError,
                  ),
                  maxLength: kTripNotesMaxLength,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (_) => _markDirty(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save-notes-button'),
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
