import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminGate()),
    );
  }

  Future<void> _signIn(WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final auth = ref.watch(authControllerProvider);

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      key: const Key('login-logo-tap-target'),
                      onTap: _onLogoTap,
                      child: const Icon(Icons.card_travel, size: 72),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'TripJournal',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Journal your travels and track your health.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 48),
                    if (auth.error != null) ...[
                      _ErrorBanner(message: auth.error!),
                      const SizedBox(height: 16),
                    ],
                    FilledButton.icon(
                      key: const Key('sign-in-with-google'),
                      onPressed: auth.loading ? null : () => _signIn(ref),
                      icon: auth.loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(auth.loading ? 'Signing in' : 'Sign in with Google'),
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
