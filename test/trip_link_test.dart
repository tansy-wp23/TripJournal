import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/trip/trip_link.dart';

void main() {
  test('tripLinkFor builds a tripjournal://trip/<id> link', () {
    expect(tripLinkFor('abc-123'), 'tripjournal://trip/abc-123');
  });

  test('tripIdFromLink extracts the id from a well-formed link', () {
    expect(
      tripIdFromLink(Uri.parse('tripjournal://trip/abc-123')),
      'abc-123',
    );
  });

  test('tripLinkFor and tripIdFromLink round-trip a real UUID', () {
    const id = '24d11c20-f9ad-484b-8c64-7348ef6a070e';
    expect(tripIdFromLink(Uri.parse(tripLinkFor(id))), id);
  });

  test('tripIdFromLink rejects the wrong scheme', () {
    expect(tripIdFromLink(Uri.parse('https://trip/abc-123')), isNull);
  });

  test('tripIdFromLink rejects the wrong host', () {
    expect(tripIdFromLink(Uri.parse('tripjournal://open/abc-123')), isNull);
  });

  test('tripIdFromLink rejects a link with no id segment', () {
    expect(tripIdFromLink(Uri.parse('tripjournal://trip/')), isNull);
    expect(tripIdFromLink(Uri.parse('tripjournal://trip')), isNull);
  });

  test('tripIdFromLink ignores extra path segments and takes the first', () {
    expect(
      tripIdFromLink(Uri.parse('tripjournal://trip/abc-123/extra')),
      'abc-123',
    );
  });
}
