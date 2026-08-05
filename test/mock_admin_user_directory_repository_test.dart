import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_admin_user_directory_repository.dart';
import 'package:tripjournal/data/mock_admin_user_store.dart';

void main() {
  late MockAdminUserStore store;
  late MockAdminUserDirectoryRepository repository;

  setUp(() {
    store = MockAdminUserStore();
    repository = MockAdminUserDirectoryRepository(store);
  });

  group('MockAdminUserDirectoryRepository', () {
    test('searchUsers with no query returns every seeded user', () async {
      final results = await repository.searchUsers();

      expect(results.length, store.profiles.length);
    });

    test('searchUsers matches by partial display name, case-insensitive',
        () async {
      final results = await repository.searchUsers(query: 'alice');

      expect(results, hasLength(1));
      expect(results.single.displayName, 'Alice Tan');
    });

    test('searchUsers matches by partial email', () async {
      final results = await repository.searchUsers(query: 'david.wong');

      expect(results, hasLength(1));
      expect(results.single.userID, 'user-104');
    });

    test('searchUsers with no match returns an empty list', () async {
      final results = await repository.searchUsers(query: 'nonexistent');

      expect(results, isEmpty);
    });

    test('getUserById returns the matching profile', () async {
      final profile = await repository.getUserById('user-101');

      expect(profile, isNotNull);
      expect(profile!.displayName, 'Alice Tan');
    });

    test('getUserById returns null for an unknown id', () async {
      final profile = await repository.getUserById('does-not-exist');

      expect(profile, isNull);
    });
  });
}