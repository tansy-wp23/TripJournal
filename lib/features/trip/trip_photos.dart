import '../../models/journal_entry.dart';
import '../../models/trip.dart';
import 'trip_day_groups.dart';

/// Where a photo came from. Trip pictures and food pictures are uploaded
/// through two separate pickers (`CreateEditEntryScreen` vs the meal dialog in
/// `HealthLogForm`) and land in two separate places, but they share one
/// timeline once they reach the carousel and the slideshow.
enum TripPhotoKind { entry, meal }

/// One photo, flattened out of the trip → day → entry → (photo | meal) tree
/// and tagged with everything the carousel and slideshow need to caption it
/// and navigate back to its source.
class TripPhoto {
  const TripPhoto({
    required this.path,
    required this.kind,
    required this.entryId,
    required this.date,
    required this.dayNumber,
    this.caption,
  });

  final String path;
  final TripPhotoKind kind;

  /// The entry this photo belongs to — a meal photo points at the entry that
  /// owns the health log, not at the meal, since the meal has no screen of
  /// its own to navigate to.
  final String entryId;

  /// Date-only, matching [DayGroup.date].
  final DateTime date;

  /// 1-based within the trip, matching [DayGroup.dayNumber].
  final int dayNumber;

  final String? caption;
}

/// Flattens every photo in [trip] into one ordered list: day, then entry, then
/// that entry's own photos followed by its meal photos.
///
/// Built on top of [buildDayGroups] so day numbering and the "entries outside
/// the trip's date range are dropped" rule stay identical to the timeline the
/// user sees — the slideshow can never disagree with the day list about which
/// day a photo belongs to.
///
/// Ordering is deliberately made *total* here. [buildDayGroups] sorts by
/// `createdAt` alone, and `List.sort` is not stable, while
/// `deriveEntryTimestamp` stamps every backfilled past day at exactly noon —
/// so two entries backfilled to the same day compare equal and can swap places
/// between rebuilds. A slideshow position is handed across a `Navigator.push`,
/// so an unstable order would mean "tap photo 7" opening a different photo
/// after an unrelated save. Breaking ties on `id` pins it down. This is done
/// here rather than in [buildDayGroups] to leave the timeline's own behaviour
/// (and its tests) untouched.
List<TripPhoto> buildTripPhotos(Trip trip, List<JournalEntry> entries) {
  final photos = <TripPhoto>[];

  for (final group in buildDayGroups(trip, entries)) {
    final ordered = List<JournalEntry>.of(group.entries)
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

    for (final entry in ordered) {
      for (final path in entry.photoPaths) {
        photos.add(TripPhoto(
          path: path,
          kind: TripPhotoKind.entry,
          entryId: entry.id,
          date: group.date,
          dayNumber: group.dayNumber,
          caption: entry.displayTitle,
        ));
      }

      for (final meal in entry.healthLog?.meals ?? const []) {
        final path = meal.photoPath;
        if (path == null) continue;
        photos.add(TripPhoto(
          path: path,
          kind: TripPhotoKind.meal,
          entryId: entry.id,
          date: group.date,
          dayNumber: group.dayNumber,
          caption: meal.name,
        ));
      }
    }
  }

  return photos;
}

/// The position in [photos] to open the slideshow at for [dayNumber].
///
/// Falls *forward* to the next day that actually has photos, so tapping a
/// photoless day still lands somewhere sensible rather than failing; clamps to
/// the last photo when [dayNumber] is past everything, and returns 0 for an
/// empty list so callers never have to guard against -1.
int firstIndexForDay(List<TripPhoto> photos, int dayNumber) {
  if (photos.isEmpty) return 0;
  final index = photos.indexWhere((photo) => photo.dayNumber >= dayNumber);
  return index == -1 ? photos.length - 1 : index;
}
