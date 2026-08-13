import 'journal_repository.dart';
import 'mock_journal_repository.dart';
import 'mock_photo_storage.dart';
import 'photo_storage.dart';

/// The one place the app resolves its [JournalRepository] from.
///
/// Everything else (controllers, screens) imports this instead of
/// [MockJournalRepository] or `SupabaseJournalRepository` directly, so the
/// phase-6 swap to Supabase is a one-line change here.
final JournalRepository journalRepository = MockJournalRepository();

/// The one place the app resolves its [PhotoStorage] from — swapping in
/// `SupabasePhotoStorage` in phase 7 is a one-line change here.
///
/// Lives beside the journal repository because both consumers are journal
/// screens: entry photos in `CreateEditEntryScreen` and meal photos in the
/// health log's meal dialog.
final PhotoStorage photoStorage = MockPhotoStorage();
