import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controller/admin_auth_controller.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_login_screen.dart';

/// Routes between `AdminLoginScreen` and `AdminDashboardScreen` on
/// `AdminAuthController.status` — mirrors `AuthGate`.
///
/// `unauthorized` renders the same `AdminLoginScreen` as `signedOut` (rather
/// than a separate "access denied" screen) since `AdminLoginScreen` already
/// surfaces `AdminAuthController.error` regardless of status, the same way
/// the traveler `LoginScreen` does — no dashboard access either way (Phase 2
/// Definition of Done).
class AdminGate extends ConsumerWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(adminAuthControllerProvider).status;

    switch (status) {
      case AdminAuthStatus.signedOut:
      case AdminAuthStatus.unauthorized:
        return const AdminLoginScreen();
      case AdminAuthStatus.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AdminAuthStatus.authenticated:
        return const AdminDashboardScreen();
    }
  }
}
