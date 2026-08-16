import '../../../models/journal_entry.dart';
import '../../../models/geo_tag.dart';

/// The smallest rectangle containing all visible marker groups.
class TripMapBounds {
  const TripMapBounds({
    required this.southWestLatitude,
    required this.southWestLongitude,
    required this.northEastLatitude,
    required this.northEastLongitude,
  });

  final double southWestLatitude;
  final double southWestLongitude;
  final double northEastLatitude;
  final double northEastLongitude;
}

/// Entries sharing one map marker, either by Place ID or normalized
/// coordinates.
class TripMapMarkerGroup {
  const TripMapMarkerGroup({
    required this.key,
    required this.latitude,
    required this.longitude,
    required this.entries,
    required this.dayNumber,
  });

  final String key;
  final double latitude;
  final double longitude;
  final List<JournalEntry> entries;
  final int dayNumber;
}

/// Pure input for map surfaces. It contains no repository or Flutter map
/// dependencies so it can be used by the map UI and its fallback alike.
class TripMapModel {
  const TripMapModel({
    required this.groups,
    required this.availableDays,
    required this.mappedEntryCount,
    required this.unmappedEntryCount,
    required this.bounds,
  });

  final List<TripMapMarkerGroup> groups;
  final List<int> availableDays;
  final int mappedEntryCount;
  final int unmappedEntryCount;
  final TripMapBounds? bounds;
}

/// Derives chronologically ordered marker groups for a trip.
///
/// Entries with a non-blank Place ID are grouped by its trimmed value.
/// Legacy coordinate-only locations are grouped using six-decimal rounded
/// latitude and longitude keys. Day values are based on each DateTime's local
/// calendar date, rather than elapsed hours from the trip start.
TripMapModel buildTripMapModel({
  required List<JournalEntry> entries,
  required DateTime tripStartDate,
  int? selectedDay,
}) {
  final mapped = entries.where((entry) => entry.location != null).toList();
  final availableDays =
      mapped
          .map((entry) => _dayNumber(entry.createdAt, tripStartDate))
          .toSet()
          .toList()
        ..sort();

  final visible = selectedDay == null
      ? mapped
      : mapped
            .where(
              (entry) =>
                  _dayNumber(entry.createdAt, tripStartDate) == selectedDay,
            )
            .toList();

  final grouped = <String, List<JournalEntry>>{};
  for (final entry in visible) {
    final location = entry.location!;
    final key = _groupKey(location);
    grouped.putIfAbsent(key, () => <JournalEntry>[]).add(entry);
  }

  final groups = <TripMapMarkerGroup>[];
  for (final groupedEntry in grouped.entries) {
    final groupEntries = List<JournalEntry>.of(groupedEntry.value)
      ..sort(_compareEntries);
    final firstLocation = groupEntries.first.location!;
    groups.add(
      TripMapMarkerGroup(
        key: groupedEntry.key,
        latitude: firstLocation.latitude,
        longitude: firstLocation.longitude,
        entries: List.unmodifiable(groupEntries),
        dayNumber: _dayNumber(groupEntries.first.createdAt, tripStartDate),
      ),
    );
  }
  groups.sort(_compareGroups);

  return TripMapModel(
    groups: List.unmodifiable(groups),
    availableDays: List.unmodifiable(availableDays),
    mappedEntryCount: mapped.length,
    unmappedEntryCount: entries.length - mapped.length,
    bounds: _boundsFor(groups),
  );
}

String _groupKey(GeoTag location) {
  final placeId = location.placeId?.trim();
  if (placeId != null && placeId.isNotEmpty) {
    return 'place:$placeId';
  }
  return 'coord:${location.latitude.toStringAsFixed(6)},'
      '${location.longitude.toStringAsFixed(6)}';
}

int _dayNumber(DateTime entryDate, DateTime tripStartDate) {
  final entryDay = _dateOnly(entryDate);
  final startDay = _dateOnly(tripStartDate);

  // Use UTC only for the subtraction so a daylight-saving transition cannot
  // turn two adjacent local calendar days into a 23-hour duration.
  final entryOrdinal = DateTime.utc(
    entryDay.year,
    entryDay.month,
    entryDay.day,
  );
  final startOrdinal = DateTime.utc(
    startDay.year,
    startDay.month,
    startDay.day,
  );
  return entryOrdinal.difference(startOrdinal).inDays + 1;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _compareEntries(JournalEntry a, JournalEntry b) {
  final byCreatedAt = a.createdAt.compareTo(b.createdAt);
  if (byCreatedAt != 0) return byCreatedAt;
  return a.id.compareTo(b.id);
}

int _compareGroups(TripMapMarkerGroup a, TripMapMarkerGroup b) {
  final byFirstEntry = _compareEntries(a.entries.first, b.entries.first);
  if (byFirstEntry != 0) return byFirstEntry;
  return a.key.compareTo(b.key);
}

TripMapBounds? _boundsFor(List<TripMapMarkerGroup> groups) {
  if (groups.length < 2) return null;

  var minLat = groups.first.latitude;
  var maxLat = groups.first.latitude;
  var minLng = groups.first.longitude;
  var maxLng = groups.first.longitude;
  for (final group in groups.skip(1)) {
    if (group.latitude < minLat) minLat = group.latitude;
    if (group.latitude > maxLat) maxLat = group.latitude;
    if (group.longitude < minLng) minLng = group.longitude;
    if (group.longitude > maxLng) maxLng = group.longitude;
  }
  return TripMapBounds(
    southWestLatitude: minLat,
    southWestLongitude: minLng,
    northEastLatitude: maxLat,
    northEastLongitude: maxLng,
  );
}
