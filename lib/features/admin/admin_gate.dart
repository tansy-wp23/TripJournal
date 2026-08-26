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
    final controller = ref.watch(adminAuthControllerProvider);
    final status = controller.status;

    // Found and fixed 2026-08-26, alongside `AdminAuthController._rejectAndSignOut`
    // (see its doc comment for the full "why"): a rejected admin attempt now
    // signs itself out immediately, so by the time this build sees it,
    // `status` has already moved on to `signedOut` — there's nothing left
    // to show *on this screen*. Instead, pop back to whatever's underneath
    // (the traveler side) and relay the rejection there as a SnackBar,
    // rather than leaving the user to notice the error and back out
    // manually. `consumePendingRejection()` is one-shot specifically so a
    // later rebuild of this same build method (anything else this widget
    // watches changing) doesn't pop a second time.
    //
    // Capture the Navigator/ScaffoldMessenger *states* now, not `context` —
    // by the time the post-frame callback runs, this widget's own route has
    // popped and `context` is no longer valid, but these State objects live
    // above the Navigator and stay mounted regardless.
    if (controller.hasPendingRejection) {
      final message = controller.consumePendingRejection();
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator.maybePop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      });
    }

    // This screen is reached via a `Navigator.push` from the traveler
    // `LoginScreen`'s hidden logo-tap entry, which leaves that screen's
    // route alive underneath this one. Admin sign-in shares the same
    // Supabase session as the traveler side (`adminAuthRepository` is an
    // alias for `authRepository`), so once a sign-in attempt has *succeeded*
    // as a real account, the route underneath silently becomes whatever the
    // traveler `AuthGate` now resolves to (often `HomeScreen`, not the
    // `LoginScreen` it was when this route was pushed).
    //
    // Only `authenticated` blocks back, though — not `unauthorized`. Found
    // and fixed 2026-08-26: blocking `unauthorized` too (the original
    // version of this guard) trapped anyone who attempted admin sign-in
    // with a real, non-admin account. `AdminLoginScreen` (what `unauthorized`
    // renders) has no sign-out affordance of its own — only "Sign in with
    // Google" — so "Log out to leave the admin portal" was an instruction
    // with no way to follow it. `authenticated` doesn't have this problem:
    // `AdminDashboardScreen` has a real "Log out" button, so the message
    // points somewhere that actually exists. And landing back on the
    // traveler side after a rejected attempt isn't a leak worth blocking
    // for — it's the same person's own, ordinary account either way.
    final canPop = status != AdminAuthStatus.authenticated;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Log out to leave the admin portal.'),
            ),
          );
      },
      child: switch (status) {
        AdminAuthStatus.signedOut ||
        AdminAuthStatus.unauthorized => const AdminLoginScreen(),
        AdminAuthStatus.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        AdminAuthStatus.authenticated => const AdminDashboardScreen(),
      },
    );
  }
}
