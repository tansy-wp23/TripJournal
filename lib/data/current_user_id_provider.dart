abstract interface class CurrentUserIdProvider {
  String requireUserId();
}

final class UnauthenticatedTripUserException implements Exception {
  const UnauthenticatedTripUserException();

  @override
  String toString() => 'Please sign in to manage trips.';
}
