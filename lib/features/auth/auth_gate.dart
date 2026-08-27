import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/app_splash.dart';
import '../guest/guest_home_screen.dart';
import '../home/home_screen.dart';
import '../profile/screens/profile_onboarding_screen.dart';
import 'controller/auth_controller.dart';
import 'screens/admin_account_screen.dart';
import 'screens/reactivation_screen.dart';
import 'screens/suspended_screen.dart';

/// Never routes to `LoginScreen` directly — a first-time launch or a
/// just-logged-out user resolves to [AuthStatus.guest] and lands on
/// [GuestHomeScreen] (read-only community browsing). `LoginScreen` is only
/// reached by an explicit prompt from there: the profile affordance, or a
/// gated action requiring a real account. See `AuthStatus`'s doc comment.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider).status;

    switch (status) {
      case AuthStatus.guest:
        return const GuestHomeScreen();
      case AuthStatus.loading:
        // Carries the native launch screen's artwork through until the session
        // resolves, so there is no blank frame between the two.
        return const AppSplash();
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.needsOnboarding:
        return const ProfileOnboardingScreen();
      case AuthStatus.deactivated:
        return const ReactivationScreen();
      case AuthStatus.suspended:
        return const SuspendedScreen();
      case AuthStatus.adminAccount:
        return const AdminAccountScreen();
    }
  }
}