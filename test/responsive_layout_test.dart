import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/journal_repository.dart';
import 'package:tripjournal/data/mock_account_lifecycle_repository.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/data/mock_verification_code_repository.dart';
import 'package:tripjournal/data/repository_locator.dart';
import 'package:tripjournal/features/auth/controller/auth_controller.dart';
import 'package:tripjournal/features/profile/controller/profile_controller.dart';
import 'package:tripjournal/data/mock_profile_avatar_storage.dart';
import 'package:tripjournal/features/admin/screens/admin_dashboard_screen.dart';
import 'package:tripjournal/features/admin/screens/admin_login_screen.dart';
import 'package:tripjournal/features/admin/screens/admin_user_list_screen.dart';
import 'package:tripjournal/features/admin/screens/audit_log_screen.dart';
import 'package:tripjournal/features/auth/screens/login_screen.dart';
import 'package:tripjournal/features/auth/screens/reactivation_screen.dart';
import 'package:tripjournal/features/home/home_screen.dart';
import 'package:tripjournal/features/journal/ai/daily_advice_locator.dart';
import 'package:tripjournal/features/journal/controller/journal_controller.dart';
import 'package:tripjournal/features/journal/screens/create_edit_entry_screen.dart';
import 'package:tripjournal/features/journal/screens/entry_detail_screen.dart';
import 'package:tripjournal/features/journal/screens/photo_viewer_screen.dart';
import 'package:tripjournal/features/profile/screens/profile_view_screen.dart';
import 'package:tripjournal/features/settings/settings_screen.dart';
import 'package:tripjournal/features/trip/screens/trip_photo_slideshow_screen.dart';
import 'package:tripjournal/features/trip/screens/trip_trash_screen.dart';
import 'package:tripjournal/features/trip/screens/trip_wellness_screen.dart';
import 'package:tripjournal/features/trip/trip_form_screen.dart';
import 'package:tripjournal/features/trip/trip_photos.dart';
import 'package:tripjournal/features/trip/trip_view_screen.dart';
import 'package:tripjournal/features/trip/widgets/trip_cover_photo.dart';
import 'package:tripjournal/models/health_log.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/meal.dart';
import 'package:tripjournal/models/meal_type.dart';
import 'package:tripjournal/models/mood.dart';
import 'package:tripjournal/models/trip.dart';
import 'package:tripjournal/widgets/app_splash.dart';

/// Sizes chosen to bracket what the app actually has to survive: a small
/// budget phone, the same phone rotated (the tightest vertical case by far),
/// a large phone, and a tablet in both orientations.
const _sizes = <String, Size>{
  'small phone portrait': Size(320, 568),
  'small phone landscape': Size(568, 320),
  'phone portrait': Size(412, 915),
  'phone landscape': Size(915, 412),
  'tablet portrait': Size(834, 1112),
  'tablet landscape': Size(1112, 834),
};

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget home, {double textScale = 1.0}) => ProviderScope(
      child: MaterialApp(
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: home,
      ),
    );

/// Same as [_app] but overrides [authControllerProvider] with a mock-backed
/// controller so screens that watch auth state don't touch
/// `Supabase.instance` (which isn't initialized in widget tests).
Widget _appWithMockAuth(Widget home, {double textScale = 1.0}) {
  final profileRepository = MockProfileRepository(
    state: MockProfileState.active,
  );
  final verificationCodeRepository = MockVerificationCodeRepository();
  final authController = AuthController(
    MockAuthRepository(),
    profileRepository,
    MockAccountLifecycleRepository(
      profileRepository: profileRepository,
      verificationCodeRepository: verificationCodeRepository,
    ),
  );
  final profileController = ProfileController(
    profileRepository,
    authController,
    MockProfileAvatarStorage(),
  );

  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith((ref) => authController),
      profileControllerProvider.overrideWith((ref) => profileController),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child!,
      ),
      home: home,
    ),
  );
}

/// Renders [build] at every size and fails on any layout overflow. A
/// RenderFlex/RenderBox overflow raises a FlutterError during paint, which the
/// test binding records — so takeException is a real assertion here, not a
/// formality.
/// Set [settle] to false for a screen holding an indefinite animation — a
/// permanent [CircularProgressIndicator] never stops scheduling frames, so
/// pumpAndSettle would time out rather than report a layout problem.
Future<void> _expectNoOverflow(
  WidgetTester tester,
  Widget Function() build, {
  Future<void> Function(WidgetTester tester)? after,
  bool settle = true,
}) async {
  for (final entry in _sizes.entries) {
    _setSize(tester, entry.value);
    await tester.pumpWidget(build());
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    if (after != null) await after(tester);

    expect(
      tester.takeException(),
      isNull,
      reason: 'layout overflowed at ${entry.key} (${entry.value})',
    );
  }
}

/// The same sweep with the OS font size turned up, which is a second, separate
/// way for a layout to break: everything gets taller and wider while the
/// window does not.
Future<void> _expectNoOverflowAtLargeText(
  WidgetTester tester,
  Widget Function({double textScale}) build, {
  bool settle = true,
}) async {
  for (final entry in _sizes.entries) {
    _setSize(tester, entry.value);
    await tester.pumpWidget(build(textScale: 1.3));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }

    expect(
      tester.takeException(),
      isNull,
      reason: 'layout overflowed at ${entry.key} (${entry.value}) with 1.3x text',
    );
  }
}

class _LongTextJournalRepository implements JournalRepository {
  static final _entries = [
    JournalEntry(
      id: 'entry-long',
      tripId: 'trip-001',
      title: 'A day so eventful that describing it properly takes considerably '
          'more room than any sensible layout would ever reserve for a title',
      body: 'Body text that also runs on well past the point where a narrow '
          'phone in portrait would like it to stop.',
      mood: Mood.excited,
      photoPaths: const ['assets/mock/kyoto_arrival_1.jpg'],
      createdAt: DateTime(2026, 4, 10, 9),
      updatedAt: DateTime(2026, 4, 10, 9),
      healthLog: const HealthLog(
        id: 'hl-long',
        entryId: 'entry-long',
        steps: 123456,
        caloriesEaten: 98765,
        caloriesBurned: 87654,
        meals: [
          Meal(
            id: 'meal-long',
            name: 'An extravagantly long meal name that nobody would type but '
                'somebody eventually will',
            calories: 1234,
            mealType: MealType.dinner,
            photoPath: 'assets/mock/ramen_lunch.jpg',
          ),
        ],
      ),
    ),
  ];

  @override
  Future<List<JournalEntry>> getEntries(String tripId) async => _entries;

  @override
  Future<JournalEntry?> getEntry(String id) async =>
      _entries.where((e) => e.id == id).firstOrNull;

  @override
  Future<void> addEntry(JournalEntry entry) async {}

  @override
  Future<void> updateEntry(JournalEntry entry) async {}

  @override
  Future<void> deleteEntry(String id) async {}
}

TripPhoto _photo(int day) => TripPhoto(
      path: 'assets/mock/gion_evening.jpg',
      kind: TripPhotoKind.entry,
      entryId: 'entry-1',
      date: DateTime(2026, 4, 9 + day),
      dayNumber: day,
      caption: 'A fairly long caption that has to wrap or ellipsize cleanly',
    );

void main() {
  testWidgets('Trip View survives every screen size and orientation', (tester) async {
    await _expectNoOverflow(
      tester,
      () => _app(const TripViewScreen(tripId: 'trip-001')),
    );
  });

  testWidgets('the trip photo slideshow survives every screen size and orientation', (
    tester,
  ) async {
    await _expectNoOverflow(
      tester,
      () => _app(TripPhotoSlideshowScreen(
        photos: [_photo(1), _photo(2), _photo(3)],
        initialIndex: 1,
      )),
    );
  });

  testWidgets('the entry editor survives every screen size and orientation', (tester) async {
    await _expectNoOverflow(
      tester,
      () => _app(const CreateEditEntryScreen(tripId: 'trip-001')),
    );
  });

  testWidgets('the add-meal dialog survives every screen size and orientation', (tester) async {
    // The tightest case in the app: a tall form inside a dialog, on a screen
    // only ~320 logical pixels high in landscape.
    await _expectNoOverflow(
      tester,
      () => _app(const CreateEditEntryScreen(tripId: 'trip-001')),
      after: (tester) async {
        await tester.scrollUntilVisible(
          find.byKey(const Key('add-meal-button')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const Key('add-meal-button')));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('entry detail survives every screen size and orientation', (tester) async {
    await _expectNoOverflow(
      tester,
      () => _app(const EntryDetailScreen(entryId: 'entry-1')),
    );
  });

  testWidgets('the full-screen photo viewer survives every screen size and orientation', (
    tester,
  ) async {
    await _expectNoOverflow(
      tester,
      () => _app(const PhotoViewerScreen(
        photoPaths: ['assets/mock/gion_evening.jpg', 'assets/mock/kyoto_arrival_1.jpg'],
        initialIndex: 0,
      )),
    );
  });

  testWidgets('Home survives every screen size and orientation', (tester) async {
    await _expectNoOverflow(tester, () => _app(const HomeScreen()));
  });

  testWidgets("the active trip's cover fills the card's width rather than pillarboxing", (
    tester,
  ) async {
    for (final size in [const Size(412, 915), const Size(915, 412)]) {
      _setSize(tester, size);
      await tester.pumpWidget(_app(const HomeScreen()));
      await tester.pumpAndSettle();

      final card = tester.getSize(find.byKey(const Key('active-trip-card')));
      final cover = tester.getSize(
        find.descendant(
          of: find.byKey(const Key('active-trip-card')),
          matching: find.byType(TripCoverPhoto),
        ),
      );

      expect(
        cover.width,
        card.width,
        reason: 'cover should span the card at $size, not sit in grey bands',
      );
    }
  });

  testWidgets('Login survives every screen size and orientation', (tester) async {
    await _expectNoOverflow(
      tester,
      () => _appWithMockAuth(const LoginScreen()),
    );
  });

  testWidgets('the splash survives every screen size and orientation', (tester) async {
    await _expectNoOverflow(tester, () => _app(const AppSplash()), settle: false);
  });

  testWidgets('the trip form survives every screen size and orientation', (tester) async {
    await _expectNoOverflow(tester, () => _app(const TripFormScreen()));
  });

  testWidgets('trip wellness survives every screen size and orientation', (tester) async {
    final trip = Trip(
      id: 'trip-001',
      userId: 'u',
      title: 'Kyoto Trip',
      startDate: DateTime(2026, 4, 10),
      endDate: DateTime(2026, 4, 14),
      createdAt: DateTime(2026, 4, 10),
      updatedAt: DateTime(2026, 4, 10),
    );
    final entries = await journalRepository.getEntries('trip-001');
    await _expectNoOverflow(
      tester,
      () => _app(TripWellnessScreen(trip: trip, entries: entries)),
    );
  });

  testWidgets('trip trash survives every screen size and orientation', (tester) async {
    await _expectNoOverflow(tester, () => _app(const TripTrashScreen()));
  });

  testWidgets('settings survives every screen size and orientation', (tester) async {
    await _expectNoOverflow(tester, () => _app(const SettingsScreen()));
  });

  testWidgets('the profile screen survives every screen size and orientation', (tester) async {
    await _expectNoOverflow(
      tester,
      () => _appWithMockAuth(const ProfileViewScreen()),
    );
  });

  testWidgets('reactivation survives every screen size and orientation', (tester) async {
    await _expectNoOverflow(
      tester,
      () => _appWithMockAuth(const ReactivationScreen()),
    );
  });

  group('admin', () {
    testWidgets('admin login survives every screen size and orientation', (tester) async {
      await _expectNoOverflow(tester, () => _app(const AdminLoginScreen()));
    });

    testWidgets('the admin dashboard survives every screen size and orientation', (tester) async {
      await _expectNoOverflow(tester, () => _app(const AdminDashboardScreen()));
    });

    testWidgets('the admin user list survives every screen size and orientation', (tester) async {
      await _expectNoOverflow(tester, () => _app(const AdminUserListScreen()));
    });

    testWidgets('the audit log survives every screen size and orientation', (tester) async {
      await _expectNoOverflow(tester, () => _app(const AuditLogScreen()));
    });
  });

  testWidgets('long user-entered text does not blow out the trip timeline', (tester) async {
    // Seeded titles are all short, so nothing else in the suite exercises what
    // happens when a traveler types a genuinely long one. The fixture also
    // carries six-figure step counts and a long meal name.
    await _expectNoOverflow(
      tester,
      () => ProviderScope(
        overrides: [
          journalControllerProvider.overrideWith(
            (ref) => JournalController(_LongTextJournalRepository(), dailyAdviceService),
          ),
        ],
        child: const MaterialApp(home: TripViewScreen(tripId: 'trip-001')),
      ),
    );
  });

  group('with the OS font size turned up', () {
    testWidgets('Trip View survives 1.3x text at every size', (tester) async {
      await _expectNoOverflowAtLargeText(
        tester,
        ({double textScale = 1.0}) =>
            _app(const TripViewScreen(tripId: 'trip-001'), textScale: textScale),
      );
    });

    testWidgets('Home survives 1.3x text at every size', (tester) async {
      await _expectNoOverflowAtLargeText(
        tester,
        ({double textScale = 1.0}) => _app(const HomeScreen(), textScale: textScale),
      );
    });

    testWidgets('Login survives 1.3x text at every size', (tester) async {
      await _expectNoOverflowAtLargeText(
        tester,
        ({double textScale = 1.0}) =>
            _appWithMockAuth(const LoginScreen(), textScale: textScale),
      );
    });

    testWidgets('the splash survives 1.3x text at every size', (tester) async {
      await _expectNoOverflowAtLargeText(
        tester,
        ({double textScale = 1.0}) => _app(const AppSplash(), textScale: textScale),
        settle: false,
      );
    });

    testWidgets('the admin dashboard survives 1.3x text at every size', (tester) async {
      await _expectNoOverflowAtLargeText(
        tester,
        ({double textScale = 1.0}) => _app(const AdminDashboardScreen(), textScale: textScale),
      );
    });

    testWidgets('entry detail survives 1.3x text at every size', (tester) async {
      await _expectNoOverflowAtLargeText(
        tester,
        ({double textScale = 1.0}) =>
            _app(const EntryDetailScreen(entryId: 'entry-1'), textScale: textScale),
      );
    });
  });
}
