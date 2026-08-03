import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/auth_controller.dart';
import '../widgets/otp_code_input.dart';

class ReactivationScreen extends ConsumerWidget {
  const ReactivationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reactivate Account'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_reset,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Your account is deactivated',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'A verification code has been sent to ${auth.session?.email ?? 'your email'}. Enter it below to reactivate your account.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                OtpCodeInput(
                  key: const Key('reactivation-code-input'),
                  onCompleted: (code) {
                    // Phase 5: call confirmReactivation(code) then onReactivated().
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Code entered: $code (Phase 4/5 logic).'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('reactivation-confirm'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reactivation logic lands in Phase 4/5.'),
                      ),
                    );
                  },
                  child: const Text('Confirm'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const Key('reactivation-cancel'),
                  onPressed: () => _cancel(context, ref),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signOut();
  }
}
