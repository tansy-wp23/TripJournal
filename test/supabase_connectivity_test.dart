import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/supabase_connectivity.dart';

void main() {
  group('checkSupabaseConnectivity', () {
    // No `client` override reaches this test — `Supabase.initialize()` is
    // never called under `flutter_test`, so this exercises the same "not
    // initialized" path any other unit test hits, and asserts the one
    // contract that actually matters here: it never throws, and reports
    // "unreachable" honestly rather than crashing the caller.
    test('returns false, never throws, when Supabase has not been initialized',
        () async {
      final result = await checkSupabaseConnectivity();

      expect(result, isFalse);
    });
  });
}
