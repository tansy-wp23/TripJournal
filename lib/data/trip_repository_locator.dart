import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_mode.dart';
import 'current_user_id_provider.dart';
import 'mock_current_user_id_provider.dart';
import 'mock_trip_cover_storage.dart';
import 'mock_trip_repository.dart';
import 'supabase_current_user_id_provider.dart';
import 'supabase_trip_cover_storage.dart';
import 'supabase_trip_repository.dart';
import 'trip_cover_storage.dart';
import 'trip_repository.dart';

/// The one place the app resolves its [TripRepository] from — mirrors
/// `repository_locator.dart`, and reads the same app-wide [backendMode] so the
/// two can never disagree about which world the app is in.
TripRepository? _tripRepository;
TripRepository get tripRepository => _tripRepository ??= switch (backendMode) {
  BackendMode.mock => MockTripRepository(),
  BackendMode.supabase => SupabaseTripRepository(Supabase.instance.client),
};

/// Who the app thinks is signed in.
///
/// This is the field that made a per-locator switch dangerous: in
/// [BackendMode.mock] it answers with a constant that belongs to no real
/// account, so any real row written under it is invisible to every RLS policy
/// the moment the app looks for it again.
CurrentUserIdProvider? _currentUserIdProvider;
CurrentUserIdProvider get currentUserIdProvider =>
    _currentUserIdProvider ??= switch (backendMode) {
      BackendMode.mock => MockCurrentUserIdProvider(),
      BackendMode.supabase => SupabaseCurrentUserIdProvider(
        Supabase.instance.client,
      ),
    };

TripCoverStorage? _tripCoverStorage;
TripCoverStorage get tripCoverStorage =>
    _tripCoverStorage ??= switch (backendMode) {
      BackendMode.mock => MockTripCoverStorage(),
      BackendMode.supabase => SupabaseTripCoverStorage(
        Supabase.instance.client,
      ),
    };
