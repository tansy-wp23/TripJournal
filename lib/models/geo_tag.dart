class GeoTag {
  final double latitude;
  final double longitude;
  final String? placeName;
  final String? locationTag;

  const GeoTag({
    required this.latitude,
    required this.longitude,
    this.placeName,
    this.locationTag,
  });

  factory GeoTag.fromJson(Map<String, dynamic> json) {
    return GeoTag(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      placeName: json['placeName'] as String?,
      locationTag: json['locationTag'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'locationTag': locationTag,
    };
  }

  GeoTag copyWith({
    double? latitude,
    double? longitude,
    String? placeName,
    String? locationTag,
  }) {
    return GeoTag(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      locationTag: locationTag ?? this.locationTag,
    );
  }
}
