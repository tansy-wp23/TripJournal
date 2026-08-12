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
class AdminUserManagementController extends ChangeNotifier {
  AdminUserManagementController(this._directoryRepository);

  final AdminUserDirectoryRepository _directoryRepository;

  static const Duration _debounceDuration = Duration(milliseconds: 300);

  String _query = '';
  List<Profile> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  // Guards against an older, slower search response overwriting a newer
  // one's results — mirrors `TripController`'s `_loadGeneration` pattern.
  int _searchGeneration = 0;

  String get query => _query;
  List<Profile> get results => _results;
  bool get loading => _loading;
  String? get error => _error;

  /// Loads the full user directory (empty query) — call once when the
  /// screen first opens.
  Future<void> loadAll() => _search('');

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

  Future<void> _search(String value) async {
    final generation = ++_searchGeneration;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _directoryRepository.searchUsers(query: value);
      if (generation != _searchGeneration) return; // superseded by a newer search
      _results = results;
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
