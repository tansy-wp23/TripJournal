import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/admin_repository_locator.dart';
import '../../../models/admin_audit_log.dart';
import '../../../models/profile.dart';
import '../../journal/widgets/format_utils.dart';
import '../admin_format_utils.dart';
import '../controller/admin_auth_controller.dart';
import '../controller/admin_user_detail_controller.dart';
import '../widgets/reactivate_confirmation_dialog.dart';
import '../widgets/suspend_confirmation_dialog.dart';

/// PB-03's detail half: shows one user's full profile plus their status
/// history (`AdminAuditLog`) and sign-in-attempt history
/// (`AdminAccessAttemptLog`). PB-04/PB-05 (Phase 5): suspend/reactivate
/// actions, gated by the validation decisions recorded in
/// `docs/admin/PROGRESS.md` ("Phase 5 validation decisions").
///
/// A `ConsumerStatefulWidget` (not a plain `StatefulWidget`) — needs
/// `ref.read(adminAuthControllerProvider)` to know which admin is acting,
/// for `AdminAccountActionsRepository`'s `adminUserId` param.
/// `AdminUserDetailController` is still constructed locally per-instance
/// rather than resolved from a global Riverpod provider; see that
/// controller's doc comment for why.
class AdminUserDetailScreen extends ConsumerStatefulWidget {
  const AdminUserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  late final AdminUserDetailController _controller = AdminUserDetailController(
    adminUserDirectoryRepository,
    adminAuditLogRepository,
    adminAccessAttemptLogRepository,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.load(widget.userId);
  }

  void _onControllerChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// PB-04. Phase 5 validation decisions (`docs/admin/PROGRESS.md`):
  /// admin-on-admin suspension is blocked entirely (enforced primarily by
  /// `_AccountActionsSection` not showing the button at all — this repeats
  /// the check as defense-in-depth against a stale screen); an
  /// already-suspended target is rejected with a message, not silently
  /// no-op'd; a reason is required (enforced by the dialog itself).
  Future<void> _suspend(Profile target) async {
    final admin = ref.read(adminAuthControllerProvider).profile;
    if (admin == null) return; // shouldn't happen — screen requires an authenticated admin

    if (target.role == UserRole.admin) {
      _showMessage("Administrator accounts can't be suspended from here.");
      return;
    }
    if (target.isSuspended) {
      _showMessage('${target.displayName} is already suspended.');
      return;
    }

    final reason =
        await showSuspendConfirmationDialog(context, targetDisplayName: target.displayName);
    if (reason == null || !mounted) return; // cancelled

    try {
      await adminAccountActionsRepository.suspendUser(
        adminUserId: admin.userID,
        targetUserId: target.userID,
        reason: reason,
      );
      await _controller.load(widget.userId);
      _showMessage('${target.displayName} has been suspended.');
    } catch (e) {
      _showMessage('Could not suspend this account: $e');
    }
  }

  /// PB-05. Same defense-in-depth pattern as [_suspend]: a target that
  /// isn't currently suspended is rejected with a message rather than
  /// silently no-op'd.
  Future<void> _reactivate(Profile target) async {
    final admin = ref.read(adminAuthControllerProvider).profile;
    if (admin == null) return;

    if (!target.isSuspended) {
      _showMessage('${target.displayName} is not suspended.');
      return;
    }

    final confirmed =
        await showReactivateConfirmationDialog(context, targetDisplayName: target.displayName);
    if (!confirmed || !mounted) return;

    try {
      await adminAccountActionsRepository.reactivateUser(
        adminUserId: admin.userID,
        targetUserId: target.userID,
      );
      await _controller.load(widget.userId);
      _showMessage('${target.displayName} has been reactivated.');
    } catch (e) {
      _showMessage('Could not reactivate this account: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Details')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.loading && _controller.profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.error != null && _controller.profile == null) {
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
            Text(
              _controller.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('admin-user-detail-retry'),
              onPressed: () => _controller.load(widget.userId),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final profile = _controller.profile;
    if (profile == null) return const SizedBox.shrink();

    return ListView(
      key: const Key('admin-user-detail-content'),
      padding: const EdgeInsets.all(16),
      children: [
        _ProfileHeader(profile: profile),
        const SizedBox(height: 16),
        _AccountActionsSection(
          profile: profile,
          onSuspend: () => _suspend(profile),
          onReactivate: () => _reactivate(profile),
        ),
        const SizedBox(height: 24),
        Text('Status history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_controller.auditHistory.isEmpty)
          const Text('No status changes recorded.')
        else
          ..._controller.auditHistory.map((entry) => _AuditLogTile(entry: entry)),
        const SizedBox(height: 24),
        Text('Admin sign-in attempts', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Times this account tried to sign in through the admin portal '
          'without administrator access.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (_controller.accessAttempts.isEmpty)
          const Text('No attempts recorded.')
        else
          ..._controller.accessAttempts.map(
            (attempt) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.warning_amber,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(accessAttemptReasonLabel(attempt.reason)),
              subtitle: Text(formatRelativeTime(attempt.createdAt)),
            ),
          ),
      ],
    );
  }
}

/// PB-04/PB-05's actual "entry points" — see `docs/admin/PROGRESS.md`
/// Phase 5 for the validation decisions this reflects. Admin-on-admin and
/// self-service-deactivated accounts get an explanatory note instead of a
/// button, rather than a disabled button with no explanation.
class _AccountActionsSection extends StatelessWidget {
  const _AccountActionsSection({
    required this.profile,
    required this.onSuspend,
    required this.onReactivate,
  });

  final Profile profile;
  final VoidCallback onSuspend;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    if (profile.role == UserRole.admin) {
      return Text(
        "Administrator accounts can't be suspended from here.",
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    if (profile.status == AccountStatus.deactivated) {
      return Text(
        'This account was deactivated by the user. Only they can '
        'reactivate it by signing in again — an administrator suspension '
        'is a separate status.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    if (profile.isSuspended) {
      return FilledButton.icon(
        key: const Key('admin-reactivate-button'),
        onPressed: onReactivate,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Reactivate account'),
      );
    }
    return FilledButton.tonalIcon(
      key: const Key('admin-suspend-button'),
      style: FilledButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      onPressed: onSuspend,
      icon: const Icon(Icons.block),
      label: const Text('Suspend account'),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundImage:
              profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
          child: profile.avatarUrl == null
              ? Text(
                  profile.displayName.isNotEmpty
                      ? profile.displayName[0].toUpperCase()
                      : '?',
                  style: theme.textTheme.headlineSmall,
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.displayName, style: theme.textTheme.titleLarge),
              Text(profile.email, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(profile.role == UserRole.admin ? 'Administrator' : 'Traveler')),
                  Chip(
                    label: Text(_statusLabel(profile.status)),
                    backgroundColor: _statusColor(context, profile.status),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Joined ${formatDate(profile.createdAt)}', style: theme.textTheme.bodySmall),
              Text(
                profile.lastLoginAt == null
                    ? 'Never signed in'
                    : 'Last signed in ${formatDate(profile.lastLoginAt!)}',
                style: theme.textTheme.bodySmall,
              ),
              if (profile.deactivatedAt != null)
                Text(
                  '${_statusLabel(profile.status)} on ${formatDate(profile.deactivatedAt!)}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
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

  Color? _statusColor(BuildContext context, AccountStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case AccountStatus.active:
        return null; // default chip color is enough for the common case
      case AccountStatus.suspended:
        return scheme.errorContainer;
      case AccountStatus.deactivated:
        return scheme.surfaceContainerHighest;
    }
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.entry});

  final AdminAuditLog entry;

  @override
  Widget build(BuildContext context) {
    // This screen only ever loads targetType: user history (see
    // AdminUserDetailController.load), so the issue-related cases in
    // adminActionLabel/adminActionIcon aren't reachable here in practice —
    // but both stay exhaustive now that AdminAction covers both target
    // types (Sprint 2, Phase 8 — docs/admin/PROGRESS.md).
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(adminActionIcon(entry.action)),
      title: Text(adminActionLabel(entry.action)),
      subtitle: Text(
        entry.reason == null
            ? formatRelativeTime(entry.createdAt)
            : '${entry.reason} · ${formatRelativeTime(entry.createdAt)}',
      ),
    );
  }
}
