import 'package:supabase_flutter/supabase_flutter.dart';

import 'current_user_id_provider.dart';

final class SupabaseCurrentUserIdProvider implements CurrentUserIdProvider {
  SupabaseCurrentUserIdProvider(this._client);

  final SupabaseClient _client;

  @override
  String requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const UnauthenticatedTripUserException();
    }
    return userId;
  }
}
