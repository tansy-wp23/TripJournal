import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/admin_repository_locator.dart';
import '../../../data/admin_user_directory_repository.dart';
import '../../../models/profile.dart';

/// PB-03: Search and View User (the search half). Debounces search input
/// and exposes loading/error/results state for `AdminUserListScreen`.
///
/// Debouncing lives here rather than in the search field widget (contrast
/// `JournalSearchBar`, which debounces itself) since the plan names
/// "search debouncing" as this controller's job.
///
/// Also supports a status/role/"new this week" filter, layered on top of
/// the text search rather than a repository-level concern —
/// `AdminUserDirectoryRepository.searchUsers` only takes a text query, so
/// the filter is applied client-side to whatever that call returns. Added
/// so `AdminDashboardScreen`'s stat cards can navigate to a pre-filtered
/// view (e.g. "Suspended" → only suspended users) instead of always
/// dropping into the same unfiltered list.
class AdminUserManagementController extends ChangeNotifier {
  AdminUserManagementController(this._directoryRepository);

  final AdminUserDirectoryRepository _directoryRepository;

  static const Duration _debounceDuration = Duration(milliseconds: 300);

  String _query = '';
  List<Profile> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  AccountStatus? _statusFilter;
  UserRole? _roleFilter;
  bool _newThisWeekOnly = false;

  // Guards against an older, slower search response overwriting a newer
  // one's results — mirrors `TripController`'s `_loadGeneration` pattern.
  int _searchGeneration = 0;

  String get query => _query;
  List<Profile> get results => _results;
  bool get loading => _loading;
  String? get error => _error;
  AccountStatus? get statusFilter => _statusFilter;
  UserRole? get roleFilter => _roleFilter;
  bool get newThisWeekOnly => _newThisWeekOnly;
  bool get hasActiveFilter =>
      _statusFilter != null || _roleFilter != null || _newThisWeekOnly;

  /// Loads the full user directory (empty query) — call once when the
  /// screen first opens.
  Future<void> loadAll() => _search(_query);

  /// Called on every keystroke. Debounces before actually searching, so
  /// rapid typing doesn't fire a request per character.
  void setQuery(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => _search(value));
  }

  /// Searches immediately, bypassing the debounce — used by the search
  /// field's "clear" action, where there's no reason to wait.
  void clearQuery() {
    _debounce?.cancel();
    _query = '';
    _search('');
  }

  /// Applies a status/role/"new this week" filter on top of the current
  /// text query and reloads. Pass no arguments (or all null/false) to
  /// clear back to an unfiltered view.
  Future<void> setFilter({AccountStatus? status, UserRole? role, bool newThisWeek = false}) {
    _statusFilter = status;
    _roleFilter = role;
    _newThisWeekOnly = newThisWeek;
    return _search(_query);
  }

  Future<void> clearFilter() => setFilter();

  Future<void> _search(String value) async {
    final generation = ++_searchGeneration;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _directoryRepository.searchUsers(query: value);
      if (generation != _searchGeneration) return; // superseded by a newer search
      _results = _applyFilter(results);
    } catch (e) {
      if (generation != _searchGeneration) return;
      _error = 'Could not search users: $e';
    } finally {
      if (generation == _searchGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  List<Profile> _applyFilter(List<Profile> profiles) {
    var filtered = profiles;
    if (_statusFilter != null) {
      filtered = filtered.where((p) => p.status == _statusFilter).toList();
    }
    if (_roleFilter != null) {
      filtered = filtered.where((p) => p.role == _roleFilter).toList();
    }
    if (_newThisWeekOnly) {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      filtered = filtered.where((p) => p.createdAt.isAfter(weekAgo)).toList();
    }
    return filtered;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// The single place the app resolves its [AdminUserManagementController]
/// from — mirrors `adminDashboardControllerProvider`.
final adminUserManagementControllerProvider =
    ChangeNotifierProvider<AdminUserManagementController>(
  (ref) => AdminUserManagementController(adminUserDirectoryRepository),
);
