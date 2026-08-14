import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/data/mock_verification_code_repository.dart';
import 'package:tripjournal/features/auth/auth_gate.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';
import 'package:tripjournal/widgets/app_logo.dart';
import 'package:tripjournal/widgets/app_splash.dart';

/// The mock repositories resolve without any latency, so a real sign-in never
/// leaves a loading frame on screen to assert against. Pinning the status is
/// what makes this deterministic rather than a race against the microtask queue.
class _LoadingAuthController extends AuthController {
  _LoadingAuthController(super.auth, super.profile, super.lifecycle);

  @override
  AuthStatus get status => AuthStatus.loading;
}

void main() {
  Widget wrapped(Widget home) => ProviderScope(
        child: MaterialApp(home: home),
      );

  group('AppSplash', () {
    testWidgets('shows the app artwork, the name and a progress indicator',
        (tester) async {
      await tester.pumpWidget(wrapped(const AppSplash()));
      await tester.pump();

      // `cacheWidth` wraps the provider, so the AssetImage is one layer down.
      final provider = tester.widget<Image>(find.byType(Image)).image;
      final asset = provider is ResizeImage ? provider.imageProvider : provider;
      expect((asset as AssetImage).assetName, AppLogo.asset);
      expect(find.text('TripJournal'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('the logo is capped rather than scaled to fill a tablet',
        (tester) async {
      tester.view.physicalSize = const Size(1112, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapped(const AppSplash()));
      await tester.pump();

      // 30% of 834 would be 250; the cap is what keeps it a logo rather than
      // a hero image.
      expect(tester.getSize(find.byType(Image)).height, 160);
    });

    testWidgets('the logo shrinks to fit a phone in landscape', (tester) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapped(const AppSplash()));
      await tester.pump();

      final height = tester.getSize(find.byType(Image)).height;
      expect(height, lessThan(160));
      expect(height, greaterThan(56));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('AuthGate shows the splash while the session is resolving',
      (tester) async {
    final profileRepository = MockProfileRepository(
      state: MockProfileState.active,
    );
    final verificationCodeRepository = MockVerificationCodeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => _LoadingAuthController(
              MockAuthRepository(),
              profileRepository,
              MockAccountLifecycleRepository(
                profileRepository: profileRepository,
                verificationCodeRepository: verificationCodeRepository,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pump();

    expect(find.byType(AppSplash), findsOneWidget);
    expect(find.text('TripJournal'), findsOneWidget);
  });
}
