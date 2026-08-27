import 'package:flutter/material.dart';

import '../auth/screens/login_screen.dart';
import '../community/community_screen.dart';

/// Home screen for guest (unauthenticated) users — the resting state for
/// [AuthStatus.guest] (2026-08-27 redesign: a first-time launch or a
/// just-logged-out user lands here directly, never on a login wall).
///
/// Embeds [CommunityScreen] directly rather than forking its list/search/
/// empty-state logic: the community feed is already read-only and has no
/// owner-only actions, so it works unmodified for a visitor with no
/// Supabase auth session (queries run as the `anon` role — see
/// `202608270001_guest_mode_anon_access.sql`). The profile/"Sign in"
/// affordance (`CommunityScreen.onSignIn`) pushes [LoginScreen] as an
/// explicit prompt rather than flipping any auth state — the guest can
/// simply back out of it and keep browsing.
class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CommunityScreen(
      key: const Key('guest-home-screen'),
      onSignIn: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      ),
    );
  }
}
