/// The custom URL scheme registered in the Android manifest and iOS
/// Info.plist (see the deep-link intent-filter / CFBundleURLTypes entries
/// there). Pasted into a mobile browser's address bar, the OS offers to open
/// this app directly - there's no hosted website behind it, so it only works
/// when the app is already installed.
const String tripLinkScheme = 'tripjournal';
const String _tripLinkHost = 'trip';

/// Builds the shareable link for [tripId], e.g. `tripjournal://trip/<id>`.
String tripLinkFor(String tripId) => '$tripLinkScheme://$_tripLinkHost/$tripId';

/// Extracts the trip id from a `tripjournal://trip/<id>` link, or `null` if
/// [uri] isn't one (wrong scheme/host, or no id segment).
String? tripIdFromLink(Uri uri) {
  if (uri.scheme != tripLinkScheme || uri.host != _tripLinkHost) return null;
  if (uri.pathSegments.isEmpty) return null;
  final id = uri.pathSegments.first.trim();
  return id.isEmpty ? null : id;
}
