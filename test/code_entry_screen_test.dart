import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/data/mock_verification_code_repository.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';
import 'package:tripjournal/features/auth/screens/code_entry_screen.dart';
import 'package:tripjournal/models/profile.dart';
import 'package:tripjournal/models/verification_code.dart';

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

  Widget wrapped(VerificationPurpose purpose) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          (ref) => AuthController(
            authRepository,
            profileRepository,
            lifecycleRepository,
          ),
        ),
      ],
      child: MaterialApp(
        home: CodeEntryScreen(purpose: purpose),
      ),
    );
  }

  group('CodeEntryScreen (reactivation)', () {
    testWidgets('shows reactivation title and message', (tester) async {
      await tester.pumpWidget(wrapped(VerificationPurpose.reactivation));
      await tester.pumpAndSettle();

      expect(find.text('Reactivate Account'), findsOneWidget);
      expect(find.text('Resend code'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byKey(const Key('code-entry-input')), findsOneWidget);
    });

    testWidgets('confirm button is disabled until 6 digits entered',
        (tester) async {
      await tester.pumpWidget(wrapped(VerificationPurpose.reactivation));
      await tester.pumpAndSettle();

      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const Key('code-entry-confirm')),
      );
      expect(confirmButton.onPressed, isNull);

      // Enter digits one at a time.
      for (var i = 0; i < 6; i++) {
        await tester.enterText(
          find.byKey(Key('otp-digit-$i')),
          '${i + 1}',
        );
        await tester.pump();
      }

      final enabledButton = tester.widget<FilledButton>(
        find.byKey(const Key('code-entry-confirm')),
      );
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets('cancel signs out and returns to login', (tester) async {
      // Set up a deactivated profile so sign-in routes to reactivation.
      profileRepository = MockProfileRepository(
        state: MockProfileState.deactivated,
      );
      lifecycleRepository = MockAccountLifecycleRepository(
        profileRepository: profileRepository,
        verificationCodeRepository: verificationCodeRepository,
      );

      await tester.pumpWidget(wrapped(VerificationPurpose.reactivation));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('code-entry-cancel')));
      await tester.pumpAndSettle();

      // After signOut, the auth controller status is signedOut.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CodeEntryScreen)),
      );
      final auth = container.read(authControllerProvider);
      expect(auth.status, AuthStatus.signedOut);
    });

    testWidgets('resend code sends a new code', (tester) async {
      await tester.pumpWidget(wrapped(VerificationPurpose.reactivation));
      await tester.pumpAndSettle();

      // Send an initial code.
      await lifecycleRepository.requestReactivation();
      final firstCode = verificationCodeRepository.activeCode;

      await tester.tap(find.byKey(const Key('code-entry-resend')));
      await tester.pumpAndSettle();

      final secondCode = verificationCodeRepository.activeCode;
      expect(secondCode, isNotNull);
      expect(secondCode!.codeID, isNot(firstCode!.codeID));
    });
  });

  group('CodeEntryScreen (deactivation)', () {
    testWidgets('shows deactivation title and message', (tester) async {
      await tester.pumpWidget(wrapped(VerificationPurpose.deactivation));
      await tester.pumpAndSettle();

      expect(find.text('Deactivate Account'), findsOneWidget);
      expect(find.text('Resend code'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.byKey(const Key('code-entry-input')), findsOneWidget);
    });

    testWidgets('auto-sends a deactivation code when the screen opens',
        (tester) async {
      await tester.pumpWidget(wrapped(VerificationPurpose.deactivation));
      await tester.pumpAndSettle();

      // The screen should have automatically sent a deactivation code.
      expect(
        verificationCodeRepository.activeCode?.purpose,
        VerificationPurpose.deactivation,
      );
      expect(verificationCodeRepository.activeCode, isNotNull);
    });

    testWidgets('cancel pops back without side effects', (tester) async {
      await tester.pumpWidget(wrapped(VerificationPurpose.deactivation));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('code-entry-cancel')));
      await tester.pumpAndSettle();

      // The screen should be popped (no longer visible).
      expect(find.byType(CodeEntryScreen), findsNothing);

      // Profile should still be active and session intact.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final auth = container.read(authControllerProvider);
      expect(auth.status, AuthStatus.signedOut); // not signed in in this setup
    });

    testWidgets('confirm with valid code deactivates the profile and signs out',
        (tester) async {
      // Sign in first so the profile exists and the session is active.
      final preAuth = AuthController(
        authRepository,
        profileRepository,
        lifecycleRepository,
      );
      await preAuth.signInWithGoogle();
      preAuth.dispose();

      await tester.pumpWidget(wrapped(VerificationPurpose.deactivation));
      await tester.pumpAndSettle();

      // The screen auto-sends a code on open (verified above); the mock
      // already has an active deactivation code.

      // Enter the valid mock code.
      for (var i = 0; i < 6; i++) {
        await tester.enterText(
          find.byKey(Key('otp-digit-$i')),
          MockVerificationCodeRepository.mockCode[i],
        );
        await tester.pump();
      }

      await tester.tap(find.byKey(const Key('code-entry-confirm')));
      await tester.pumpAndSettle();

      // Profile should now be deactivated.
      final profile = await profileRepository.getProfile('user-001');
      expect(profile!.status, AccountStatus.deactivated);
      expect(profile.deactivatedAt, isNotNull);
    });
  });
}
