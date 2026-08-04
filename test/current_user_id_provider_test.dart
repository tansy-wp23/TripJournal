import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tripjournal/data/current_user_id_provider.dart';
import 'package:tripjournal/data/mock_current_user_id_provider.dart';
import 'package:tripjournal/data/supabase_current_user_id_provider.dart';
import 'package:tripjournal/features/trip/mock_user.dart';

void main() {
  test('mock provider returns the mock user id', () {
    expect(MockCurrentUserIdProvider().requireUserId(), kMockUserId);
  });

  test('Supabase provider throws when there is no signed-in user', () {
    final client = SupabaseClient('https://example.supabase.co', 'anon-key');

    expect(
      () => SupabaseCurrentUserIdProvider(client).requireUserId(),
      throwsA(isA<UnauthenticatedTripUserException>()),
    );
  });
}
