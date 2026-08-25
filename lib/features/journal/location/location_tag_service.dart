import '../../../models/geo_tag.dart';

abstract interface class LocationTagService {
  Future<GeoTag> enrich(GeoTag location);
}

class NoopLocationTagService implements LocationTagService {
  const NoopLocationTagService();

  @override
  Future<GeoTag> enrich(GeoTag location) async {
    return location.copyWith(
      locationTag: location.placeName == null
          ? null
          : locationTagForPlaceName(location.placeName!),
    );
  }
}

String? locationTagForPlaceName(String placeName) {
  final compactName = placeName.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  return compactName.isEmpty ? null : '#$compactName';
}
