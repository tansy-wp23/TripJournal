import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'admin_user_directory_repository.dart';
import 'profile_supabase_mapper.dart';

/// Real [AdminUserDirectoryRepository] backed by a multi-row, RLS-scoped
/// read over `profiles` (Phase 7 of ADMIN_MODULE_IMPLEMENTATION_PLAN.md).
/// Only reachable by a caller whose own profile satisfies
/// `is_admin_user()` — see `profiles_select_admin`
/// (202608190001_admin_module_phase7.sql); a non-admin caller's queries
/// here return only their own row via the pre-existing
/// `profiles_select_own` policy, not an error.
class SupabaseAdminUserDirectoryRepository
    implements AdminUserDirectoryRepository {
  SupabaseAdminUserDirectoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Profile>> searchUsers({String? query}) async {
    final trimmed = query?.trim() ?? '';
    var builder = _client.from('profiles').select();
    if (trimmed.isNotEmpty) {
      // Case-insensitive substring match on either field, mirroring
      // MockAdminUserDirectoryRepository. Postgrest's `.or()` filter string
      // is comma-delimited, so a literal comma in the query would break
      // this — acceptable for an admin search box, not user-facing input
      // that needs to be robust against arbitrary text.
      builder = builder.or(
        'display_name.ilike.%$trimmed%,email.ilike.%$trimmed%',
      );
    }
    final rows = await builder;
    return rows.map(profileFromSupabaseRow).toList();
  }

  @override
  Future<Profile?> getUserById(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : profileFromSupabaseRow(row);
  }
}
