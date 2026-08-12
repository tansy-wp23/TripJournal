import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/data/mock_verification_code_repository.dart';
import 'package:tripjournal/features/auth/auth_gate.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';
import 'package:tripjournal/features/auth/screens/login_screen.dart';
import 'package:tripjournal/features/auth/screens/suspended_screen.dart';
import 'package:tripjournal/models/profile.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockProfileRepository profileRepository;
  late MockVerificationCodeRepository verificationCodeRepository;
  late MockAccountLifecycleRepository lifecycleRepository;

  setUp(() {
    authRepository = MockAuthRepository();
    profileRepository = MockProfileRepository(state: MockProfileState.active);
    verificationCodeRepository = MockVerificationCodeRepository();
    lifecycleRepository = MockAccountLifecycleRepository(
      profileRepository: profileRepository,
      verificationCodeRepository: verificationCodeRepository,
    );
  });

  Widget wrapped() {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          (ref) => AuthController(authRepository, profileRepository, lifecycleRepository),
        ),
      ],
      child: const MaterialApp(home: AuthGate()),
    );
  }

  group('AuthGate routes a suspended profile to SuspendedScreen', () {
    testWidgets('signing in as an already-suspended profile shows '
        'SuspendedScreen, not HomeScreen', (tester) async {
      final existing = (await profileRepository.getProfile('user-001'))!;
      await profileRepository.updateProfile(
        existing.copyWith(status: AccountStatus.suspended),
      );

      await tester.pumpWidget(wrapped());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sign-in-with-google')));
      await tester.pumpAndSettle();

      expect(find.byType(SuspendedScreen), findsOneWidget);
      expect(find.text('Account Suspended'), findsOneWidget);
    });

    testWidgets('tapping "Sign out" on SuspendedScreen returns to '
        'LoginScreen', (tester) async {
      final existing = (await profileRepository.getProfile('user-001'))!;
      await profileRepository.updateProfile(
        existing.copyWith(status: AccountStatus.suspended),
      );

      await tester.pumpWidget(wrapped());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sign-in-with-google')));
      await tester.pumpAndSettle();
      expect(find.byType(SuspendedScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('suspended-sign-out')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SuspendedScreen), findsNothing);
    });
  });
}
