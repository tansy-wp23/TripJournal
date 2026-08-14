import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/app_splash.dart';
import '../home/home_screen.dart';
import 'controller/auth_controller.dart';
import 'screens/login_screen.dart';
import 'screens/reactivation_screen.dart';
import 'screens/suspended_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider).status;

    switch (status) {
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.loading:
        // Carries the native launch screen's artwork through until the session
        // resolves, so there is no blank frame between the two.
        return const AppSplash();
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.deactivated:
        return const ReactivationScreen();
      case AuthStatus.suspended:
        return const SuspendedScreen();
    }
  }
}