import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_screen.dart';
import 'controller/auth_controller.dart';
import 'screens/login_screen.dart';
import 'screens/reactivation_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider).status;

    switch (status) {
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.deactivated:
        return const ReactivationScreen();
    }
  }
}