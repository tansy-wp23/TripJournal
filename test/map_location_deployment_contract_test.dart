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

  test('web bootstrap exposes Google Maps SDK loader readiness to Dart', () {
    final web = readProjectFile('web/index.html');

    expect(web, contains("tripJournalGoogleMapsSdkState = 'unconfigured'"));
    expect(web, contains("tripJournalGoogleMapsSdkState = 'ready'"));
    expect(web, contains("tripJournalGoogleMapsSdkState = 'failed'"));
    expect(web, isNot(contains('maps.onerror = startFlutter')));
  });

  test('setup guide documents every required application restriction', () {
    final guide = readProjectFile('docs/MAP_LOCATION_SETUP.md');

    expect(guide, contains('com.tripjournal.tripjournal'));
    expect(guide, contains('SHA-1'));
    expect(guide, isNot(contains('SHA-256')));
    expect(guide, contains('Play app-signing certificate SHA-1'));
    expect(guide, contains('not the upload certificate'));
    expect(guide, contains('bundle ID'));
    expect(guide, contains('HTTP referrer'));
    expect(guide, contains('`http://localhost`'));
    expect(guide, contains('`http://localhost/*`'));
    expect(guide, contains('omitting the port matches any port'));
    expect(guide, isNot(contains('localhost:*')));
    expect(guide, contains('Set-Content -Encoding utf8'));
    expect(guide, contains('android-signing.properties'));
    expect(guide, contains('tripjournal-release.jks'));
    expect(guide, contains('must be backed up'));
    expect(
      guide,
      isNot(contains('release builds are presently signed with the debug')),
    );
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

  test('workspace exposes an explicit Supabase Android Maps launch', () {
    final launch = readProjectFile('.vscode/launch.json');

    expect(launch, contains('TripJournal (Supabase + Android Maps)'));
    expect(launch, contains('--dart-define=BACKEND_MODE=supabase'));
    expect(
      launch,
      contains('--dart-define-from-file=.local/maps_defines.json'),
    );
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
