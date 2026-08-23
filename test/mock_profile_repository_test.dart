import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_profile_repository.dart';
import 'package:tripjournal/models/profile.dart';

void main() {
  group('MockProfileRepository', () {
    test('active state seeds an active profile for the mock user', () async {
      final repo = MockProfileRepository(state: MockProfileState.active);

      final profile = await repo.getProfile('user-001');

      expect(profile, isNotNull);
      expect(profile!.status, AccountStatus.active);
      expect(profile.isActive, isTrue);
      expect(profile.email, 'sangyou@example.com');
    });

    test('deactivated state seeds a deactivated profile', () async {
      final repo = MockProfileRepository(state: MockProfileState.deactivated);

      final profile = await repo.getProfile('user-001');

      expect(profile, isNotNull);
      expect(profile!.status, AccountStatus.deactivated);
      expect(profile.isDeactivated, isTrue);
      expect(profile.deactivatedAt, isNotNull);
    });

    test('firstTime state has no profile until createProfileIfMissing',
        () async {
      final repo = MockProfileRepository(state: MockProfileState.firstTime);

      expect(await repo.getProfile('user-001'), isNull);

      final created = await repo.createProfileIfMissing(
        userId: 'user-001',
        email: 'sangyou@example.com',
        displayName: 'Sang You',
      );

      expect(created.status, AccountStatus.active);
      expect(created.userID, 'user-001');
      expect((await repo.getProfile('user-001'))?.displayName, 'Sang You');
    });

    test('createProfileIfMissing stamps last_login_at on an existing profile',
        () async {
      final repo = MockProfileRepository(state: MockProfileState.active);

      final existing = await repo.getProfile('user-001');
      expect(existing!.lastLoginAt, isNull);

      final result = await repo.createProfileIfMissing(
        userId: 'user-001',
        email: 'other@example.com',
        displayName: 'Other',
      );

      expect(result.userID, existing.userID);
      expect(result.email, existing.email);
      expect(result.displayName, existing.displayName);
      expect(result.lastLoginAt, isNotNull);
    });

    test('getProfile returns null for an unknown user', () async {
      final repo = MockProfileRepository(state: MockProfileState.active);

      expect(await repo.getProfile('someone-else'), isNull);
    });

    test('updateProfile replaces the stored profile', () async {
      final repo = MockProfileRepository(state: MockProfileState.active);
      final current = await repo.getProfile('user-001');

      final updated = await repo.updateProfile(
        current!.copyWith(displayName: 'Renamed'),
      );

      expect(updated.displayName, 'Renamed');
      expect((await repo.getProfile('user-001'))?.displayName, 'Renamed');
    });
  });
}