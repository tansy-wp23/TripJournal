import 'health_data_source.dart';
import 'mock_health_data_source.dart';
import 'platform_health_data_source.dart';

/// The one place the app resolves its [HealthDataSource] from — mirrors
/// `data/trip_repository_locator.dart`. Defaults to the mock so the app runs
/// out of the box on the Windows desktop dev loop, an emulator, or `flutter
/// test` — HealthKit/Health Connect don't work in any of those environments
/// (IMPLEMENTATION_PLAN_HEALTH.md §6). Opt into the real platform
/// implementation on a physical device with:
///   flutter run --dart-define=USE_PLATFORM_HEALTH=true
const bool _usePlatformHealth = bool.fromEnvironment('USE_PLATFORM_HEALTH');

final HealthDataSource healthDataSource =
    _usePlatformHealth ? PlatformHealthDataSource() : MockHealthDataSource();
