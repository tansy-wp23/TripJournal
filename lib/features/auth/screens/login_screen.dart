import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/auth_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                const Icon(Icons.card_travel, size: 72),
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
  }

  Future<void> _signIn(WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
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
