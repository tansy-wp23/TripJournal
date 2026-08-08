import 'package:flutter/material.dart';

import '../../../models/verification_code.dart';
import 'code_entry_screen.dart';

/// The reactivation screen — a thin wrapper around [CodeEntryScreen] with
/// `purpose: VerificationPurpose.reactivation`.
///
/// Shown when a deactivated user signs in (PB-06 detection). The code was
/// already sent automatically by [AuthController.signInWithGoogle]; this
/// screen lets the user enter it, resend it, or cancel (which signs out —
/// Architecture Decision 7).
class ReactivationScreen extends StatelessWidget {
  const ReactivationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CodeEntryScreen(
      purpose: VerificationPurpose.reactivation,
    );
  }
}