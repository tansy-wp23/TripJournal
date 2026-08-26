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

    test(
        'sign-in as a non-admin profile is rejected, signed back out, and '
        'recorded', () async {
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

      // Found and fixed 2026-08-26: a rejected attempt now signs itself
      // back out immediately (both the shared Supabase session and
      // Google's own cached account selection — see
      // `_rejectAndSignOut`'s doc comment) rather than leaving the
      // rejected account sitting there signed in. `error` and
      // `hasPendingRejection` are what carry the rejection message
      // forward for `AdminGate` to relay after popping itself.
      expect(controller.status, AdminAuthStatus.signedOut);
      expect(controller.session, isNull);
      expect(controller.profile, isNull);
      expect(controller.error, isNotNull);
      expect(controller.hasPendingRejection, isTrue);
      expect(controller.consumePendingRejection(), controller.error);

      expect(accessAttemptLogRepository.entries, hasLength(1));
      final entry = accessAttemptLogRepository.entries.single;
      expect(entry.attemptedUserId, 'user-101');
      expect(entry.attemptedEmail, 'alice.tan@example.com');
      expect(entry.reason, AdminAccessAttemptReason.notAnAdmin);
    });

    test(
        'sign-in with an id that has no profile at all is rejected, signed '
        'back out, and recorded', () async {
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

      // See the "sign-in as a non-admin profile" test above for why this
      // is signedOut, not unauthorized (found and fixed 2026-08-26).
      expect(controller.status, AdminAuthStatus.signedOut);
      expect(controller.session, isNull);
      expect(controller.profile, isNull);
      expect(controller.error, isNotNull);
      expect(controller.hasPendingRejection, isTrue);

      expect(accessAttemptLogRepository.entries, hasLength(1));
      expect(
        accessAttemptLogRepository.entries.single.reason,
        AdminAccessAttemptReason.noProfileFound,
      );
    });

    test(
        'sign-in as a suspended admin is rejected, signed back out, and '
        'recorded', () async {
      userStore.profiles[0] = userStore.profiles[0].copyWith(
        status: AccountStatus.suspended,
      );

      await controller.signInWithGoogle();

      // See the "sign-in as a non-admin profile" test above for why this
      // is signedOut, not unauthorized (found and fixed 2026-08-26).
      expect(controller.status, AdminAuthStatus.signedOut);
      expect(controller.hasPendingRejection, isTrue);
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
