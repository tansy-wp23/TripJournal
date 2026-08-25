import 'journal_repository.dart';
import 'mock_journal_repository.dart';
import '../features/journal/location/location_tag_service.dart';
import '../features/journal/location/nominatim_location_tag_service.dart';

/// The one place the app resolves its [JournalRepository] from.
///
/// Everything else (controllers, screens) imports this instead of
/// [MockJournalRepository] or `SupabaseJournalRepository` directly, so the
/// phase-6 swap to Supabase is a one-line change here.
final JournalRepository journalRepository = MockJournalRepository();

final LocationTagService locationTagService = NominatimLocationTagService();
