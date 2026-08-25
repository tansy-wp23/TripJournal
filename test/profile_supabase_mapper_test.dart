import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/profile_supabase_mapper.dart';
import 'package:tripjournal/models/profile.dart';

void main() {
  group('profileFromSupabaseRow', () {
    test('maps every snake_case database field to the Profile model', () {
      final profile = profileFromSupabaseRow({
        'user_id': 'user-456',
        'email': 'sangyou@example.com',
        'display_name': 'Sang You',
        'avatar_url': 'profile-avatars/user-456/avatar.jpg',
        'role': 'user',
        'status': 'active',
        'deactivated_at': null,
        'last_login_at': '2026-08-01T02:03:04.000Z',
        'created_at': '2026-07-01T02:03:04.000Z',
        'updated_at': '2026-07-02T03:04:05.000Z',
      });

      expect(profile.userID, 'user-456');
      expect(profile.email, 'sangyou@example.com');
      expect(profile.displayName, 'Sang You');
      expect(profile.avatarUrl, 'profile-avatars/user-456/avatar.jpg');
      expect(profile.role, UserRole.user);
      expect(profile.status, AccountStatus.active);
      expect(profile.deactivatedAt, isNull);
      expect(profile.lastLoginAt, DateTime.utc(2026, 8, 1, 2, 3, 4));
      expect(profile.createdAt, DateTime.utc(2026, 7, 1, 2, 3, 4));
      expect(profile.updatedAt, DateTime.utc(2026, 7, 2, 3, 4, 5));
    });

    test('maps deactivated status and deactivated_at', () {
      final profile = profileFromSupabaseRow({
        'user_id': 'user-456',
        'email': 'sangyou@example.com',
        'display_name': 'Sang You',
        'avatar_url': null,
        'role': 'admin',
        'status': 'deactivated',
        'deactivated_at': '2026-08-10T04:05:06.000Z',
        'last_login_at': null,
        'created_at': '2026-07-01T02:03:04.000Z',
        'updated_at': '2026-07-02T03:04:05.000Z',
      });

      expect(profile.status, AccountStatus.deactivated);
      expect(profile.deactivatedAt, DateTime.utc(2026, 8, 10, 4, 5, 6));
      expect(profile.role, UserRole.admin);
      expect(profile.avatarUrl, isNull);
      expect(profile.lastLoginAt, isNull);
    });

    test('falls back to defaults for unknown role/status', () {
      final profile = profileFromSupabaseRow({
        'user_id': 'user-456',
        'email': 'sangyou@example.com',
        'display_name': 'Sang You',
        'avatar_url': null,
        'role': 'unknown-role',
        'status': 'unknown-status',
        'deactivated_at': null,
        'last_login_at': null,
        'created_at': '2026-07-01T02:03:04.000Z',
        'updated_at': '2026-07-02T03:04:05.000Z',
      });

      expect(profile.role, UserRole.user);
      expect(profile.status, AccountStatus.active);
    });

    test('maps onboarding fields when present', () {
      final profile = profileFromSupabaseRow({
        'user_id': 'user-456',
        'email': 'sangyou@example.com',
        'display_name': 'Sang You',
        'avatar_url': null,
        'role': 'user',
        'status': 'active',
        'deactivated_at': null,
        'last_login_at': null,
        'created_at': '2026-07-01T02:03:04.000Z',
        'updated_at': '2026-07-02T03:04:05.000Z',
        'date_of_birth': '2000-05-17',
        'country': 'Malaysia',
        'travel_interests': ['Scenery', 'Food'],
        'profile_completed': false,
      });

      expect(profile.dateOfBirth, DateTime.parse('2000-05-17'));
      expect(profile.country, 'Malaysia');
      expect(profile.travelInterests, ['Scenery', 'Food']);
      expect(profile.profileCompleted, isFalse);
    });

    test(
      'defaults onboarding fields when absent (a row from before this '
      'migration, or a minimal test fixture)',
      () {
        final profile = profileFromSupabaseRow({
          'user_id': 'user-456',
          'email': 'sangyou@example.com',
          'display_name': 'Sang You',
          'avatar_url': null,
          'role': 'user',
          'status': 'active',
          'deactivated_at': null,
          'last_login_at': null,
          'created_at': '2026-07-01T02:03:04.000Z',
          'updated_at': '2026-07-02T03:04:05.000Z',
        });

        expect(profile.dateOfBirth, isNull);
        expect(profile.country, isNull);
        expect(profile.travelInterests, isEmpty);
        // true, not the column's own `false` default — see the mapper's
        // doc comment: a row missing this key reads as already-onboarded.
        expect(profile.profileCompleted, isTrue);
      },
    );
  });

  group('profileToSupabaseRow', () {
    test('maps every model field to snake_case database columns', () {
      final row = profileToSupabaseRow(
        Profile(
          userID: 'user-456',
          email: 'sangyou@example.com',
          displayName: 'Sang You',
          avatarUrl: 'profile-avatars/user-456/avatar.jpg',
          role: UserRole.user,
          status: AccountStatus.active,
          createdAt: DateTime.utc(2026, 7, 1, 2, 3, 4),
          updatedAt: DateTime.utc(2026, 7, 2, 3, 4, 5),
        ),
      );

      expect(row, {
        'user_id': 'user-456',
        'email': 'sangyou@example.com',
        'display_name': 'Sang You',
        'avatar_url': 'profile-avatars/user-456/avatar.jpg',
        'role': 'user',
        'status': 'active',
        'deactivated_at': null,
        'last_login_at': null,
        'created_at': '2026-07-01T02:03:04.000Z',
        'updated_at': '2026-07-02T03:04:05.000Z',
        'date_of_birth': null,
        'country': null,
        'travel_interests': <String>[],
        'profile_completed': true,
      });
      expect(row, isNot(contains('userID')));
      expect(row, isNot(contains('displayName')));
    });

    test('formats date_of_birth as a date-only string, no time component', () {
      final row = profileToSupabaseRow(
        Profile(
          userID: 'user-456',
          email: 'sangyou@example.com',
          displayName: 'Sang You',
          dateOfBirth: DateTime.utc(2000, 5, 7),
          country: 'Malaysia',
          travelInterests: const ['Scenery', 'Food'],
          profileCompleted: false,
          createdAt: DateTime.utc(2026, 7, 1, 2, 3, 4),
          updatedAt: DateTime.utc(2026, 7, 2, 3, 4, 5),
        ),
      );

      expect(row['date_of_birth'], '2000-05-07');
      expect(row['country'], 'Malaysia');
      expect(row['travel_interests'], ['Scenery', 'Food']);
      expect(row['profile_completed'], isFalse);
    });
  });

  test('editable row excludes ownership and lifecycle columns', () {
    final row = profileEditableFieldsToSupabaseRow(
      Profile(
        userID: 'user-456',
        email: 'sangyou@example.com',
        displayName: 'Sang You',
        avatarUrl: 'profile-avatars/user-456/avatar.jpg',
        role: UserRole.user,
        status: AccountStatus.deactivated,
        deactivatedAt: DateTime.utc(2026, 8, 10),
        lastLoginAt: DateTime.utc(2026, 8, 1),
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 2),
      ),
    );

    expect(row, {
      'email': 'sangyou@example.com',
      'display_name': 'Sang You',
      'avatar_url': 'profile-avatars/user-456/avatar.jpg',
      'role': 'user',
      'status': 'deactivated',
      'deactivated_at': '2026-08-10T00:00:00.000Z',
      'last_login_at': '2026-08-01T00:00:00.000Z',
      'date_of_birth': null,
      'country': null,
      'travel_interests': <String>[],
      'profile_completed': true,
    });
    expect(row, isNot(contains('user_id')));
    expect(row, isNot(contains('created_at')));
    expect(row, isNot(contains('updated_at')));
  });
}