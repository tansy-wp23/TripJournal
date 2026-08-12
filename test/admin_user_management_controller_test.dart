import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/admin_user_directory_repository.dart';
import 'package:tripjournal/data/mock_admin_user_directory_repository.dart';
import 'package:tripjournal/data/mock_admin_user_store.dart';
import 'package:tripjournal/features/admin/controller/admin_user_management_controller.dart';
import 'package:tripjournal/models/profile.dart';

// setQuery debounces for 300ms before actually searching; tests that rely
// on the debounce firing wait past that with a real delay rather than
// `package:fake_async`, since a plain `test()` (unlike `testWidgets`)
// doesn't run in a fake-time zone that would make `Timer` respect
// simulated pumps.
const _pastDebounce = Duration(milliseconds: 350);

void main() {
  late MockAdminUserStore store;
  late AdminUserManagementController controller;

  setUp(() {
    store = MockAdminUserStore();
    controller = AdminUserManagementController(MockAdminUserDirectoryRepository(store));
  });

  tearDown(() => controller.dispose());

  group('AdminUserManagementController', () {
    test('initial state is empty, not loading, no error', () {
      expect(controller.results, isEmpty);
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
    });

    test('loadAll returns every seeded profile', () async {
      await controller.loadAll();

      expect(controller.results, hasLength(6));
      expect(controller.error, isNull);
    });

    test('setQuery does not search immediately (debounced)', () async {
      controller.setQuery('alice');

      expect(controller.results, isEmpty);
    });

    test('setQuery searches after the debounce window and matches by name',
        () async {
      controller.setQuery('alice');
      await Future.delayed(_pastDebounce);

      expect(controller.results, hasLength(1));
      expect(controller.results.single.displayName, 'Alice Tan');
    });

    test('setQuery matches by email substring', () async {
      controller.setQuery('brandon.lee');
      await Future.delayed(_pastDebounce);

      expect(controller.results, hasLength(1));
      expect(controller.results.single.email, 'brandon.lee@example.com');
    });

    test('rapid typing only searches for the final query', () async {
      controller.setQuery('a');
      await Future.delayed(const Duration(milliseconds: 100));
      controller.setQuery('al');
      await Future.delayed(const Duration(milliseconds: 100));
      controller.setQuery('alice');
      await Future.delayed(_pastDebounce);

      expect(controller.results, hasLength(1));
      expect(controller.results.single.displayName, 'Alice Tan');
    });

    test('a query matching nobody yields an empty result, not an error',
        () async {
      controller.setQuery('nonexistent-name-xyz');
      await Future.delayed(_pastDebounce);

      expect(controller.results, isEmpty);
      expect(controller.error, isNull);
    });

    test('clearQuery searches immediately, bypassing the debounce',
        () async {
      controller.setQuery('alice');
      await Future.delayed(_pastDebounce);
      expect(controller.results, hasLength(1));

      controller.clearQuery();
      await Future.delayed(Duration.zero);

      expect(controller.query, '');
      expect(controller.results, hasLength(6));
    });

    test('a failing repository sets error', () async {
      final failingController = AdminUserManagementController(_FailingDirectoryRepository());

      await failingController.loadAll();

      expect(failingController.error, isNotNull);
      expect(failingController.results, isEmpty);
      failingController.dispose();
    });

    test('loading is true during a search, false after', () async {
      final future = controller.loadAll();
      expect(controller.loading, isTrue);
      await future;
      expect(controller.loading, isFalse);
    });

    group('filtering', () {
      test('hasActiveFilter is false initially', () {
        expect(controller.hasActiveFilter, isFalse);
      });

      test('setFilter with a status narrows results to that status',
          () async {
        await controller.setFilter(status: AccountStatus.suspended);

        expect(controller.hasActiveFilter, isTrue);
        expect(controller.statusFilter, AccountStatus.suspended);
        expect(controller.results, hasLength(1));
        expect(controller.results.single.displayName, 'Chong Mei Ling');
      });

      test('setFilter with a role narrows results to that role', () async {
        await controller.setFilter(role: UserRole.admin);

        expect(controller.results, hasLength(1));
        expect(controller.results.single.role, UserRole.admin);
      });

      test('setFilter with newThisWeek narrows to recently created profiles',
          () async {
        await controller.setFilter(newThisWeek: true);

        // Default seed: Alice Tan (2 days ago) and Farah Aziz (1 day ago)
        // are within the last 7 days; everyone else is older.
        expect(controller.results, hasLength(2));
        expect(
          controller.results.map((p) => p.displayName),
          containsAll(['Alice Tan', 'Farah Aziz']),
        );
      });

      test('clearFilter resets to the full unfiltered list', () async {
        await controller.setFilter(status: AccountStatus.suspended);
        expect(controller.results, hasLength(1));

        await controller.clearFilter();

        expect(controller.hasActiveFilter, isFalse);
        expect(controller.statusFilter, isNull);
        expect(controller.results, hasLength(6));
      });

      test('a filter composes with an active text query', () async {
        controller.setQuery('a'); // matches several names/emails
        await Future.delayed(_pastDebounce);

        await controller.setFilter(status: AccountStatus.active);

        expect(controller.results.every((p) => p.isActive), isTrue);
      });
    });
  });
}

class _FailingDirectoryRepository implements AdminUserDirectoryRepository {
  @override
  Future<List<Profile>> searchUsers({String? query}) async {
    throw Exception('mock backend unreachable');
  }

  @override
  Future<Profile?> getUserById(String userId) async => null;
}
