import '../features/trip/mock_user.dart';
import 'current_user_id_provider.dart';

final class MockCurrentUserIdProvider implements CurrentUserIdProvider {
  @override
  String requireUserId() => kMockUserId;
}
