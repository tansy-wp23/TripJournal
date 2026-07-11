class GeoTag {
  final double latitude;
  final double longitude;
  final String? placeName;

  const GeoTag({
    required this.latitude,
    required this.longitude,
    this.placeName,
  });

  factory GeoTag.fromJson(Map<String, dynamic> json) {
    return GeoTag(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      placeName: json['placeName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
    };
  }

  GeoTag copyWith({
    double? latitude,
    double? longitude,
    String? placeName,
  }) {
    return GeoTag(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
    );
  }
}
