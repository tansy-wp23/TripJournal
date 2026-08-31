import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/profile.dart';
import '../../../widgets/app_content_toolbar.dart';
import '../controller/admin_user_management_controller.dart';
import 'admin_user_detail_screen.dart';

/// PB-03's search half: a debounced search field over
/// `AdminUserDirectoryRepository.searchUsers()`, reached either
/// unfiltered from `AdminDashboardScreen`'s "Manage users" action, or
/// pre-filtered from one of its stat cards (e.g. tapping "Suspended"
/// lands here showing only suspended users) — see
/// `AdminUserManagementController`'s filter support.
class AdminUserListScreen extends ConsumerStatefulWidget {
  const AdminUserListScreen({
    super.key,
    this.title = 'Manage Users',
    this.initialStatusFilter,
    this.initialRoleFilter,
    this.initialNewThisWeek = false,
    this.userDetailScreenBuilder,
  });

  final String title;
  final AccountStatus? initialStatusFilter;
  final UserRole? initialRoleFilter;
  final bool initialNewThisWeek;

  /// Test-only override for the screen pushed on tapping a user — see
  /// `AdminDashboardScreen.userDetailScreenBuilder`'s doc comment for why
  /// this exists.
  final Widget Function(String userId)? userDetailScreenBuilder;

  @override
  ConsumerState<AdminUserListScreen> createState() =>
      _AdminUserListScreenState();
}

class _AdminUserListScreenState extends ConsumerState<AdminUserListScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _loadInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    try {
      final controller = ref.read(
        adminUserManagementControllerProvider.notifier,
      );
      if (widget.initialStatusFilter != null ||
          widget.initialRoleFilter != null ||
          widget.initialNewThisWeek) {
        await controller.setFilter(
          status: widget.initialStatusFilter,
          role: widget.initialRoleFilter,
          newThisWeek: widget.initialNewThisWeek,
        );
      } else {
        await controller.loadAll();
      }
    } finally {
      _loadInProgress = false;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final management = ref.watch(adminUserManagementControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AppContentToolbar(
                resultLabel: '${management.results.length} users found',
                activeFilterLabel: management.hasActiveFilter
                    ? 'Directory filter active'
                    : null,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: TextField(
                      key: const Key('admin-user-search-field'),
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _textController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _textController.clear();
                                  ref
                                      .read(
                                        adminUserManagementControllerProvider
                                            .notifier,
                                      )
                                      .clearQuery();
                                  setState(() {});
                                },
                              ),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        ref
                            .read(
                              adminUserManagementControllerProvider.notifier,
                            )
                            .setQuery(value);
                        setState(() {});
                      },
                    ),
                  ),
                  if (management.hasActiveFilter)
                    Chip(
                      key: const Key('admin-user-filter-chip'),
                      label: Text('Filtered: ${widget.title}'),
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () => ref
                          .read(adminUserManagementControllerProvider.notifier)
                          .clearFilter(),
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody(context, management)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AdminUserManagementController management,
  ) {
    if (management.loading &&
        management.results.isEmpty &&
        management.error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (management.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(management.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('admin-user-search-retry'),
              onPressed: _loadAll,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (management.results.isEmpty) {
      final String message;
      if (management.query.isNotEmpty) {
        message = 'No users match "${management.query}".';
      } else if (management.hasActiveFilter) {
        message = 'No users match this filter.';
      } else {
        message = 'No users found.';
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            key: const Key('admin-user-search-empty-state'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('admin-user-search-results'),
      itemCount: management.results.length,
      itemBuilder: (context, index) {
        final profile = management.results[index];
        return _UserResultTile(
          profile: profile,
          userDetailScreenBuilder: widget.userDetailScreenBuilder,
        );
      },
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({required this.profile, this.userDetailScreenBuilder});

  final Profile profile;
  final Widget Function(String userId)? userDetailScreenBuilder;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: profile.avatarUrl != null
            ? NetworkImage(profile.avatarUrl!)
            : null,
        child: profile.avatarUrl == null
            ? Text(
                profile.displayName.isNotEmpty
                    ? profile.displayName[0].toUpperCase()
                    : '?',
              )
            : null,
      ),
      title: Text(profile.displayName),
      subtitle: Text('${profile.email} · ${_statusLabel(profile.status)}'),
      trailing: profile.role == UserRole.admin
          ? const Icon(Icons.admin_panel_settings)
          : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => userDetailScreenBuilder != null
              ? userDetailScreenBuilder!(profile.userID)
              : AdminUserDetailScreen(userId: profile.userID),
        ),
      ),
    );
  }

  String _statusLabel(AccountStatus status) {
    switch (status) {
      case AccountStatus.active:
        return 'Active';
      case AccountStatus.suspended:
        return 'Suspended';
      case AccountStatus.deactivated:
        return 'Deactivated';
    }
  }
}
