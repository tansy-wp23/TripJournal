import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String readProjectFile(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path must exist.');
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  test('example environment declares blank platform map keys', () {
    final example = readProjectFile('.env.example');

    for (final name in const [
      'GOOGLE_MAPS_ANDROID_KEY',
      'GOOGLE_MAPS_IOS_KEY',
      'GOOGLE_MAPS_WEB_KEY',
    ]) {
      expect(
        example,
        contains(RegExp('^${RegExp.escape(name)}=\\s*\$', multiLine: true)),
        reason: '$name must be documented without committing a value.',
      );
    }
    expect(example, isNot(contains('AIza')));
  });

  test('platform manifests keep Google Maps keys as build placeholders', () {
    final android = readProjectFile('android/app/src/main/AndroidManifest.xml');
    final ios = readProjectFile('ios/Runner/Info.plist');
    final web = readProjectFile('web/index.html');

    expect(android, contains('com.google.android.geo.API_KEY'));
    expect(android, contains(r'${GOOGLE_MAPS_ANDROID_KEY}'));
    expect(ios, contains('TripJournalDartDefines'));
    expect(ios, contains(r'$(DART_DEFINES)'));
    expect(web, contains('__GOOGLE_MAPS_WEB_KEY__'));

    for (final manifest in [android, ios, web]) {
      expect(manifest, isNot(contains('AIza')));
    }
  });

  test('setup guide documents every required application restriction', () {
    final guide = readProjectFile('docs/MAP_LOCATION_SETUP.md');

    expect(guide, contains('com.tripjournal.tripjournal'));
    expect(guide, contains('SHA-1'));
    expect(guide, contains('SHA-256'));
    expect(guide, contains('bundle ID'));
    expect(guide, contains('HTTP referrer'));
  });

  test('map configuration does not request device location permission', () {
    final android = readProjectFile('android/app/src/main/AndroidManifest.xml');
    final ios = readProjectFile('ios/Runner/Info.plist');

    expect(android, isNot(contains('ACCESS_FINE_LOCATION')));
    expect(android, isNot(contains('ACCESS_COARSE_LOCATION')));
    expect(ios, isNot(contains('NSLocationWhenInUseUsageDescription')));
    expect(ios, isNot(contains('NSLocationAlwaysUsageDescription')));
  });
}
