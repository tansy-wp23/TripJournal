import '../models/profile.dart';
import 'profile_repository.dart';

/// In-memory fake of [ProfileRepository] so UI work in Phases 2–5 never
/// blocks on a backend.
///
/// Seeded with a configurable profile state:
/// - [MockProfileState.firstTime] — no profile exists yet; the first
///   [createProfileIfMissing] call creates one (covers PB-03).
/// - [MockProfileState.active] — an active profile already exists.
/// - [MockProfileState.deactivated] — a deactivated profile already exists
///   (drives the Phase 2/4 reactivation routing branch).
class MockProfileRepository implements ProfileRepository {
  /// Controls whether a profile exists and its status on construction.
  MockProfileState state;

  /// The user id / email / display name used when seeding a profile.
  String mockUserId;
  String mockEmail;
  String mockDisplayName;

  Profile? _profile;

  MockProfileRepository({
    this.state = MockProfileState.active,
    this.mockUserId = 'user-001',
    this.mockEmail = 'sangyou@example.com',
    this.mockDisplayName = 'Sang You',
  }) {
    _seed();
  }

  void _seed() {
    final now = DateTime.now();
    switch (state) {
      case MockProfileState.firstTime:
        _profile = null;
        break;
      case MockProfileState.active:
        _profile = Profile(
          userID: mockUserId,
          email: mockEmail,
          displayName: mockDisplayName,
          status: AccountStatus.active,
          createdAt: now,
          updatedAt: now,
        );
        break;
      case MockProfileState.deactivated:
        _profile = Profile(
          userID: mockUserId,
          email: mockEmail,
          displayName: mockDisplayName,
          status: AccountStatus.deactivated,
          deactivatedAt: now,
          createdAt: now,
          updatedAt: now,
        );
        break;
      case MockProfileState.suspended:
        // Added for the profile-sign-in fix (2026-09-02): mirrors the admin
        // module's suspended status so mock behavior matches the real backend
        // for a user who can't satisfy is_active_user().
        _profile = Profile(
          userID: mockUserId,
          email: mockEmail,
          displayName: mockDisplayName,
          status: AccountStatus.suspended,
          createdAt: now,
          updatedAt: now,
        );
        break;
    }
  }

  @override
  Future<Profile?> getProfile(String userId) async {
    if (_profile == null || _profile!.userID != userId) return null;
    return _profile;
  }

  @override
  Future<Profile> createProfileIfMissing({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    if (_profile != null) {
      if (!_profile!.isActive) {
        // Mirror SupabaseProfileRepository: don't stamp last_login_at (or
        // attempt any write) for a deactivated/suspended profile — each is
        // gated at sign-in and can never reach the app, and the real backend
        // RLS forbids the update anyway.
        return _profile!;
      }
      // Stamp last_login_at on every sign-in (interactive or restored),
      // mirroring SupabaseProfileRepository.
      _profile = _profile!.copyWith(lastLoginAt: DateTime.now());
      return _profile!;
    }
    final now = DateTime.now();
    _profile = Profile(
      userID: userId,
      email: email,
      displayName: displayName,
      status: AccountStatus.active,
      lastLoginAt: now,
      createdAt: now,
      updatedAt: now,
      // Genuinely new account — route through onboarding once (Profile
      // Onboarding feature). Every other Profile() construction in this
      // class (the active/deactivated seeds above) leaves this at its
      // default `true`, since those represent users who were already using
      // the app.
      profileCompleted: false,
    );
    return _profile!;
  }

  @override
  Future<Profile> updateProfile(Profile profile) async {
    _profile = profile;
    return _profile!;
  }
}

/// Configurable initial state of the mock profile.
enum MockProfileState { firstTime, active, deactivated, suspended }
