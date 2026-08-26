import '../../../models/geo_tag.dart';
import '../../../models/journal_entry.dart';

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

/// The final mapped stop on one day linked to the first mapped stop on the
/// immediately following day.
class TripMapDayConnector {
  const TripMapDayConnector({
    required this.fromDay,
    required this.toDay,
    required this.fromLatitude,
    required this.fromLongitude,
    required this.toLatitude,
    required this.toLongitude,
    required this.fromLabel,
    required this.toLabel,
  });

  final int fromDay;
  final int toDay;
  final double fromLatitude;
  final double fromLongitude;
  final double toLatitude;
  final double toLongitude;
  final String fromLabel;
  final String toLabel;

  String get id => 'day-$fromDay-to-day-$toDay';
}

/// Pure input for map surfaces. It contains no repository or Flutter map
/// dependencies so it can be used by the map UI and its fallback alike.
class TripMapModel {
  TripMapModel({
    required this.groups,
    required List<TripMapDayConnector> connectors,
    required this.availableDays,
    required this.mappedEntryCount,
    required this.unmappedEntryCount,
    required this.bounds,
  }) : connectors = List.unmodifiable(connectors);

  final List<TripMapMarkerGroup> groups;
  final List<TripMapDayConnector> connectors;
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
  required DateTime tripEndDate,
  int? selectedDay,
}) {
  final tripStartDay = _dateOnly(tripStartDate);
  final tripEndDay = _dateOnly(tripEndDate);
  final tripEntries = entries.where((entry) {
    final entryDay = _dateOnly(entry.createdAt);
    return !entryDay.isBefore(tripStartDay) && !entryDay.isAfter(tripEndDay);
  }).toList();
  final mapped = tripEntries.where((entry) => entry.location != null).toList();
  final availableDays =
      mapped
          .map((entry) => _dayNumber(entry.createdAt, tripStartDate))
          .toSet()
          .toList()
        ..sort();

  final mappedByDay = <int, List<JournalEntry>>{};
  for (final entry in mapped) {
    final dayNumber = _dayNumber(entry.createdAt, tripStartDate);
    mappedByDay.putIfAbsent(dayNumber, () => <JournalEntry>[]).add(entry);
  }
  for (final dayEntries in mappedByDay.values) {
    dayEntries.sort(_compareEntries);
  }

  final visible = selectedDay == null
      ? mapped
      : [
          for (final entry in mapped)
            if (_dayNumber(entry.createdAt, tripStartDate) >= 1 &&
                _dayNumber(entry.createdAt, tripStartDate) <= selectedDay)
              entry,
        ];

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

  final connectors = _connectorsFor(
    mappedByDay: mappedByDay,
    availableDays: availableDays,
    selectedDay: selectedDay,
  );
  return TripMapModel(
    groups: List.unmodifiable(groups),
    connectors: List.unmodifiable(connectors),
    availableDays: List.unmodifiable(availableDays),
    mappedEntryCount: mapped.length,
    unmappedEntryCount: tripEntries.length - mapped.length,
    bounds: _boundsFor(groups, connectors),
  );
}

List<TripMapDayConnector> _connectorsFor({
  required Map<int, List<JournalEntry>> mappedByDay,
  required List<int> availableDays,
  required int? selectedDay,
}) {
  final fromDays = selectedDay == null
      ? availableDays.where((day) => day >= 1)
      : availableDays.where((day) => day >= 1 && day < selectedDay);
  final connectors = <TripMapDayConnector>[];
  for (final fromDay in fromDays) {
    final fromEntries = mappedByDay[fromDay];
    final toEntries = mappedByDay[fromDay + 1];
    if (fromEntries == null ||
        fromEntries.isEmpty ||
        toEntries == null ||
        toEntries.isEmpty) {
      continue;
    }
    final fromLocation = fromEntries.last.location!;
    final toLocation = toEntries.first.location!;
    if (_sameMappedLocation(fromLocation, toLocation)) continue;
    connectors.add(
      TripMapDayConnector(
        fromDay: fromDay,
        toDay: fromDay + 1,
        fromLatitude: fromLocation.latitude,
        fromLongitude: fromLocation.longitude,
        toLatitude: toLocation.latitude,
        toLongitude: toLocation.longitude,
        fromLabel: _locationLabel(fromLocation),
        toLabel: _locationLabel(toLocation),
      ),
    );
  }
  return connectors;
}

bool _sameMappedLocation(GeoTag a, GeoTag b) {
  final aPlaceId = a.placeId?.trim();
  final bPlaceId = b.placeId?.trim();
  if (aPlaceId != null &&
      aPlaceId.isNotEmpty &&
      bPlaceId != null &&
      bPlaceId.isNotEmpty &&
      aPlaceId == bPlaceId &&
      _coordinateKey(a) == _coordinateKey(b)) {
    return true;
  }
  return _coordinateKey(a) == _coordinateKey(b);
}

double _normalizedLongitude(double longitude) {
  final normalized = ((longitude + 180) % 360 + 360) % 360 - 180;
  return normalized == 0 ? 0 : normalized;
}

String _locationLabel(GeoTag location) {
  final placeName = location.placeName?.trim();
  if (placeName != null && placeName.isNotEmpty) return placeName;
  final address = location.formattedAddress?.trim();
  if (address != null && address.isNotEmpty) return address;
  return '${location.latitude.toStringAsFixed(5)}, '
      '${location.longitude.toStringAsFixed(5)}';
}

String _groupKey(GeoTag location) {
  final coordinateKey = _coordinateKey(location);
  final placeId = location.placeId?.trim();
  if (placeId != null && placeId.isNotEmpty) {
    return 'place:$placeId:$coordinateKey';
  }
  return 'coord:$coordinateKey';
}

String _coordinateKey(GeoTag location) =>
    '${location.latitude.toStringAsFixed(6)},'
    '${_normalizedLongitude(location.longitude).toStringAsFixed(6)}';

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

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

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

TripMapBounds? _boundsFor(
  List<TripMapMarkerGroup> groups,
  List<TripMapDayConnector> connectors,
) {
  final points = <(double, double)>[
    for (final group in groups) (group.latitude, group.longitude),
    for (final connector in connectors) ...[
      (connector.fromLatitude, connector.fromLongitude),
      (connector.toLatitude, connector.toLongitude),
    ],
  ];
  if (points.length < 2) return null;

  var minLat = points.first.$1;
  var maxLat = points.first.$1;
  for (final point in points.skip(1)) {
    if (point.$1 < minLat) minLat = point.$1;
    if (point.$1 > maxLat) maxLat = point.$1;
  }
  final longitudeBounds = _smallestLongitudeBounds(points);
  return TripMapBounds(
    southWestLatitude: minLat,
    southWestLongitude: longitudeBounds.$1,
    northEastLatitude: maxLat,
    northEastLongitude: longitudeBounds.$2,
  );
}

(double, double) _smallestLongitudeBounds(List<(double, double)> points) {
  final longitudes = points.map((point) => point.$2).toList()..sort();
  var largestGap = -1.0;
  var west = longitudes.first;
  var east = longitudes.last;
  for (var index = 0; index < longitudes.length; index++) {
    final current = longitudes[index];
    final next = index == longitudes.length - 1
        ? longitudes.first + 360
        : longitudes[index + 1];
    final gap = next - current;
    if (gap > largestGap) {
      largestGap = gap;
      west = index == longitudes.length - 1
          ? longitudes.first
          : longitudes[index + 1];
      east = current;
    }
  }
  return (west, east);
}
