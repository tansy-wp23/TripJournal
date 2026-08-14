import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/photo_storage.dart';
import '../../../data/repository_locator.dart' as photo_locator;
import '../../../models/meal.dart';
import '../../../models/meal_type.dart';
import '../../../models/portion_size.dart';
import '../../../validation/meal_validation.dart';
import '../../../validation/photo_validation.dart';
import '../../../validation/steps_validation.dart';
import '../../health/health_data_source.dart';
import '../../health/health_data_source_locator.dart' as locator;
import '../ai/food_detection_locator.dart';
import 'meal_display.dart';
import 'photo_thumbnail.dart';

class HealthLogFormData {
  const HealthLogFormData({required this.steps, required this.caloriesBurned, required this.meals});

  final int steps;
  final int? caloriesBurned;
  final List<Meal> meals;
}

/// Reusable steps + meals sub-form. Calories EATEN are always derived from
/// the meal list (never entered directly) — read them via
/// [HealthLogFormData] in [onChanged]. Steps and calories BURNED may arrive
/// pre-filled from the health platform (see [CreateEditEntryScreen]) but
/// always stay manually editable here — a denied permission or missing
/// wearable must never block filling these in by hand.
class HealthLogForm extends StatefulWidget {
  const HealthLogForm({
    super.key,
    this.initialSteps = 0,
    this.initialCaloriesBurned,
    this.initialMeals = const [],
    required this.entryDate,
    this.initialStepsFromHealth = false,
    this.initialCaloriesFromHealth = false,
    this.initialShowConnectHealthNote = false,
    this.healthDataSource,
    this.photoStorage,
    required this.onChanged,
  });

  final int initialSteps;
  final int? initialCaloriesBurned;
  final List<Meal> initialMeals;

  /// The calendar day to query the health platform for — matches how
  /// [HealthLog] is keyed to a journal entry's day (IMPLEMENTATION_PLAN_
  /// HEALTH.md §3).
  final DateTime entryDate;

  /// Whether [initialSteps] / [initialCaloriesBurned] came from an automatic
  /// prefill on open (see `CreateEditEntryScreen`), so the "synced" hint
  /// shows correctly without this form re-fetching on its own.
  final bool initialStepsFromHealth;
  final bool initialCaloriesFromHealth;

  /// Whether the automatic prefill found no health permission, so the
  /// "connect a health app" note should show right away.
  final bool initialShowConnectHealthNote;

  /// Overrides the app-wide [locator.healthDataSource] instance — tests only;
  /// production call sites never pass this, so they always get the real
  /// mock/platform swap from the locator.
  final HealthDataSource? healthDataSource;

  /// Overrides the app-wide [photoStorage] instance — tests only; production
  /// call sites never pass this.
  final PhotoStorage? photoStorage;

  final ValueChanged<HealthLogFormData> onChanged;

  @override
  State<HealthLogForm> createState() => _HealthLogFormState();
}

class _HealthLogFormState extends State<HealthLogForm> {
  late final TextEditingController _stepsController;
  late final TextEditingController _caloriesBurnedController;
  late List<Meal> _meals;

  // Live feedback only — the actual save-time gate is the controller's own
  // validation (see IMPLEMENTATION_PLAN_VALIDATION.md), which holds
  // regardless of what this sub-form shows.
  String? _stepsError;

  // Whether the value currently shown came from the health platform (versus
  // hand-typed) — cleared the moment the user edits that field themselves,
  // per IMPLEMENTATION_PLAN_HEALTH.md §2 ("never overwrite user input").
  late bool _stepsFromHealth;
  late bool _caloriesFromHealth;
  late bool _showConnectNote;
  bool _syncing = false;
  late final HealthDataSource _healthDataSource;
  late final PhotoStorage _photoStorage;

  @override
  void initState() {
    super.initState();
    _stepsController = TextEditingController(text: widget.initialSteps.toString());
    _caloriesBurnedController =
        TextEditingController(text: widget.initialCaloriesBurned?.toString() ?? '');
    _meals = List.of(widget.initialMeals);
    _stepsFromHealth = widget.initialStepsFromHealth;
    _caloriesFromHealth = widget.initialCaloriesFromHealth;
    _showConnectNote = widget.initialShowConnectHealthNote;
    _healthDataSource = widget.healthDataSource ?? locator.healthDataSource;
    _photoStorage = widget.photoStorage ?? photo_locator.photoStorage;
  }

  @override
  void dispose() {
    _stepsController.dispose();
    _caloriesBurnedController.dispose();
    super.dispose();
  }

  int get _totalCalories => _meals.fold(0, (sum, m) => sum + m.calories);

  void _emitChange() {
    final steps = int.tryParse(_stepsController.text) ?? 0;
    setState(() => _stepsError = validateSteps(steps));
    widget.onChanged(HealthLogFormData(
      steps: steps,
      caloriesBurned: int.tryParse(_caloriesBurnedController.text),
      meals: _meals,
    ));
  }

  /// Explicit, on-demand re-pull from the health platform — the natural
  /// place to trigger the permission request the first time (contextual,
  /// not on cold launch), and the only path allowed to overwrite a value the
  /// user already typed, since it's a conscious action rather than a silent
  /// background prefill (IMPLEMENTATION_PLAN_HEALTH.md §2, §5).
  Future<void> _syncFromHealthApp() async {
    var granted = await _healthDataSource.hasPermissions();
    if (!mounted) return;
    if (!granted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Connect a health app?'),
          content: const Text(
            'TripJournal can read your step count and calories burned from your '
            "phone's health app to save you typing them in. This is read-only — "
            'nothing is ever written back, and you can always edit the numbers yourself.',
          ),
          actions: [
            TextButton(
              key: const Key('health-permission-cancel'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              key: const Key('health-permission-continue'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
      granted = await _healthDataSource.requestPermissions();
    }
    if (!mounted) return;

    if (!granted) {
      setState(() => _showConnectNote = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied — you can still enter steps and calories manually.')),
      );
      return;
    }

    setState(() => _syncing = true);
    final steps = await _healthDataSource.getStepsForDate(widget.entryDate);
    final caloriesBurned = await _healthDataSource.getCaloriesBurnedForDate(widget.entryDate);
    if (!mounted) return;

    setState(() {
      _syncing = false;
      _showConnectNote = false;
      if (steps != null) {
        _stepsController.text = steps.toString();
        _stepsFromHealth = true;
      }
      if (caloriesBurned != null) {
        _caloriesBurnedController.text = caloriesBurned.toString();
        _caloriesFromHealth = true;
      }
    });
    if (steps == null && caloriesBurned == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No health data found for this day.')),
      );
    }
    _emitChange();
  }

  Future<void> _addMeal() async {
    final meal = await showDialog<Meal>(
      context: context,
      builder: (_) => _MealDialog(photoStorage: _photoStorage),
    );
    if (meal == null) return;
    setState(() => _meals = [..._meals, meal]);
    _emitChange();
  }

  Future<void> _editMeal(int index) async {
    final updated = await showDialog<Meal>(
      context: context,
      builder: (_) => _MealDialog(
        initialMeal: _meals[index],
        photoStorage: _photoStorage,
      ),
    );
    if (updated == null) return;
    setState(() => _meals = List.of(_meals)..[index] = updated);
    _emitChange();
  }

  void _removeMeal(int index) {
    setState(() => _meals = List.of(_meals)..removeAt(index));
    _emitChange();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Health Log', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_showConnectNote)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite_border, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Connect a health app to auto-fill steps and calories.'),
                        ),
                        IconButton(
                          key: const Key('dismiss-connect-health-note'),
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _showConnectNote = false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('sync-health-button'),
                onPressed: _syncing ? null : _syncFromHealthApp,
                icon: _syncing
                    ? const SizedBox(
                        key: Key('sync-health-loading'),
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_syncing ? 'Syncing…' : 'Sync from health app'),
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              key: const Key('health-log-steps-field'),
              controller: _stepsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Steps'),
              onChanged: (_) {
                _stepsFromHealth = false;
                _emitChange();
              },
            ),
            if (_stepsFromHealth)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Synced from health app',
                  key: const Key('steps-from-health-hint'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            if (_stepsError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _stepsError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('health-log-calories-burned-field'),
              controller: _caloriesBurnedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Calories burned (optional)',
                hintText: 'No health data — enter manually',
              ),
              onChanged: (_) {
                _caloriesFromHealth = false;
                _emitChange();
              },
            ),
            if (_caloriesFromHealth)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Synced from health app',
                  key: const Key('calories-from-health-hint'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Meals', style: Theme.of(context).textTheme.titleSmall),
                TextButton.icon(
                  key: const Key('add-meal-button'),
                  onPressed: _addMeal,
                  icon: const Icon(Icons.add),
                  label: const Text('Add meal'),
                ),
              ],
            ),
            if (_meals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No meals logged yet.'),
              )
            else
              for (var i = 0; i < _meals.length; i++)
                ListTile(
                  key: Key('meal-row-$i'),
                  contentPadding: EdgeInsets.zero,
                  leading: _meals[i].photoPath == null
                      ? null
                      : PhotoThumbnail(
                          key: Key('meal-row-photo-$i'),
                          photoPath: _meals[i].photoPath!,
                          size: 40,
                        ),
                  title: Text(_meals[i].name),
                  subtitle: Text(
                    '${mealTypeLabel(_meals[i].mealType)} · ${portionSizeLabel(_meals[i].portion)} · '
                    '~${_meals[i].calories} kcal',
                  ),
                  onTap: () => _editMeal(i),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('edit-meal-$i'),
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editMeal(i),
                      ),
                      IconButton(
                        key: Key('remove-meal-$i'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeMeal(i),
                      ),
                    ],
                  ),
                ),
            const Divider(),
            Text(
              'Total calories eaten: ~$_totalCalories kcal',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Add/edit meal dialog. Passing [initialMeal] switches it into edit mode:
/// fields are pre-filled and the result preserves the meal's original [id]
/// so the caller can replace it in place rather than appending a new one.
class _MealDialog extends StatefulWidget {
  const _MealDialog({this.initialMeal, required this.photoStorage});

  final Meal? initialMeal;
  final PhotoStorage photoStorage;

  bool get isEditing => initialMeal != null;

  @override
  State<_MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<_MealDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;
  late MealType _mealType;
  late PortionSize _portion;
  String? _nameError;
  String? _caloriesError;

  // The calorie estimate normalized to a "regular" portion — the reference
  // point that suggestions are scaled from when the portion changes. Kept
  // separate from the (possibly user-overridden) displayed value so repeated
  // portion switches don't drift from compounding rounding.
  double _baseCalories = 0;

  // AI food detection is an optional convenience (IMPLEMENTATION_PLAN_UX_
  // POLISH.md §2) — manual entry below always works on its own regardless of
  // this state.
  bool _detecting = false;

  // The photo this meal was logged from, already copied into app storage.
  // Kept independently of the detection result: the photo belongs to the user
  // whether or not the AI managed to recognise what was on the plate.
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMeal;
    _photoPath = initial?.photoPath;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _caloriesController = TextEditingController(text: initial?.calories.toString() ?? '');
    _mealType = initial?.mealType ?? MealType.breakfast;
    _portion = initial?.portion ?? PortionSize.regular;
    _baseCalories = initial == null ? 0 : initial.calories / initial.portion.calorieMultiplier;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _onCaloriesEdited(String text) {
    final parsed = int.tryParse(text.trim());
    if (parsed != null) {
      _baseCalories = parsed / _portion.calorieMultiplier;
    }
  }

  void _onPortionChanged(PortionSize portion) {
    setState(() {
      _portion = portion;
      if (_baseCalories > 0) {
        _caloriesController.text = (_baseCalories * portion.calorieMultiplier).round().toString();
      }
    });
  }

  /// Optional photo → detected name + calorie pre-fill. Never blocks: a
  /// denied permission, no camera, a cancelled picker, or a failed/null
  /// detection all fall back silently to manual entry, which always works on
  /// its own.
  Future<void> _detectFromPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              key: const Key('detect-photo-camera'),
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              key: const Key('detect-photo-gallery'),
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
      if (picked == null || !mounted) return; // user backed out of the OS picker

      final sizeError = validatePhotoSize(await picked.length());
      if (sizeError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sizeError)));
        return;
      }

      setState(() => _detecting = true);

      // Copy first, then detect from the stored copy — the picker's own path
      // lives in an evictable cache directory.
      final stored = await widget.photoStorage.savePhoto(picked);
      if (!mounted) return;
      setState(() => _photoPath = stored);

      final detected = await foodDetectionService.detectFromImage(stored);
      if (!mounted) return;

      if (detected == null) {
        // The photo stays attached regardless. A failed guess is no reason to
        // throw away the user's picture — this is also what makes the button
        // usable as a plain "attach a food photo" upload.
        setState(() => _detecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't detect food from that photo — enter it manually.")),
        );
        return;
      }

      setState(() {
        _detecting = false;
        _nameController.text = detected.name;
        _caloriesController.text = detected.estimatedCalories.toString();
        _baseCalories = detected.estimatedCalories / _portion.calorieMultiplier;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _detecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't access photos — you can still enter the meal manually.")),
      );
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final nameError = validateMealName(name);

    // Blank calories defaults to 0 automatically — the user is never forced
    // to type it. Anything else must parse as a non-negative number.
    final caloriesText = _caloriesController.text.trim();
    int calories = 0;
    String? caloriesError;
    if (caloriesText.isNotEmpty) {
      final parsed = int.tryParse(caloriesText);
      if (parsed == null) {
        caloriesError = 'Please enter a valid number.';
      } else {
        calories = parsed;
        caloriesError = validateMealCalories(parsed);
      }
    }

    setState(() {
      _nameError = nameError;
      _caloriesError = caloriesError;
    });
    if (nameError != null || caloriesError != null) return;

    Navigator.pop(
      context,
      Meal(
        id: widget.initialMeal?.id ?? 'meal-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        calories: calories,
        mealType: _mealType,
        portion: _portion,
        photoPath: _photoPath,
      ),
    );
  }

  void _removePhoto() {
    final removed = _photoPath;
    setState(() => _photoPath = null);

    // Only delete a copy made during *this* dialog session. The meal's already
    // persisted photo has to survive, because the user can still cancel out of
    // here and leave that meal exactly as it was.
    if (removed != null && removed != widget.initialMeal?.photoPath) {
      unawaited(widget.photoStorage.deletePhoto(removed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return AlertDialog(
      // This form is tall — name, photo, calories, portion, meal type — and a
      // phone in landscape leaves a dialog barely 200 logical pixels high.
      // Without this it overflows the bottom and the Add button is unreachable.
      scrollable: true,
      title: Text(widget.isEditing ? 'Edit meal' : 'Add meal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('meal-name-field'),
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Meal name'),
            autofocus: true,
          ),
          if (_nameError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_nameError!, style: TextStyle(color: errorColor)),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('detect-from-photo-button'),
              onPressed: _detecting ? null : _detectFromPhoto,
              icon: _detecting
                  ? const SizedBox(
                      key: Key('detect-from-photo-loading'),
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(_detecting ? 'Detecting…' : 'Detect from photo'),
            ),
          ),
          if (_photoPath != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: PhotoThumbnail(
                  key: const Key('meal-photo-thumbnail'),
                  photoPath: _photoPath!,
                  size: 72,
                  onRemove: _removePhoto,
                  removeButtonKey: const Key('remove-meal-photo'),
                ),
              ),
            ),
          TextField(
            key: const Key('meal-calories-field'),
            controller: _caloriesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Calories'),
            onChanged: _onCaloriesEdited,
          ),
          if (_caloriesError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_caloriesError!, style: TextStyle(color: errorColor)),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Portion', style: Theme.of(context).textTheme.labelMedium),
          ),
          const SizedBox(height: 4),
          SegmentedButton<PortionSize>(
            key: const Key('meal-portion-selector'),
            segments: [
              for (final size in PortionSize.values)
                ButtonSegment(value: size, label: Text(portionSizeLabel(size))),
            ],
            selected: {_portion},
            onSelectionChanged: (selected) => _onPortionChanged(selected.first),
          ),
          const SizedBox(height: 8),
          DropdownButton<MealType>(
            value: _mealType,
            isExpanded: true,
            items: [
              for (final type in MealType.values)
                DropdownMenuItem(value: type, child: Text(mealTypeLabel(type))),
            ],
            onChanged: (value) => setState(() => _mealType = value ?? _mealType),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-meal-button'),
          onPressed: _submit,
          child: Text(widget.isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
