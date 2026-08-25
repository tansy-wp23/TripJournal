import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_mode.dart';
import 'journal_repository.dart';
import 'mock_journal_repository.dart';
import 'mock_photo_storage.dart';
import 'photo_storage.dart';
import 'supabase_journal_repository.dart';
import 'supabase_photo_storage.dart';
import 'trip_repository_locator.dart';
import '../features/journal/location/location_tag_service.dart';
import '../features/journal/location/nominatim_location_tag_service.dart';

/// The one place the app resolves its [JournalRepository] from.
///
/// Everything else (controllers, screens) imports this instead of
/// [MockJournalRepository] or [SupabaseJournalRepository] directly, and which
/// one it gets is decided by [backendMode] — see `backend_mode.dart` for why
/// that is a single app-wide switch rather than a choice made here.
JournalRepository? _journalRepository;
JournalRepository get journalRepository =>
    _journalRepository ??= switch (backendMode) {
      BackendMode.mock => MockJournalRepository(),
      BackendMode.supabase => SupabaseJournalRepository(
        Supabase.instance.client,
        currentUserIdProvider,
      ),
    };

/// Where journal entry photos and meal photos are kept.
///
/// Lives beside the journal repository because both consumers are journal
/// screens: entry photos in `CreateEditEntryScreen` and meal photos in the
/// health log's meal dialog.
PhotoStorage? _photoStorage;
PhotoStorage get photoStorage => _photoStorage ??= switch (backendMode) {
  BackendMode.mock => MockPhotoStorage(),
  BackendMode.supabase => SupabasePhotoStorage(
    Supabase.instance.client,
    currentUserIdProvider,
  ),
};

final LocationTagService locationTagService = NominatimLocationTagService();