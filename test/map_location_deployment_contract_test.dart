import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String readProjectFile(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path must exist.');
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  test('no Google Maps rendering key survives anywhere in the tree', () {
    final example = readProjectFile('.env.example');
    final android = readProjectFile('android/app/src/main/AndroidManifest.xml');
    final gradle = readProjectFile('android/app/build.gradle.kts');
    final web = readProjectFile('web/index.html');

    for (final source in [example, android, gradle, web]) {
      expect(source, isNot(contains('AIza')));
      expect(source, isNot(contains('GOOGLE_MAPS_ANDROID_KEY')));
      expect(source, isNot(contains('GOOGLE_MAPS_IOS_KEY')));
      expect(source, isNot(contains('GOOGLE_MAPS_WEB_KEY')));
    }
    expect(android, isNot(contains('com.google.android.geo.API_KEY')));
    expect(web, isNot(contains('maps.googleapis.com')));
  });

  test('setup guide documents OSM tiles, not a Google key deployment', () {
    final guide = readProjectFile('docs/MAP_LOCATION_SETUP.md');

    expect(guide, isNot(contains('AIza')));
    expect(guide, isNot(contains('GOOGLE_MAPS_ANDROID_KEY')));
    expect(guide, contains('OpenStreetMap'));
    expect(guide, contains(RegExp('attribution', caseSensitive: false)));

    // The Android/iOS/signing sections this replaced were never map-specific
    // - they still apply and the guide should not have dropped them.
    expect(guide, contains(RegExp('SHA-1', caseSensitive: false)));
    expect(guide, contains('android-signing.properties'));
    expect(guide, contains('tripjournal-release.jks'));
    expect(guide, contains('must be backed up'));
  });

  test('map configuration requests foreground-only location permission', () {
    final android = readProjectFile('android/app/src/main/AndroidManifest.xml');
    final ios = readProjectFile('ios/Runner/Info.plist');

    expect(android, contains('ACCESS_FINE_LOCATION'));
    expect(android, contains('ACCESS_COARSE_LOCATION'));
    expect(android, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    expect(android, isNot(contains('FOREGROUND_SERVICE_LOCATION')));
    expect(ios, contains('NSLocationWhenInUseUsageDescription'));
    expect(ios, isNot(contains('NSLocationAlwaysUsageDescription')));
  });

  test('workspace launch configs need no map key input', () {
    final launch = readProjectFile('.vscode/launch.json');

    expect(launch, contains('"TripJournal"'));
    expect(launch, contains('--dart-define=BACKEND_MODE=supabase'));
    expect(launch, isNot(contains('maps.local')));
    expect(launch, isNot(contains('maps_defines')));
  });

  test('Android release signing never falls back to the debug certificate', () {
    final gradle = readProjectFile('android/app/build.gradle.kts');
    final gitignore = readProjectFile('.gitignore');

    expect(gradle, contains('android-signing.properties'));
    expect(gradle, contains('signingConfigs.create("release")'));
    expect(gradle, contains('signingConfigs.getByName("release")'));
    expect(
      gradle,
      isNot(contains('signingConfig = signingConfigs.getByName("debug")')),
    );
    expect(gitignore, contains('/.local/'));
  });
}
