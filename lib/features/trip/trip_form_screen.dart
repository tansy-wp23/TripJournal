import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../data/current_user_id_provider.dart';
import '../../data/trip_cover_storage.dart';
import '../../data/trip_repository_locator.dart';
import '../../models/trip.dart';
import '../../validation/photo_validation.dart';
import '../../validation/trip_validation.dart';
import '../../widgets/app_form_section.dart';
import '../journal/widgets/format_utils.dart';
import 'controller/trip_controller.dart';
import 'controller/trip_trash_controller.dart';
import 'trip_view_screen.dart';
import 'widgets/delete_trip_confirmation_dialog.dart';
import 'widgets/trip_cover_photo.dart';
import 'widgets/trip_photo_carousel.dart';

/// Create/Edit Trip form (IMPLEMENTATION_PLAN_HOMEPAGE.md Phase 6).
class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({
    super.key,
    this.existingTrip,
    this.userIdProvider,
    this.restoreOnSave = false,
  }) : assert(!restoreOnSave || existingTrip != null);

  final Trip? existingTrip;
  final CurrentUserIdProvider? userIdProvider;
  final bool restoreOnSave;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _destinationController;
  late final TextEditingController _notesController;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _coverPhotoPath;
  TripCoverDraft? _coverPhotoDraft;
  String? _dateRangeError;
  bool _saving = false;

  bool get _isEditing => widget.existingTrip != null;
  bool get _isRestoring => widget.restoreOnSave;

  @override
  void initState() {
    super.initState();
    final trip = widget.existingTrip;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _titleController = TextEditingController(text: trip?.title ?? '');
    _destinationController = TextEditingController(
      text: trip?.destination ?? '',
    );
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
    _destinationController.dispose();
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

      final draft = await TripCoverDraft.fromXFile(picked);
      final sizeError = validatePhotoSize(draft.previewBytes!.length);
      if (sizeError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(sizeError)));
        return;
      }

      setState(() {
        _coverPhotoPath = null;
        _coverPhotoDraft = draft;
      });
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

  void _removeCoverPhoto() => setState(() {
    _coverPhotoPath = null;
    _coverPhotoDraft = null;
  });

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
    } catch (e) {
      if (!mounted) return;
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
      destination: _destinationController.text.trim(),
      coverPhotoPath: _isRestoring ? existing?.coverPhotoPath : _coverPhotoPath,
      startDate: _startDate,
      endDate: _endDate,
      notes: notes.isEmpty ? null : notes,
      summary: existing?.summary,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      deletedAt: existing?.deletedAt,
    );

    if (_isRestoring) {
      final result = await ref
          .read(tripTrashControllerProvider.notifier)
          .restoreWithChanges(trip);
      if (!mounted) return;
      if (result.status == TripRestoreStatus.restored) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _dateRangeError = result.message ?? 'Could not restore this trip.';
        _saving = false;
      });
      return;
    }

    final controller = ref.read(tripControllerProvider.notifier);
    final error = _isEditing
        ? await controller.editTrip(trip, coverDraft: _coverPhotoDraft)
        : await controller.createTrip(trip, coverDraft: _coverPhotoDraft);
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
        MaterialPageRoute(
          builder: (_) => TripViewScreen(
            tripId: tripId,
            userIdProvider: widget.userIdProvider,
          ),
        ),
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
        title: Text(
          _isRestoring
              ? 'Restore trip'
              : _isEditing
              ? 'Edit trip'
              : 'New trip',
        ),
        actions: [
          if (_isEditing && !_isRestoring)
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
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    viewport.maxWidth < 480 ? 12 : 24,
                    12,
                    viewport.maxWidth < 480 ? 12 : 24,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppFormSection(
                        title: 'Trip details',
                        icon: Icons.luggage_outlined,
                        helperText: 'Give this journey a name and destination.',
                        child: Column(
                          children: [
                            TextFormField(
                              key: const Key('trip-title-field'),
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Trip title',
                                hintText: 'A name you will remember',
                              ),
                              maxLength: kTripTitleMaxLength,
                              validator: validateTripTitle,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              key: const Key('trip-destination-field'),
                              controller: _destinationController,
                              decoration: const InputDecoration(
                                labelText: 'Destination',
                                hintText: 'City, region, or country',
                              ),
                              validator: validateTripDestination,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppFormSection(
                        title: 'Travel dates',
                        icon: Icons.calendar_month_outlined,
                        helperText: 'Entries must stay within this date range.',
                        child: LayoutBuilder(
                          builder: (context, section) {
                            final fields = [
                              _DatePickerField(
                                key: const Key('trip-start-date-field'),
                                label: 'Start date',
                                date: _startDate,
                                onTap: _pickStartDate,
                              ),
                              _DatePickerField(
                                key: const Key('trip-end-date-field'),
                                label: 'End date',
                                date: _endDate,
                                onTap: _pickEndDate,
                              ),
                            ];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (section.maxWidth < 420) ...[
                                  fields.first,
                                  const SizedBox(height: 12),
                                  fields.last,
                                ] else
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: fields.first),
                                      const SizedBox(width: 12),
                                      Expanded(child: fields.last),
                                    ],
                                  ),
                                if (_dateRangeError != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _dateRangeError!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppFormSection(
                        title: 'Cover photo',
                        icon: Icons.landscape_outlined,
                        helperText: _isRestoring
                            ? 'The existing cover will be kept while restoring.'
                            : 'Choose one image to set the mood for this trip.',
                        action: _isRestoring
                            ? null
                            : TextButton.icon(
                                key: const Key('add-cover-photo-button'),
                                onPressed: _addCoverPhoto,
                                icon: const Icon(Icons.add_a_photo_outlined),
                                label: Text(
                                  _coverPhotoPath == null &&
                                          _coverPhotoDraft == null
                                      ? 'Add photo'
                                      : 'Change',
                                ),
                              ),
                        child:
                            _coverPhotoPath == null && _coverPhotoDraft == null
                            ? const _EmptyCoverPhoto()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: TripCoverPhoto(
                                      photoPath: _coverPhotoPath,
                                      coverDraft: _coverPhotoDraft,
                                      height: TripPhotoCarousel.resolveHeight(
                                        context,
                                      ),
                                      width: double.infinity,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Chip(
                                    avatar: const Icon(Icons.photo, size: 18),
                                    label: Text(
                                      _coverPhotoDraft?.name ??
                                          basename(_coverPhotoPath!),
                                    ),
                                    onDeleted: _isRestoring
                                        ? null
                                        : _removeCoverPhoto,
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                      AppFormSection(
                        title: 'Notes',
                        icon: Icons.notes_outlined,
                        helperText:
                            'Keep useful details together for easy reference.',
                        child: TextFormField(
                          key: const Key('trip-notes-field'),
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes and reminders (optional)',
                            hintText: 'Packing list, booking refs, addresses…',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 712),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('save-trip-button'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(_isRestoring ? 'Restoring…' : 'Saving…'),
                          ],
                        )
                      : Text(_isRestoring ? 'Restore' : 'Save'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCoverPhoto extends StatelessWidget {
  const _EmptyCoverPhoto();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.image_outlined, color: colors.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'No cover photo added.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
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
