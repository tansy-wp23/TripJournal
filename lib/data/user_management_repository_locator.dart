import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_lifecycle_repository.dart';
import 'auth_repository.dart';
import 'profile_avatar_storage.dart';
import 'profile_repository.dart';
import 'supabase_account_lifecycle_repository.dart';
import 'supabase_auth_repository.dart';
import 'supabase_profile_avatar_storage.dart';
import 'supabase_profile_repository.dart';
import 'supabase_verification_code_repository.dart';
import 'verification_code_repository.dart';

/// The one place the app resolves its user-management repositories from —
/// mirrors `repository_locator.dart` / `trip_repository_locator.dart`.
///
/// Phase 7: all repositories are wired to their real Supabase
/// implementations. The mock implementations remain in the codebase for
/// offline/dev-mode use but are no longer wired by default.
///
/// Lazy getters (rather than top-level finals) so importing this file in a
/// test never touches `Supabase.instance` — that throws unless
/// `Supabase.initialize` has run, which widget tests don't do.
SupabaseClient get _supabase => Supabase.instance.client;

AuthRepository get authRepository => SupabaseAuthRepository(_supabase);
ProfileRepository get profileRepository =>
    SupabaseProfileRepository(_supabase);
ProfileAvatarStorage get profileAvatarStorage =>
    SupabaseProfileAvatarStorage(_supabase);
VerificationCodeRepository get verificationCodeRepository =>
    SupabaseVerificationCodeRepository(_supabase);
AccountLifecycleRepository get accountLifecycleRepository =>
    SupabaseAccountLifecycleRepository(
      _supabase,
      verificationCodeRepository,
      profileRepository,
    );