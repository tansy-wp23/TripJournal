import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/account_lifecycle_repository.dart';
import '../../../data/verification_code_repository.dart';
import '../../../models/verification_code.dart';
import '../../../widgets/centered_form_body.dart';
import '../controller/auth_controller.dart';
import '../widgets/otp_code_input.dart';

/// A reusable code-entry screen for confirming an action with a 6-digit OTP.
///
/// Takes a [VerificationPurpose] so it can be used for both reactivation
/// (Phase 4) and deactivation (Phase 5). Handles send/resend, validation
/// with wrong-code and expired-code error states, and a cancel action.
class CodeEntryScreen extends ConsumerStatefulWidget {
  const CodeEntryScreen({
    super.key,
    required this.purpose,
    this.title,
    this.message,
  });

  /// What the code is for — drives the confirm action and the cancel
  /// behaviour (reactivation cancel signs out; deactivation cancel pops).
  final VerificationPurpose purpose;

  /// Optional title override. Defaults to a purpose-appropriate title.
  final String? title;

  /// Optional message override. Defaults to a purpose-appropriate message.
  final String? message;

  @override
  ConsumerState<CodeEntryScreen> createState() => _CodeEntryScreenState();
}

class _CodeEntryScreenState extends ConsumerState<CodeEntryScreen> {
  String _code = '';
  bool _submitting = false;
  String? _error;

  bool get _isReactivation =>
      widget.purpose == VerificationPurpose.reactivation;

  @override
  void initState() {
    super.initState();
    // Auto-send a code when the screen opens. Reactivation already has a
    // code sent during sign-in (AuthController.signInWithGoogle), but
    // deactivation does not — without this, entering the code would fail
    // until the user manually presses "Resend code".
    if (!_isReactivation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendInitialCode();
      });
    }
  }

  Future<void> _sendInitialCode() async {
    try {
      await ref.read(authControllerProvider.notifier).requestDeactivation();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to send code: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final title = widget.title ??
        (_isReactivation ? 'Reactivate Account' : 'Deactivate Account');
    final message = widget.message ??
        (_isReactivation
            ? 'A verification code has been sent to ${auth.session?.email ?? 'your email'}. Enter it below to reactivate your account.'
            : 'A verification code has been sent to ${auth.session?.email ?? 'your email'}. Enter it below to confirm deactivation.');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: !_isReactivation,
      ),
      body: CenteredFormBody(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                Icon(
                  _isReactivation ? Icons.lock_reset : Icons.person_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                OtpCodeInput(
                  key: const Key('code-entry-input'),
                  error: _error != null,
                  onChanged: (code) {
                    setState(() {
                      _code = code;
                      _error = null;
                    });
                  },
                  onCompleted: (code) {
                    setState(() => _code = code);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('code-entry-confirm'),
                  onPressed: _submitting || _code.length < 6
                      ? null
                      : () => _confirm(context),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isReactivation ? 'Confirm' : 'Deactivate'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const Key('code-entry-resend'),
                  onPressed: _submitting ? null : () => _resend(context),
                  child: const Text('Resend code'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const Key('code-entry-cancel'),
                  onPressed: _submitting
                      ? null
                      : () async {
                          await _cancel(context);
                        },
              child: Text(_isReactivation ? 'Cancel' : 'Back'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_isReactivation) {
        await ref
            .read(authControllerProvider.notifier)
            .confirmReactivation(_code);
        // On success, AuthController refreshes the profile → status becomes
        // authenticated → AuthGate routes into the app.
      } else {
        await ref
            .read(authControllerProvider.notifier)
            .confirmDeactivation(_code);
        // On success, AuthController signs out → AuthGate swaps to
        // LoginScreen. Pop any pushed routes (the Profile screen, this
        // screen) so the root AuthGate's LoginScreen is actually visible.
        if (mounted) {
          Navigator.of(this.context).popUntil((route) => route.isFirst);
        }
      }
    } on AccountSuspendedException {
      // Admin Module Phase 5: confirmReactivation rejects a suspended
      // profile — the code itself is valid, so this is a distinct message
      // from the wrong/expired-code cases below, not folded into them.
      setState(() {
        _error = 'This account has been suspended by an administrator.';
      });
    } on CodeValidationException catch (e) {
      setState(() {
        _error = e.result == CodeValidationResult.expired
            ? 'This code has expired. Please resend a new one.'
            : 'Incorrect code. Please try again.';
      });
    } catch (e) {
      setState(() {
        _error = 'An unexpected error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _resend(BuildContext context) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_isReactivation) {
        await ref.read(authControllerProvider.notifier).requestReactivation();
      } else {
        await ref.read(authControllerProvider.notifier).requestDeactivation();
      }
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('A new code has been sent.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to resend code: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _cancel(BuildContext context) async {
    if (_isReactivation) {
      // Architecture Decision 7 — don't leave a gated session hanging.
      await ref.read(authControllerProvider.notifier).signOut();
    } else {
      Navigator.of(context).pop();
    }
  }
}
