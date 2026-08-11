import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/settings/settings_controller.dart';
import 'package:tripjournal/features/settings/settings_preferences.dart';
import 'package:tripjournal/features/settings/settings_providers.dart';
import 'package:tripjournal/features/settings/settings_screen.dart';

class _Store implements SettingsStore {
  SettingsPreferences value = SettingsPreferences.defaults;
  @override
  Future<SettingsPreferences> load() async => value;
  @override
  Future<void> save(SettingsPreferences preferences) async => value = preferences;
}

void main() {
  testWidgets('shows appearance, reminder, health, and about sections', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStoreProvider.overrideWithValue(_Store())],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Journal reminder'), findsOneWidget);
    expect(find.text('Health data'), findsOneWidget);
    expect(find.textContaining('mobile device'), findsWidgets);
    await tester.scrollUntilVisible(find.text('About'), 300);
    expect(find.text('About'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('selecting dark mode persists through the controller', (tester) async {
    final store = _Store();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('theme-dark')));
    await tester.pumpAndSettle();
    expect(store.value.themeMode, ThemeMode.dark);
  });
}
