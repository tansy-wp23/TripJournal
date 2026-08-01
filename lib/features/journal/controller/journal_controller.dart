import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/journal_repository.dart';
import '../../../data/repository_locator.dart';
import '../../../models/journal_entry.dart';
import '../../../models/trip.dart';
import '../../../validation/journal_entry_validation.dart';
import '../../../validation/meal_validation.dart';
import '../../../validation/steps_validation.dart';
import '../ai/daily_advice_locator.dart';
import '../ai/daily_advice_service.dart';
import '../journal_filter.dart';

class JournalController extends ChangeNotifier {
  JournalController(this._repository, this._dailyAdviceService);

  final JournalRepository _repository;
  final DailyAdviceService _dailyAdviceService;

  String? _tripId;
  List<JournalEntry> _entries = [];
  bool _loading = false;
  String? _error;
  JournalFilter _filter = const JournalFilter();

  List<JournalEntry> get entries => _entries;
  bool get loading => _loading;
  String? get error => _error;

  /// Current search/filter criteria (IMPLEMENTATION_PLAN_EXTRA_FEATURES.md
  /// #2). View-only — never mutates or persists [_entries].
  JournalFilter get filter => _filter;

  /// [entries] narrowed by [filter]. Equal to [entries] when the filter is
  /// inactive, so callers can always render this instead of [entries]
  /// without special-casing the unfiltered case.
  List<JournalEntry> get filteredEntries =>
      filterJournalEntries(_entries, _filter);

  void setFilter(JournalFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void clearFilter() {
    _filter = const JournalFilter();
    notifyListeners();
  }

  Future<void> loadEntries(String tripId) async {
    // Switching trips should never carry a stale search/filter over.
    if (_tripId != null && _tripId != tripId) _filter = const JournalFilter();
    _tripId = tripId;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await _repository.getEntries(tripId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Validates [entry] against the rules in IMPLEMENTATION_PLAN_VALIDATION.md
  /// and returns the first error message, or null if it's valid. Lives here
  /// — not just in the create/edit screen — so it holds regardless of how
  /// save is triggered. [checkDate] should only be true for NEW entries:
  /// editing never changes an entry's day, so re-validating an unrelated
  /// field edit against dates that may have shifted since creation would be
  /// a usability harm, not a real invariant.
  String? _validateEntry(
    JournalEntry entry, {
    required bool checkDate,
    Trip? trip,
  }) {
    final contentError = validateEntryContent(entry.title, entry.body);
    if (contentError != null) return contentError;

    final titleError = validateEntryTitleLength(entry.title);
    if (titleError != null) return titleError;

    final bodyError = validateEntryBodyLength(entry.body);
    if (bodyError != null) return bodyError;

    final totalTextError = validateEntryTotalTextLength(
      entry.title,
      entry.body,
    );
    if (totalTextError != null) return totalTextError;

    final healthLog = entry.healthLog;
    if (healthLog != null) {
      final stepsError = validateSteps(healthLog.steps);
      if (stepsError != null) return stepsError;

      for (final meal in healthLog.meals) {
        final nameError = validateMealName(meal.name);
        if (nameError != null) return nameError;
        final caloriesError = validateMealCalories(meal.calories);
        if (caloriesError != null) return caloriesError;
      }
    }

    if (checkDate) {
      final dateError = validateEntryDate(
        entry.createdAt,
        now: DateTime.now(),
        trip: trip,
      );
      if (dateError != null) return dateError;
    }

    return null;
  }

  /// Validates [entry] without persisting anything — lets the UI gate a
  /// save-confirmation dialog on validity first (IMPLEMENTATION_PLAN_UX_
  /// POLISH.md §5: only a *valid* save should prompt "Save changes?").
  /// [create]/[edit] always re-validate internally regardless — this is a
  /// UX pre-check, never a substitute for that authoritative backstop.
  String? validate(JournalEntry entry, {required bool checkDate, Trip? trip}) {
    return _validateEntry(entry, checkDate: checkDate, trip: trip);
  }

  /// Creates [entry], or returns a validation/save error message without
  /// persisting anything. Pass [trip] when known so the entry-date-within-
  /// trip-range rule can be checked.
  ///
  /// Does NOT generate AI advice — see [generateAndAttachAdvice]. Persisting
  /// and advice generation are deliberately separate steps (IMPLEMENTATION_
  /// PLAN_UX_AI.md §3): the save must complete and stay visible immediately,
  /// with the (possibly slower, real-API-backed later) advice call following
  /// afterward with its own loading state.
  Future<String?> create(JournalEntry entry, {Trip? trip}) async {
    final validationError = _validateEntry(entry, checkDate: true, trip: trip);
    if (validationError != null) return validationError;

    _error = null;
    try {
      await _repository.addEntry(entry);
      await _refresh();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error;
    }
  }

  /// Edits [entry], or returns a validation/save error message without
  /// persisting anything. Does NOT generate AI advice — see [create].
  Future<String?> edit(JournalEntry entry) async {
    final validationError = _validateEntry(entry, checkDate: false);
    if (validationError != null) return validationError;

    _error = null;
    try {
      await _repository.updateEntry(entry);
      await _refresh();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return _error;
    }
  }

  /// Runs [entry]'s day (meals/steps/mood) through [DailyAdviceService] and
  /// persists the result into `healthLog.aiAdvice`. Returns the generated
  /// advice text, or null if generation/persistence failed — the caller
  /// should offer a retry rather than losing the (already-saved) entry.
  ///
  /// Skips the screen-level validation in [create]/[edit] on purpose: by the
  /// time this runs, [entry] was already successfully saved once; this call
  /// only attaches generated content, it doesn't change anything the user
  /// typed.
  Future<String?> generateAndAttachAdvice(JournalEntry entry) async {
    final healthLog = entry.healthLog;
    if (healthLog == null) return null;

    try {
      final advice = await _dailyAdviceService.adviceFor(
        meals: healthLog.meals,
        steps: healthLog.steps,
        mood: entry.mood,
        caloriesEaten: healthLog.caloriesEaten,
        caloriesBurned: healthLog.caloriesBurned,
      );
      await _repository.updateEntry(
        entry.copyWith(healthLog: healthLog.copyWith(aiAdvice: advice)),
      );
      await _refresh();
      return advice;
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String id) async {
    _error = null;
    try {
      await _repository.deleteEntry(id);
      await _refresh();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _refresh() async {
    final tripId = _tripId;
    if (tripId == null) return;
    _entries = await _repository.getEntries(tripId);
    notifyListeners();
  }
}

/// The single place the app resolves its [JournalController] from — mirrors
/// the repository/service locators so the wiring stays in one spot.
final journalControllerProvider = ChangeNotifierProvider<JournalController>(
  (ref) => JournalController(journalRepository, dailyAdviceService),
);
