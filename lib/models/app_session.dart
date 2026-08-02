/// Lightweight app-level model of "what Supabase Auth currently knows".
///
/// This is **not** a table — it is derived from the Supabase SDK's
/// `onAuthStateChange` stream. `Session` (the ERD table) is superseded by
/// Supabase's own session/JWT/refresh-token handling; see
/// `docs/user-management/PROGRESS.md` Architecture Decision 3.
class AppSession {
  final String? userId;
  final String? email;
  final bool isSignedIn;

  const AppSession({
    this.userId,
    this.email,
    this.isSignedIn = false,
  });

  const AppSession.signedOut() : this();

  const AppSession.signedIn({
    required this.userId,
    required this.email,
  }) : isSignedIn = true;

  AppSession copyWith({
    String? userId,
    String? email,
    bool? isSignedIn,
  }) {
    return AppSession(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      isSignedIn: isSignedIn ?? this.isSignedIn,
    );
  }
}