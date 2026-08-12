import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_admin_access_attempt_log_repository.dart';
import 'package:tripjournal/data/mock_admin_user_directory_repository.dart';
import 'package:tripjournal/data/mock_admin_user_store.dart';
import 'package:tripjournal/data/mock_auth_repository.dart';
import 'package:tripjournal/features/admin/controller/admin_auth_controller.dart';
import 'package:tripjournal/models/admin_access_attempt_log.dart';
import 'package:tripjournal/models/profile.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockAdminUserStore userStore;
  late MockAdminUserDirectoryRepository userDirectoryRepository;
  late MockAdminAccessAttemptLogRepository accessAttemptLogRepository;
  late AdminAuthController controller;

  setUp(() {
    // MockAdminUserStore.defaultSeed()'s 'admin-001' row is the only admin
    // in the seed; match the auth mock's id/email to it so the happy path
    // is reachable in tests (mirrors admin_repository_locator.dart's
    // adminAuthRepository wiring).
    authRepository = MockAuthRepository(
      mockUserId: 'admin-001',
      mockEmail: 'admin@tripjournal.dev',
    );
    userStore = MockAdminUserStore();
    userDirectoryRepository = MockAdminUserDirectoryRepository(userStore);
    accessAttemptLogRepository = MockAdminAccessAttemptLogRepository();
    controller = AdminAuthController(
      authRepository,
      userDirectoryRepository,
      accessAttemptLogRepository,
    );
  });

  tearDown(() => controller.dispose());

  group('AdminAuthController', () {
    test('initial status is signedOut', () {
      expect(controller.status, AdminAuthStatus.signedOut);
    });

    test('sign-in as the seeded admin profile authenticates', () async {
      await controller.signInWithGoogle();

      expect(controller.status, AdminAuthStatus.authenticated);
      expect(controller.profile?.userID, 'admin-001');
      expect(controller.profile?.role, UserRole.admin);
      expect(controller.error, isNull);
      expect(accessAttemptLogRepository.entries, isEmpty);
    });

    test('sign-in as a non-admin profile is unauthorized and recorded',
        () async {
      authRepository = MockAuthRepository(
        mockUserId: 'user-101',
        mockEmail: 'alice.tan@example.com',
      );
      controller = AdminAuthController(
        authRepository,
        userDirectoryRepository,
        accessAttemptLogRepository,
      );

      await controller.signInWithGoogle();

      expect(controller.status, AdminAuthStatus.unauthorized);
      expect(controller.error, isNotNull);
      expect(controller.profile?.role, UserRole.user);

      expect(accessAttemptLogRepository.entries, hasLength(1));
      final entry = accessAttemptLogRepository.entries.single;
      expect(entry.attemptedUserId, 'user-101');
      expect(entry.attemptedEmail, 'alice.tan@example.com');
      expect(entry.reason, AdminAccessAttemptReason.notAnAdmin);
    });

    test(
        'sign-in with an id that has no profile at all is unauthorized and '
        'recorded', () async {
      authRepository = MockAuthRepository(
        mockUserId: 'nonexistent-999',
        mockEmail: 'nobody@example.com',
      );
      controller = AdminAuthController(
        authRepository,
        userDirectoryRepository,
        accessAttemptLogRepository,
      );

      await controller.signInWithGoogle();

      expect(controller.status, AdminAuthStatus.unauthorized);
      expect(controller.profile, isNull);
      expect(controller.error, isNotNull);

      expect(accessAttemptLogRepository.entries, hasLength(1));
      expect(
        accessAttemptLogRepository.entries.single.reason,
        AdminAccessAttemptReason.noProfileFound,
      );
    });

    test('sign-in as a suspended admin is unauthorized and recorded',
        () async {
      userStore.profiles[0] = userStore.profiles[0].copyWith(
        status: AccountStatus.suspended,
      );

      await controller.signInWithGoogle();

      expect(controller.status, AdminAuthStatus.unauthorized);
      expect(controller.error, contains('suspended'));

      expect(accessAttemptLogRepository.entries, hasLength(1));
      expect(
        accessAttemptLogRepository.entries.single.reason,
        AdminAccessAttemptReason.adminAccountNotActive,
      );
    });

    test('failed (not cancelled) sign-in is not recorded as an attempt — '
        'no account identity was ever established', () async {
      authRepository = MockAuthRepository(result: MockAuthResult.failure);
      controller = AdminAuthController(
        authRepository,
        userDirectoryRepository,
        accessAttemptLogRepository,
      );

      await controller.signInWithGoogle();

      expect(controller.status, AdminAuthStatus.signedOut);
      expect(controller.error, isNotNull);
      expect(accessAttemptLogRepository.entries, isEmpty);
    });

    test('cancelled sign-in sets a cancelled error, stays signedOut, and is '
        'not recorded', () async {
      authRepository = MockAuthRepository(result: MockAuthResult.cancelled);
      controller = AdminAuthController(
        authRepository,
        userDirectoryRepository,
        accessAttemptLogRepository,
      );

      await controller.signInWithGoogle();

      expect(controller.status, AdminAuthStatus.signedOut);
      expect(controller.error, 'Sign-in cancelled.');
      expect(accessAttemptLogRepository.entries, isEmpty);
    });

    test('signOut clears session and profile', () async {
      await controller.signInWithGoogle();
      expect(controller.status, AdminAuthStatus.authenticated);

      await controller.signOut();

      expect(controller.status, AdminAuthStatus.signedOut);
      expect(controller.session, isNull);
      expect(controller.profile, isNull);
    });

    test('loading is true during sign-in, false after', () async {
      final future = controller.signInWithGoogle();
      expect(controller.loading, isTrue);
      await future;
      expect(controller.loading, isFalse);
    });
  });
}
