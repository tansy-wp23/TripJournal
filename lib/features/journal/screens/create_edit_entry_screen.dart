import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../models/health_log.dart';
import '../../../models/geo_tag.dart';
import '../../../models/journal_entry.dart';
import '../../../models/meal.dart';
import '../../../models/mood.dart';
import '../../../models/trip.dart';
import '../../../data/photo_storage.dart';
import '../../../data/repository_locator.dart' as photo_locator;
import '../../../validation/journal_entry_validation.dart';
import '../../../validation/photo_validation.dart';
import '../../../widgets/app_form_section.dart';
import '../../health/health_data_source.dart';
import '../../health/health_data_source_locator.dart' as locator;
import '../../location/google_place_picker_map.dart';
import '../../location/place_picker_screen.dart';
import '../../location/place_search_locator.dart' as place_locator;
import '../../location/place_search_service.dart';
import '../controller/journal_controller.dart';
import '../entry_timestamp.dart';
import '../journal_photo_compensation.dart';
import '../mock_trip.dart';
import '../widgets/health_log_form.dart';
import '../widgets/mood_picker.dart';
import '../widgets/photo_thumbnail.dart';
import 'photo_viewer_screen.dart';

class CreateEditEntryScreen extends ConsumerStatefulWidget {
  const CreateEditEntryScreen({
    super.key,
    this.existingEntry,
    this.tripId,
    this.initialDate,
    this.trip,
    this.healthDataSource,
    this.photoStorage,
    this.placeSearchService,
    this.placePickerMapBuilder = buildConfiguredGooglePlacePickerMap,
  });

  final JournalEntry? existingEntry;

  /// Trip to create the new entry under. Ignored when editing (the
  /// existing entry's tripId is preserved). Falls back to [kMockTripId]
  /// when creating without one, so the plain FAB-create flow is unchanged.
  final String? tripId;

  /// Calendar day this entry is being written for — e.g. "today" for the
  /// homepage's "Write today's entry" deep link, or a specific backfilled
  /// day from the Trip View timeline. Ignored when editing. The actual
  /// `createdAt` timestamp is derived from this via [deriveEntryTimestamp]
  /// (today gets the real current time; a past day gets a noon default).
  /// Falls back to now.
  final DateTime? initialDate;

  /// The trip this entry belongs to, when known — used to validate that
  /// [initialDate] falls within the trip's date range before saving. Optional
  /// because the legacy unscoped create flow ([JournalListScreen]'s FAB)
  /// has no trip in scope; that path skips range validation.
  final Trip? trip;

  /// Overrides the app-wide [locator.healthDataSource] instance — tests only;
  /// production call sites never pass this, so they always get the real
  /// mock/platform swap from the locator.
  final HealthDataSource? healthDataSource;

  /// Overrides the app-wide [photoStorage] instance — tests only; production
  /// call sites never pass this.
  final PhotoStorage? photoStorage;

  /// Overrides the production Places service for focused widget tests.
  final PlaceSearchService? placeSearchService;

  /// Keeps the picker testable without constructing a platform map.
  final PlacePickerMapBuilder placePickerMapBuilder;

  @override
  ConsumerState<CreateEditEntryScreen> createState() =>
      _CreateEditEntryScreenState();
}

class _CreateEditEntryScreenState extends ConsumerState<CreateEditEntryScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late Mood _mood;
  late List<String> _photoPaths;
  late GeoTag? _location;
  int _steps = 0;
  int? _caloriesBurned;
  List<Meal> _meals = const [];

  // Only new entries get pre-filled from the health platform — re-fetching on
  // every edit would silently overwrite values the user already reviewed or
  // typed in themselves.
  bool _prefillingHealthData = false;

  // Whether the initial _steps/_caloriesBurned came from the health platform
  // (vs. the plain manual-entry defaults) — seeds HealthLogForm's "synced"
  // hints. Set once by _prefillFromHealthData; edits never touch these.
  bool _stepsFromHealth = false;
  bool _caloriesFromHealth = false;
  bool _showConnectHealthNote = false;

  // Mutable, unlike widget.existingEntry — once a brand-new entry is saved,
  // saving is no longer active on this screen (IMPLEMENTATION_PLAN_UX_AI.md
  // §3), so every subsequent save must edit that same persisted entry rather
  // than creating a second one.
  JournalEntry? _persistedEntry;

  bool _justSaved = false;
  bool _saving = false;
  bool _generatingAdvice = false;
  bool _adviceFailed = false;
  String? _aiAdviceText;

  // True once the user has changed anything since the last successful save
  // (or since opening a pristine entry). Gates the discard-changes prompt on
  // back — never nags when there's nothing to lose (IMPLEMENTATION_PLAN_
  // UX_POLISH.md §6).
  bool _dirty = false;

  bool get _isEditing => _persistedEntry != null;

  late final HealthDataSource _healthDataSource;
  late final PhotoStorage _photoStorage;
  late final String _draftEntryId;
  late final String _draftHealthLogId;

  /// The trip this entry belongs to, resolved once in [initState].
  ///
  /// Photo uploads need it before the entry is saved — `journal-photos` object
  /// paths are scoped by trip — so it cannot be worked out at save time the way
  /// it used to be.
  late final String _tripId;

  @override
  void initState() {
    super.initState();
    final entry = widget.existingEntry;
    _persistedEntry = entry;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _bodyController = TextEditingController(text: entry?.body ?? '');
    _mood = entry?.mood ?? Mood.neutral;
    _photoPaths = List.of(entry?.photoPaths ?? const []);
    _location = entry?.location;
    _steps = entry?.healthLog?.steps ?? 0;
    _caloriesBurned = entry?.healthLog?.caloriesBurned;
    _meals = List.of(entry?.healthLog?.meals ?? const []);
    _aiAdviceText = entry?.healthLog?.aiAdvice;
    _healthDataSource = widget.healthDataSource ?? locator.healthDataSource;
    _photoStorage = widget.photoStorage ?? photo_locator.photoStorage;
    _draftEntryId = entry?.id ?? const Uuid().v4();
    _draftHealthLogId = entry?.healthLog?.id ?? const Uuid().v4();
    _tripId = entry?.tripId ?? widget.tripId ?? kMockTripId;

    if (!_isEditing) {
      _prefillFromHealthData();
    }
  }

  /// Marks the form dirty since the last save, so a stale "Saved" label
  /// doesn't linger once the user has actually changed something.
  void _markDirty() {
    if (_dirty && !_justSaved) return;
    setState(() {
      _dirty = true;
      _justSaved = false;
    });
  }

  /// Silent, permission-CHECK-only prefill for a brand-new entry — never
  /// calls `requestPermissions()` here, so opening a fresh entry never shows
  /// an OS permission prompt unprompted. The actual "ask contextually" moment
  /// is the "Sync from health app" button in [HealthLogForm]
  /// (IMPLEMENTATION_PLAN_HEALTH.md §3, §5).
  Future<void> _prefillFromHealthData() async {
    setState(() => _prefillingHealthData = true);
    final date = widget.initialDate ?? DateTime.now();
    final hasPermission = await _healthDataSource.hasPermissions();
    int? steps;
    int? caloriesBurned;
    if (hasPermission) {
      steps = await _healthDataSource.getStepsForDate(date);
      caloriesBurned = await _healthDataSource.getCaloriesBurnedForDate(date);
    }
    if (!mounted) return;
    setState(() {
      // null means unavailable/no-data-for-date — leave the manual-entry
      // default (0) in place rather than overwriting it with a false zero.
      if (steps != null) {
        _steps = steps;
        _stepsFromHealth = true;
      }
      _caloriesBurned = caloriesBurned;
      _caloriesFromHealth = caloriesBurned != null;
      _showConnectHealthNote = !hasPermission;
      _prefillingHealthData = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  /// Offers camera (single photo) vs. gallery (multi-select, entry photos
  /// ONLY — the trip cover picker stays single-select on its own code path,
  /// see IMPLEMENTATION_PLAN_INLINE_PHOTO.md §3). Any failure — denied
  /// permission, no camera on this device/desktop, user backing out of the
  /// OS picker — is swallowed into a SnackBar rather than thrown; adding a
  /// photo is always optional, never a hard dependency for saving the entry.
  Future<void> _addPhoto() async {
    final remaining = remainingPhotoAllowance(_photoPaths.length);
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validatePhotoCount(_photoPaths.length)!)),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              key: const Key('pick-photo-camera'),
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              key: const Key('pick-photo-gallery'),
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    if (source == ImageSource.camera) {
      await _addFromCamera();
    } else {
      await _addFromGallery(remaining);
    }
  }

  Future<void> _addFromCamera() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera);
      if (picked == null || !mounted) {
        return; // user backed out of the OS picker
      }

      final sizeError = validatePhotoSize(await picked.length());
      if (sizeError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(sizeError)));
        return;
      }

      // Copy out of the OS cache before storing the path — the picker's own
      // path can be evicted, which is what turns a photo into a broken-image
      // placeholder days later.
      final stored = await _photoStorage.savePhoto(picked, tripId: _tripId);
      if (!mounted) return;

      setState(() {
        _photoPaths = [..._photoPaths, stored];
        _dirty = true;
        _justSaved = false;
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

  /// Multi-select from the gallery. [remaining] both guides the OS picker's
  /// own selection limit up front and is re-enforced here on return as the
  /// backstop — a selection that would exceed it is never silently
  /// truncated: the photos that fit are added and the rest are warned about,
  /// same as an individually-oversized file never blocks the rest of the
  /// batch.
  Future<void> _addFromGallery(int remaining) async {
    try {
      final picked = await ImagePicker().pickMultiImage(limit: remaining);
      if (picked.isEmpty || !mounted) {
        return; // user backed out / selected nothing
      }

      final accepted = <String>[];
      var overflowed = false;
      var oversized = false;

      for (final file in picked) {
        if (accepted.length >= remaining) {
          overflowed = true;
          continue;
        }
        final sizeError = validatePhotoSize(await file.length());
        if (sizeError != null) {
          oversized = true;
          continue;
        }
        accepted.add(await _photoStorage.savePhoto(file, tripId: _tripId));
      }
      if (!mounted) return;

      if (accepted.isNotEmpty) {
        setState(() {
          _photoPaths = [..._photoPaths, ...accepted];
          _dirty = true;
          _justSaved = false;
        });
      }

      if (!mounted) return;
      final warnings = <String>[
        if (overflowed) validatePhotoCount(kMaxPhotosPerEntry)!,
        if (oversized) 'This image is too large (max 32 MB).',
      ];
      if (warnings.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(warnings.join(' '))));
      }
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

  void _removePhoto(int index) {
    final removed = _photoPaths[index];
    setState(() {
      _photoPaths = List.of(_photoPaths)..removeAt(index);
      _dirty = true;
      _justSaved = false;
    });
    // Only clean up a copy made during *this* editing session. A photo that is
    // already part of the saved entry has to survive, because the user can
    // still discard these edits and leave that entry pointing at it.
    //
    // Fire-and-forget beyond that: a leaked file is never worth blocking the
    // UI for, and paths we never copied (gallery originals, older entries) are
    // ignored by the storage anyway.
    final persisted = _persistedEntry?.photoPaths ?? const <String>[];
    if (!persisted.contains(removed)) {
      unawaited(_photoStorage.deletePhoto(removed));
    }
  }

  Future<void> _pickLocation() async {
    final location = await Navigator.push<GeoTag>(
      context,
      MaterialPageRoute(
        builder: (_) => PlacePickerScreen(
          service:
              widget.placeSearchService ?? place_locator.placeSearchService,
          mapBuilder: widget.placePickerMapBuilder,
          initialLocation: _location,
        ),
      ),
    );
    if (!mounted || location == null) return;
    setState(() {
      _location = location;
      _dirty = true;
      _justSaved = false;
    });
  }

  void _removeLocation() {
    setState(() {
      _location = null;
      final persisted = _persistedEntry;
      if (persisted != null) {
        _persistedEntry = persisted.copyWith(clearLocation: true);
      }
      _dirty = true;
      _justSaved = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _justSaved = false;
    });

    try {
      final title = _titleController.text.trim();
      final body = _bodyController.text.trim();

      final now = DateTime.now();
      final existing = _persistedEntry;
      final createdAt =
          existing?.createdAt ??
          deriveEntryTimestamp(widget.initialDate ?? now, now: now);
      final creationOrderAt = existing?.creationOrderAt ?? now;
      final entryId = existing?.id ?? _draftEntryId;
      final healthLogId = existing?.healthLog?.id ?? _draftHealthLogId;
      final totalCaloriesEaten = _meals.fold<int>(
        0,
        (sum, meal) => sum + meal.calories,
      );

      final entry = JournalEntry(
        id: entryId,
        tripId: _tripId,
        title: title,
        body: body,
        mood: _mood,
        photoPaths: _photoPaths,
        location: _location,
        createdAt: createdAt,
        updatedAt: now,
        creationOrderAt: creationOrderAt,
        // Preserve whatever advice already existed — generateAndAttachAdvice
        // regenerates it as a separate step right after this save completes,
        // per IMPLEMENTATION_PLAN_UX_AI.md §3.
        healthLog: HealthLog(
          id: healthLogId,
          entryId: entryId,
          steps: _steps,
          caloriesEaten: totalCaloriesEaten,
          caloriesBurned: _caloriesBurned,
          meals: _meals,
          aiAdvice: existing?.healthLog?.aiAdvice,
        ),
      );

      // Content-required, length caps, steps/meal invariants, and (for new
      // entries) the date/trip-range rules all live in the controller — see
      // IMPLEMENTATION_PLAN_VALIDATION.md's "Where Validation Lives" — so they
      // hold no matter how save is triggered, not just from this screen.
      final controller = ref.read(journalControllerProvider.notifier);
      final validationError = controller.validate(
        entry,
        checkDate: !_isEditing,
        trip: widget.trip,
      );
      if (validationError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validationError)));
        return;
      }

      // Only a validated entry reaches the confirmation prompt — guards
      // against accidental saves while making the (potentially AI-triggering)
      // save a conscious action (IMPLEMENTATION_PLAN_UX_POLISH.md §5).
      final confirmed = await _confirmSave();
      if (!confirmed || !mounted) {
        return; // Cancel — stay in the editor, input intact.
      }

      final error = _isEditing
          ? await controller.edit(entry)
          : await controller.create(entry, trip: widget.trip);
      if (error != null) {
        final cleaned = await cleanupPhotosAfterFailedJournalSave(
          before: existing,
          attempted: entry,
          storage: _photoStorage,
        );
        if (!mounted) return;
        if (cleaned.isNotEmpty) {
          setState(() {
            _photoPaths = _photoPaths
                .where((path) => !cleaned.contains(path))
                .toList();
            _meals = [
              for (final meal in _meals)
                cleaned.contains(meal.photoPath)
                    ? meal.copyWith(clearPhotoPath: true)
                    : meal,
            ];
          });
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      if (!mounted) return;

      // Stay on this screen — do NOT navigate away. This entry is now the
      // persisted one going forward, so further saves edit it in place rather
      // than creating a second entry.
      setState(() {
        _persistedEntry = entry;
        _justSaved = true;
        _dirty = false;
      });

      unawaited(
        cleanupPhotosAfterSuccessfulJournalSave(
          before: existing,
          saved: entry,
          storage: _photoStorage,
        ),
      );

      unawaited(_generateAdvice(entry));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleBackAttempt(bool didPop, Object? result) async {
    if (didPop || _saving) return;
    final discard = await _confirmDiscard();
    if (!mounted) return;
    if (discard) Navigator.pop(context);
  }

  /// "Discard changes?" — only ever shown when [_dirty] is true; a clean
  /// form leaves silently on back, no nagging (IMPLEMENTATION_PLAN_UX_
  /// POLISH.md §6).
  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            key: const Key('discard-keep-editing'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            key: const Key('discard-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  /// "Save changes to this entry?" — Confirm persists, Cancel dismisses and
  /// leaves the form exactly as the user left it (IMPLEMENTATION_PLAN_UX_
  /// POLISH.md §5). Only shown once the entry has already passed validation.
  Future<bool> _confirmSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save changes to this entry?'),
        actions: [
          TextButton(
            key: const Key('save-confirm-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('save-confirm-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Generates AI advice for [entry] and persists it, showing a loading
  /// state while it runs. Failure never loses the (already-saved) entry —
  /// it just leaves a "couldn't generate, tap to retry" affordance.
  Future<void> _generateAdvice(JournalEntry entry) async {
    setState(() {
      _generatingAdvice = true;
      _adviceFailed = false;
    });

    final controller = ref.read(journalControllerProvider.notifier);
    final advice = await controller.generateAndAttachAdvice(entry);
    if (!mounted) return;

    setState(() {
      _generatingAdvice = false;
      if (advice != null) {
        _aiAdviceText = advice;
        _adviceFailed = false;
        final healthLog = entry.healthLog;
        if (healthLog != null) {
          _persistedEntry = entry.copyWith(
            healthLog: healthLog.copyWith(aiAdvice: advice),
          );
        }
      } else {
        _adviceFailed = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: _handleBackAttempt,
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Edit entry' : 'New entry')),
        body: AbsorbPointer(
          absorbing: _saving,
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
                          title: 'Your story',
                          icon: Icons.auto_stories_outlined,
                          helperText: 'Capture the moment in your own words.',
                          child: Column(
                            children: [
                              TextField(
                                key: const Key('entry-title-field'),
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Entry title',
                                  hintText: 'What made this moment memorable?',
                                ),
                                maxLength: kEntryTitleMaxLength,
                                onChanged: (_) => _markDirty(),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                key: const Key('entry-body-field'),
                                controller: _bodyController,
                                decoration: const InputDecoration(
                                  labelText: 'Journal entry',
                                  hintText: 'Write what happened…',
                                  alignLabelWithHint: true,
                                ),
                                minLines: 5,
                                maxLines: 8,
                                maxLength: kEntryBodyMaxLength,
                                onChanged: (_) => _markDirty(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppFormSection(
                          title: 'Mood',
                          icon: Icons.sentiment_satisfied_alt_outlined,
                          helperText: 'How did this part of the trip feel?',
                          child: MoodPicker(
                            selected: _mood,
                            onSelected: (mood) => setState(() {
                              _mood = mood;
                              _dirty = true;
                              _justSaved = false;
                            }),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppFormSection(
                          title: 'Photos',
                          icon: Icons.photo_library_outlined,
                          helperText:
                              '${_photoPaths.length} of $kMaxPhotosPerEntry added',
                          action: TextButton.icon(
                            key: const Key('add-photo-button'),
                            onPressed: _saving ? null : _addPhoto,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Add photo'),
                          ),
                          child: _photoPaths.isEmpty
                              ? const _FormEmptyState(
                                  icon: Icons.photo_outlined,
                                  text: 'No photos added.',
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (var i = 0; i < _photoPaths.length; i++)
                                      PhotoThumbnail(
                                        key: Key('photo-thumbnail-$i'),
                                        photoPath: _photoPaths[i],
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PhotoViewerScreen(
                                              photoPaths: _photoPaths,
                                              initialIndex: i,
                                            ),
                                          ),
                                        ),
                                        onRemove: () => _removePhoto(i),
                                        removeButtonKey: Key('remove-photo-$i'),
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        AppFormSection(
                          title: 'Place',
                          icon: Icons.place_outlined,
                          helperText:
                              'Pin this memory so it can appear on the trip map.',
                          action: _location == null
                              ? TextButton.icon(
                                  key: const Key('add-location-button'),
                                  onPressed: _pickLocation,
                                  icon: const Icon(
                                    Icons.add_location_alt_outlined,
                                  ),
                                  label: const Text('Add location'),
                                )
                              : TextButton.icon(
                                  key: const Key('change-location-button'),
                                  onPressed: _pickLocation,
                                  icon: const Icon(
                                    Icons.edit_location_outlined,
                                  ),
                                  label: const Text('Change'),
                                ),
                          child: _LocationSection(
                            location: _location,
                            onRemove: _removeLocation,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppFormSection(
                          title: 'Wellness',
                          icon: Icons.favorite_outline,
                          helperText:
                              'Review movement, energy and meals for this day.',
                          child: _prefillingHealthData
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 8),
                                        Text('Checking your health data…'),
                                      ],
                                    ),
                                  ),
                                )
                              : HealthLogForm(
                                  initialSteps: _steps,
                                  initialCaloriesBurned: _caloriesBurned,
                                  initialMeals: _meals,
                                  entryDate:
                                      _persistedEntry?.createdAt ??
                                      widget.initialDate ??
                                      DateTime.now(),
                                  initialStepsFromHealth: _stepsFromHealth,
                                  initialCaloriesFromHealth:
                                      _caloriesFromHealth,
                                  initialShowConnectHealthNote:
                                      _showConnectHealthNote,
                                  tripId: _tripId,
                                  healthDataSource: widget.healthDataSource,
                                  onChanged: (data) {
                                    _steps = data.steps;
                                    _caloriesBurned = data.caloriesBurned;
                                    _meals = data.meals;
                                    _markDirty();
                                  },
                                ),
                        ),
                        if (_generatingAdvice ||
                            _adviceFailed ||
                            _aiAdviceText != null) ...[
                          const SizedBox(height: 16),
                          AppFormSection(
                            title: 'AI suggestion',
                            icon: Icons.auto_awesome_outlined,
                            helperText:
                                'A short reflection generated after saving.',
                            child: _AdviceContent(
                              generating: _generatingAdvice,
                              failed: _adviceFailed,
                              advice: _aiAdviceText,
                              onRetry: () {
                                final entry = _persistedEntry;
                                if (entry != null) _generateAdvice(entry);
                              },
                            ),
                          ),
                        ],
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
                    key: const Key('save-entry-button'),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const Text('Saving…')
                        : Text(_justSaved ? 'Saved' : 'Save'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.location, required this.onRemove});

  final GeoTag? location;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final selected = location;
    return Column(
      key: const Key('location-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected == null)
          const _FormEmptyState(
            icon: Icons.location_off_outlined,
            text: 'No location added.',
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.place_outlined),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _LocationLabel(location: selected)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        key: const Key('remove-location-button'),
                        onPressed: onRemove,
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FormEmptyState extends StatelessWidget {
  const _FormEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _AdviceContent extends StatelessWidget {
  const _AdviceContent({
    required this.generating,
    required this.failed,
    required this.advice,
    required this.onRetry,
  });

  final bool generating;
  final bool failed;
  final String? advice;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (generating) {
      return const Row(
        key: Key('ai-advice-loading'),
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(child: Text('Generating suggestion…')),
        ],
      );
    }
    if (failed) {
      return InkWell(
        key: const Key('ai-advice-retry'),
        onTap: onRetry,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text("Couldn't generate suggestion — tap to retry."),
        ),
      );
    }
    return Text(advice ?? '', key: const Key('ai-advice-text'));
  }
}

class _LocationLabel extends StatelessWidget {
  const _LocationLabel({required this.location});

  final GeoTag location;

  @override
  Widget build(BuildContext context) {
    final coordinate =
        '${location.latitude.toStringAsFixed(6)}, '
        '${location.longitude.toStringAsFixed(6)}';
    final name =
        _nonBlank(location.placeName) ??
        _nonBlank(location.formattedAddress) ??
        coordinate;
    final address = _nonBlank(location.formattedAddress);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: Theme.of(context).textTheme.titleMedium),
        if (address != null && address != name) ...[
          const SizedBox(height: 2),
          Text(address),
        ],
      ],
    );
  }
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
