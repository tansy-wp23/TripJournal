import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tripjournal/data/mock_account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/data/mock_verification_code_repository.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';

/// Owns the mock-auth resources used by a widget test.
final class AuthTestHarness {
  AuthTestHarness({
    MockProfileState profileState = MockProfileState.active,
    MockVerificationCodeRepository? verificationRepository,
  }) : authRepository = MockAuthRepository(),
       profileRepository = MockProfileRepository(state: profileState),
       verificationRepository =
           verificationRepository ?? MockVerificationCodeRepository() {
    lifecycleRepository = MockAccountLifecycleRepository(
      profileRepository: profileRepository,
      verificationCodeRepository: this.verificationRepository,
    );
    controller = AuthController(
      authRepository,
      profileRepository,
      lifecycleRepository,
    );
  }

  final MockAuthRepository authRepository;
  final MockProfileRepository profileRepository;
  final MockVerificationCodeRepository verificationRepository;
  late final MockAccountLifecycleRepository lifecycleRepository;
  late final AuthController controller;

  Widget wrap(Widget home) => ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        (ref) => controller,
        disposeNotifier: false,
      ),
    ],
    child: MaterialApp(home: home),
  );

  Future<void> signIn() => controller.signInWithGoogle();

  /// Waits for a separate stream subscription to observe the signed-out event.
  Future<void> signOut() async {
    final signedOut = authRepository.authStateChanges().firstWhere(
      (session) => !session.isSignedIn,
    );
    await controller.signOut();
    await signedOut;
  }

  Future<void> dispose() async {
    controller.dispose();
    await authRepository.dispose();
  }
}
