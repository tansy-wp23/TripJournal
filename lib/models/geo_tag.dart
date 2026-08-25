class GeoTag {
  final double latitude;
  final double longitude;
  final String? placeName;
  final String? formattedAddress;
  final String? placeId;
  final String? locationTag;

  const GeoTag({
    required this.latitude,
    required this.longitude,
    this.placeName,
    this.formattedAddress,
    this.placeId,
    this.locationTag,
  });

  factory GeoTag.fromJson(Map<String, dynamic> json) {
    return GeoTag(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      placeName: json['placeName'] as String?,
      formattedAddress: json['formattedAddress'] as String?,
      placeId: json['placeId'] as String?,
      locationTag: json['locationTag'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'formattedAddress': formattedAddress,
      'placeId': placeId,
      'locationTag': locationTag,
    };
  }

  GeoTag copyWith({
    double? latitude,
    double? longitude,
    String? placeName,
    String? formattedAddress,
    String? placeId,
    String? locationTag,
  }) {
    return GeoTag(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      placeId: placeId ?? this.placeId,
      locationTag: locationTag ?? this.locationTag,
    );
  }
}
