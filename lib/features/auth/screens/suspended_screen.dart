import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/auth_controller.dart';

/// Shown when a signed-in profile's status is `AccountStatus.suspended` —
/// an admin-imposed suspension (`AdminAccountActionsRepository.suspendUser`),
/// distinct from self-service `deactivated`.
///
/// Deliberately **not** the same screen as `ReactivationScreen` and offers
/// no OTP entry: `AccountLifecycleRepository.confirmReactivation` already
/// rejects a suspended profile even with a perfectly valid code (Admin
/// Module Phase 5 guard), so walking the user through requesting and
/// entering a code here would only end in a guaranteed rejection. Only an
/// administrator can clear a suspension
/// (`AdminAccountActionsRepository.reactivateUser`) — this screen just
/// says so and offers a way out (sign out).
class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.block, size: 72, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 24),
                Text(
                  'Account Suspended',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account has been suspended by an administrator. '
                  'Contact support if you believe this is a mistake.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  key: const Key('suspended-sign-out'),
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
