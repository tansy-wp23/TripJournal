import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../data/current_user_id_provider.dart';
import '../../data/trip_repository_locator.dart';
import '../../models/trip.dart';
import '../../validation/photo_validation.dart';
import '../../validation/trip_validation.dart';
import '../journal/widgets/format_utils.dart';
import 'controller/trip_controller.dart';
import 'trip_view_screen.dart';
import 'widgets/delete_trip_confirmation_dialog.dart';

/// Create/Edit Trip form (IMPLEMENTATION_PLAN_HOMEPAGE.md Phase 6).
class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({super.key, this.existingTrip, this.userIdProvider});

  final Trip? existingTrip;
  final CurrentUserIdProvider? userIdProvider;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _coverPhotoPath;
  String? _dateRangeError;
  bool _saving = false;

  bool get _isEditing => widget.existingTrip != null;

  @override
  void initState() {
    super.initState();
    final trip = widget.existingTrip;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _titleController = TextEditingController(text: trip?.title ?? '');
    _notesController = TextEditingController(text: trip?.notes ?? '');
    _startDate = trip == null
        ? today
        : DateTime(
            trip.startDate.year,
            trip.startDate.month,
            trip.startDate.day,
          );
    _endDate = trip == null
        ? today
        : DateTime(trip.endDate.year, trip.endDate.month, trip.endDate.day);
    _coverPhotoPath = trip?.coverPhotoPath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      _dateRangeError = null;
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _endDate = picked;
      _dateRangeError = null;
    });
  }

  /// Offers camera vs. gallery, then invokes the real device picker — same
  /// pattern as journal entry photos. Any failure (denied permission, no
  /// camera on this device/desktop, user backing out of the OS picker) is
  /// swallowed into a SnackBar rather than thrown; a cover photo is always
  /// optional, never a hard dependency for saving the trip.
  Future<void> _addCoverPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              key: const Key('pick-cover-photo-camera'),
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              key: const Key('pick-cover-photo-gallery'),
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) return; // user backed out of the OS picker

      final sizeError = validatePhotoSize(await picked.length());
      if (sizeError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(sizeError)));
        return;
      }

      setState(() => _coverPhotoPath = picked.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't access photos — you can still save without one.",
          ),
        ),
      );
    }
  }

  void _removeCoverPhoto() => setState(() => _coverPhotoPath = null);

  Future<void> _save() async {
    if (_saving) return;

    // Immediate UI-level feedback — the controller re-checks all of this
    // (plus overlap) as the authoritative backstop before persisting.
    final titleValid = _formKey.currentState?.validate() ?? false;
    final dateRangeError = validateTripDateRange(_startDate, _endDate);
    setState(() => _dateRangeError = dateRangeError);
    if (!titleValid || dateRangeError != null) return;
    setState(() => _saving = true);

    final now = DateTime.now();
    final existing = widget.existingTrip;
    final tripId = existing?.id ?? const Uuid().v4();
    late final String userId;
    try {
      userId =
          existing?.userId ??
          (widget.userIdProvider ?? currentUserIdProvider).requireUserId();
    } on UnauthenticatedTripUserException catch (e) {
      setState(() {
        _dateRangeError = e.toString();
        _saving = false;
      });
      return;
    }
    final notes = _notesController.text.trim();

    final trip = Trip(
      id: tripId,
      userId: userId,
      title: _titleController.text.trim(),
      coverPhotoPath: _coverPhotoPath,
      startDate: _startDate,
      endDate: _endDate,
      notes: notes.isEmpty ? null : notes,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final controller = ref.read(tripControllerProvider.notifier);
    final error = _isEditing
        ? await controller.editTrip(trip)
        : await controller.createTrip(trip);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _dateRangeError = error;
        _saving = false;
      });
      return;
    }

    if (_isEditing) {
      Navigator.pop(context);
    } else {
      // Fresh trip — go straight to its timeline instead of back to the form.
      final movedToTrash = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => TripViewScreen(tripId: tripId)),
      );
      if (!mounted) return;
      Navigator.pop(context, movedToTrash == true ? true : null);
    }
  }

  Future<void> _confirmAndDelete() async {
    final existing = widget.existingTrip;
    if (existing == null) return;

    final tripController = ref.read(tripControllerProvider.notifier);
    final confirmed = await showDeleteTripConfirmationDialog(
      context,
      tripTitle: existing.title,
    );
    if (!confirmed || !mounted) return;

    final error = await tripController.moveToTrash(existing.id);
    if (!mounted) return;
    if (error != null) {
      setState(() => _dateRangeError = error);
      return;
    }
    // Signal Trip View to close as well; Home then refreshes its dashboard.
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit trip' : 'New trip'),
        actions: [
          if (_isEditing)
            IconButton(
              key: const Key('delete-trip-button'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Move to Trash',
              onPressed: _confirmAndDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('trip-title-field'),
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              maxLength: kTripTitleMaxLength,
              validator: validateTripTitle,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DatePickerField(
                    key: const Key('trip-start-date-field'),
                    label: 'Start date',
                    date: _startDate,
                    onTap: _pickStartDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerField(
                    key: const Key('trip-end-date-field'),
                    label: 'End date',
                    date: _endDate,
                    onTap: _pickEndDate,
                  ),
                ),
              ],
            ),
            if (_dateRangeError != null) ...[
              const SizedBox(height: 8),
              Text(
                _dateRangeError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cover photo',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                TextButton.icon(
                  key: const Key('add-cover-photo-button'),
                  onPressed: _addCoverPhoto,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Add photo'),
                ),
              ],
            ),
            if (_coverPhotoPath == null)
              const Text('No cover photo added.')
            else
              Chip(
                avatar: const Icon(Icons.photo, size: 18),
                label: Text(basename(_coverPhotoPath!)),
                onDeleted: _removeCoverPhoto,
              ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('trip-notes-field'),
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes / Reminders (optional)',
                hintText: 'Packing list, booking refs, addresses...',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('save-trip-button'),
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(formatDate(date)),
      ),
    );
  }
}
