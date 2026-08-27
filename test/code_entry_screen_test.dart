import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_verification_code_repository.dart';
import 'package:tripjournal/data/verification_code_repository.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';
import 'package:tripjournal/features/auth/screens/code_entry_screen.dart';
import 'package:tripjournal/models/profile.dart';
import 'package:tripjournal/models/verification_code.dart';

import 'support/auth_test_harness.dart';

void main() {
  late AuthTestHarness harness;

  setUp(() async {
    harness = AuthTestHarness();
    await harness.signOut();
  });

  tearDown(() => harness.dispose());

  Widget wrapped(VerificationPurpose purpose) =>
      harness.wrap(CodeEntryScreen(purpose: purpose));

  group('CodeEntryScreen (reactivation)', () {
    testWidgets('shows reactivation title and message', (tester) async {
      await tester.pumpWidget(wrapped(VerificationPurpose.reactivation));
      await tester.pumpAndSettle();

      expect(find.text('Reactivate Account'), findsOneWidget);
      expect(find.text('Resend code'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byKey(const Key('code-entry-input')), findsOneWidget);
    });

    testWidgets('confirm button is disabled until 6 digits entered', (
      tester,
    ) async {
      await tester.pumpWidget(wrapped(VerificationPurpose.reactivation));
      await tester.pumpAndSettle();

      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const Key('code-entry-confirm')),
      );
      expect(confirmButton.onPressed, isNull);

      // Enter digits one at a time.
      for (var i = 0; i < 6; i++) {
        await tester.enterText(find.byKey(Key('otp-digit-$i')), '${i + 1}');
        await tester.pump();
      }

      final enabledButton = tester.widget<FilledButton>(
        find.byKey(const Key('code-entry-confirm')),
      );
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets('cancel signs out', (tester) async {
      await harness.signIn();
      await tester.pumpWidget(wrapped(VerificationPurpose.reactivation));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('code-entry-cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(harness.controller.status, AuthStatus.guest);
    });

    testWidgets('resend code sends a new code', (tester) async {
      await tester.pumpWidget(wrapped(VerificationPurpose.reactivation));
      await tester.pumpAndSettle();

      // Send an initial code.
      await harness.lifecycleRepository.requestReactivation();
      final firstCode = harness.verificationRepository.activeCode;

      await tester.tap(find.byKey(const Key('code-entry-resend')));
      await tester.pumpAndSettle();

      final secondCode = harness.verificationRepository.activeCode;
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

    testWidgets('auto-sends a deactivation code when the screen opens', (
      tester,
    ) async {
      await tester.pumpWidget(wrapped(VerificationPurpose.deactivation));
      await tester.pumpAndSettle();

      // The screen should have automatically sent a deactivation code.
      expect(
        harness.verificationRepository.activeCode?.purpose,
        VerificationPurpose.deactivation,
      );
      expect(harness.verificationRepository.activeCode, isNotNull);
    });

    testWidgets(
      'back returns to the previous route without auth side effects',
      (tester) async {
        await harness.signIn();
        final statusBeforeBack = harness.controller.status;
        await tester.pumpWidget(harness.wrap(const _CodeEntrySentinel()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-deactivation-code-entry')));
        await tester.pumpAndSettle();
        expect(find.byType(CodeEntryScreen), findsOneWidget);

        await tester.tap(find.byKey(const Key('code-entry-cancel')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(CodeEntryScreen), findsNothing);
        expect(find.byKey(const Key('code-entry-sentinel')), findsOneWidget);
        expect(harness.controller.status, statusBeforeBack);
      },
    );

    testWidgets(
      'confirm with valid code deactivates the profile and signs out',
      (tester) async {
        // Sign in first so the profile exists and the session is active.
        await harness.signIn();

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
        final profile = await harness.profileRepository.getProfile('user-001');
        expect(profile!.status, AccountStatus.deactivated);
        expect(profile.deactivatedAt, isNotNull);
      },
    );
  });

  group('CodeEntryScreen (friendly send errors)', () {
    testWidgets('shows a friendly rate-limit message on send', (tester) async {
      final failingRepo = _ThrowingVerificationCodeRepository(
        SendCodeFailureKind.rateLimited,
      );
      harness = AuthTestHarness(verificationRepository: failingRepo);
      await harness.signOut();

      await tester.pumpWidget(wrapped(VerificationPurpose.deactivation));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "You've requested a code too recently. Please wait about a minute and try again.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a friendly server-error message on send', (
      tester,
    ) async {
      final failingRepo = _ThrowingVerificationCodeRepository(
        SendCodeFailureKind.serverError,
      );
      harness = AuthTestHarness(verificationRepository: failingRepo);
      await harness.signOut();

      await tester.pumpWidget(wrapped(VerificationPurpose.deactivation));
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't send your code. Please try again in a moment."),
        findsOneWidget,
      );
    });

    testWidgets('shows a friendly network-error message on send', (
      tester,
    ) async {
      final failingRepo = _ThrowingVerificationCodeRepository(
        SendCodeFailureKind.networkError,
      );
      harness = AuthTestHarness(verificationRepository: failingRepo);
      await harness.signOut();

      await tester.pumpWidget(wrapped(VerificationPurpose.deactivation));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "We couldn't send your code. Please check your connection and try again.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a friendly generic message on send', (tester) async {
      final failingRepo = _ThrowingVerificationCodeRepository(
        SendCodeFailureKind.other,
      );
      harness = AuthTestHarness(verificationRepository: failingRepo);
      await harness.signOut();

      await tester.pumpWidget(wrapped(VerificationPurpose.deactivation));
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't send your code. Please try again."),
        findsOneWidget,
      );
    });
  });

  group('CodeEntryScreen (deletion)', () {
    testWidgets('shows deletion title and message', (tester) async {
      await tester.pumpWidget(wrapped(VerificationPurpose.deletion));
      await tester.pumpAndSettle();

      // "Delete Account" appears twice: the AppBar title and the confirm
      // button label.
      expect(find.text('Delete Account'), findsNWidgets(2));
      expect(find.text('Resend code'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.byKey(const Key('code-entry-input')), findsOneWidget);
    });

    testWidgets('auto-sends a deletion code when the screen opens', (
      tester,
    ) async {
      await tester.pumpWidget(wrapped(VerificationPurpose.deletion));
      await tester.pumpAndSettle();

      expect(
        harness.verificationRepository.activeCode?.purpose,
        VerificationPurpose.deletion,
      );
      expect(harness.verificationRepository.activeCode, isNotNull);
    });

    testWidgets(
      'confirm with valid code deletes the account and signs out',
      (tester) async {
        // Sign in first so the profile exists and the session is active.
        await harness.signIn();

        await tester.pumpWidget(wrapped(VerificationPurpose.deletion));
        await tester.pumpAndSettle();

        // The screen auto-sends a code on open (verified above); the mock
        // already has an active deletion code.

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

        // The account is deleted → the controller signs out.
        expect(harness.controller.status, AuthStatus.guest);
        expect(harness.controller.session, isNull);
        expect(harness.controller.profile, isNull);
      },
    );
  });
}

/// A mock verification-code repository whose `sendCode` always throws a
/// [SendCodeException] with the given [kind], so widget tests can verify the
/// friendly error messages render correctly.
class _ThrowingVerificationCodeRepository extends MockVerificationCodeRepository {
  _ThrowingVerificationCodeRepository(this.kind);

  final SendCodeFailureKind kind;

  @override
  Future<void> sendCode(VerificationPurpose purpose) async {
    throw SendCodeException(kind);
  }
}

class _CodeEntrySentinel extends StatelessWidget {
  const _CodeEntrySentinel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('code-entry-sentinel'),
      body: Center(
        child: FilledButton(
          key: const Key('open-deactivation-code-entry'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CodeEntryScreen(
                purpose: VerificationPurpose.deactivation,
              ),
            ),
          ),
          child: const Text('Open deactivation'),
        ),
      ),
    );
  }
}
