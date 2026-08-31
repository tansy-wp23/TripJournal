import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/app_logo.dart';
import '../../../widgets/centered_form_body.dart';
import '../../admin/admin_gate.dart';
import '../controller/auth_controller.dart';

/// Taps on the logo within [_adminTapWindow] needed to reach the admin
/// portal. Not shown as a visible link — travelers shouldn't see any admin
/// affordance on this screen (`docs/admin/PROGRESS.md` Phase 2 revision).
/// Mouse-friendly (a click counts as a tap) and works identically in debug
/// and release builds, unlike a `kDebugMode`-gated button or a
/// keyboard-only shortcut.
const int _adminTapsRequired = 3;
const Duration _adminTapWindow = Duration(seconds: 3);

/// Testing seam for the tap-window clock. `widget_test`-style pumps don't
/// advance real wall-clock time, so a test simulating a gap longer than
/// [_adminTapWindow] needs to fake `DateTime.now()` rather than actually
/// sleep. Defaults to the real clock; overridden only in
/// `test/login_screen_admin_entry_test.dart`.
@visibleForTesting
DateTime Function() loginScreenDebugClock = DateTime.now;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _logoTapCount = 0;
  DateTime? _firstTapAt;

  void _onLogoTap() {
    final now = loginScreenDebugClock();
    if (_firstTapAt == null || now.difference(_firstTapAt!) > _adminTapWindow) {
      _firstTapAt = now;
      _logoTapCount = 1;
    } else {
      _logoTapCount++;
    }

    if (_logoTapCount >= _adminTapsRequired) {
      _logoTapCount = 0;
      _firstTapAt = null;
      _openAdminPortal(context);
    }
  }

  void _openAdminPortal(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminGate()));
  }

  /// This screen is now only ever reached by being pushed on top of
  /// [GuestHomeScreen] (2026-08-27 redesign) — `AuthGate`'s base route just
  /// rebuilds its content to the newly-resolved screen underneath, it never
  /// pops this pushed route on its own. Without an explicit pop here, a
  /// successful sign-in would leave the guest browsing already invisibly
  /// replaced by `HomeScreen` (or `AdminAccountScreen`, etc.) one route
  /// down, forever hidden behind this now-stale screen.
  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!context.mounted) return;
    final auth = ref.read(authControllerProvider);
    if (auth.error == null) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final auth = ref.watch(authControllerProvider);

        return Scaffold(
          // Now reached only as a pushed route (2026-08-27 redesign — guest
          // browsing is the resting state, not this screen), never as the
          // app's root: an AppBar gives the automatic back arrow a guest who
          // opened this by mistake needs to return to browsing.
          appBar: AppBar(),
          body: CenteredFormBody(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      key: const Key('login-logo-tap-target'),
                      onTap: _onLogoTap,
                      child: const AppLogo(size: 88),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'TripJournal',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your journeys, remembered beautifully.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _BenefitRow(
                      icon: Icons.luggage_outlined,
                      text: 'Keep every trip in one place',
                    ),
                    const SizedBox(height: 12),
                    const _BenefitRow(
                      icon: Icons.photo_camera_back_outlined,
                      text: 'Remember places, photos and moods',
                    ),
                    const SizedBox(height: 12),
                    const _BenefitRow(
                      icon: Icons.favorite_outline,
                      text: 'Follow your travel wellness',
                    ),
                    const SizedBox(height: 28),
                    if (auth.error != null) ...[
                      _ErrorBanner(message: auth.error!),
                      const SizedBox(height: 16),
                    ],
                    Semantics(
                      container: true,
                      button: true,
                      label: 'Sign in with Google',
                      child: ExcludeSemantics(
                        child: FilledButton.icon(
                          key: const Key('sign-in-with-google'),
                          onPressed: auth.loading
                              ? null
                              : () => _signIn(context, ref),
                          icon: auth.loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(
                            auth.loading ? 'Signing in' : 'Sign in with Google',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You can return to Community at any time.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
