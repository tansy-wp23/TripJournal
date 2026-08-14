import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/centered_form_body.dart';
import '../controller/admin_auth_controller.dart';

/// The admin sign-in screen (PB-01). A distinct screen/route from the
/// traveler `LoginScreen` — different heading, so it's visually clear this
/// isn't the traveler login — but calls the same underlying sign-in method
/// (`docs/admin/PROGRESS.md` Open Decision 1). The role check happens after
/// sign-in, in `AdminAuthController`; this screen just surfaces whatever
/// `error` that check produced, the same way `LoginScreen` does.
class AdminLoginScreen extends ConsumerWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(adminAuthControllerProvider);

    return Scaffold(
      body: CenteredFormBody(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                const Icon(Icons.admin_panel_settings, size: 72),
                const SizedBox(height: 24),
                Text(
                  'Admin Portal',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in with an administrator account to manage users.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 48),
                if (admin.error != null) ...[
                  _ErrorBanner(message: admin.error!),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  key: const Key('admin-sign-in-with-google'),
                  onPressed: admin.loading ? null : () => _signIn(ref),
                  icon: admin.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
              label: Text(admin.loading ? 'Signing in' : 'Sign in with Google'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn(WidgetRef ref) async {
    await ref.read(adminAuthControllerProvider.notifier).signInWithGoogle();
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
