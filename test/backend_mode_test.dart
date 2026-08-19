import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/backend_mode.dart';

void main() {
  group('parseBackendMode', () {
    test('defaults to mock when the flag was never passed', () {
      expect(parseBackendMode(''), BackendMode.mock);
    });

    test('reads both documented values', () {
      expect(parseBackendMode('mock'), BackendMode.mock);
      expect(parseBackendMode('supabase'), BackendMode.supabase);
    });

    test('tolerates casing and surrounding whitespace', () {
      // --dart-define values arrive verbatim from a shell or a JSON file, so a
      // stray space or a capitalised value is a plausible typo rather than a
      // deliberate different mode.
      expect(parseBackendMode('  Supabase '), BackendMode.supabase);
      expect(parseBackendMode('MOCK'), BackendMode.mock);
    });

    test('throws on an unrecognised value rather than falling back', () {
      // The whole point of the switch is that the app is never quietly in a
      // different world than the one asked for. Silently serving in-memory data
      // to someone who typed BACKEND_MODE=supabse is the exact bug it prevents.
      expect(() => parseBackendMode('supabse'), throwsArgumentError);
      expect(() => parseBackendMode('real'), throwsArgumentError);
    });
  });

  test('the app under test runs on mock', () {
    // `flutter test` passes no --dart-define, so this pins the default that
    // keeps every other test in the suite off the network.
    expect(backendMode, BackendMode.mock);
  });
}
