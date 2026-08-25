import '../models/geo_tag.dart';
import '../models/health_log.dart';
import '../models/journal_entry.dart';
import '../models/meal.dart';
import '../models/meal_type.dart';
import '../models/mood.dart';
import '../models/portion_size.dart';

/// Row <-> model mapping for the journal tables — mirrors
/// `trip_supabase_mapper.dart`, kept out of the repository so the shape of the
/// tables is stated in exactly one place and can be unit-tested without a
/// client.
///
/// Three tables back one [JournalEntry]: `journal_entries`, its one
/// `health_logs` row, and that log's `meals`. Reads pull all three in a single
/// embedded PostgREST select; writes go table by table (see
/// `SupabaseJournalRepository`).

JournalEntry journalEntryFromSupabaseRow(Map<String, dynamic> row) {
  return JournalEntry(
    id: row['id'] as String,
    tripId: row['trip_id'] as String,
    // Both columns are NOT NULL in practice, but a body-only entry stores an
    // empty title and the "title OR body" rule means either can be blank —
    // treating a null as '' keeps a hand-inserted row from crashing the list.
    title: (row['title'] as String?) ?? '',
    body: (row['body'] as String?) ?? '',
    mood: _moodFromRow(row['mood']),
    photoPaths: _stringList(row['photo_urls']),
    location: _geoTagFromRow(row['location']),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    healthLog: healthLogFromEmbeddedRows(row['health_logs']),
  );
}

/// The embedded `health_logs(*, meals(*))` payload.
///
/// PostgREST returns a *list* here: the foreign key lives on `health_logs`, so
/// it reads as one-to-many even though the app only ever writes one log per
/// entry. Accepts a bare map too, in case a unique constraint is added later
/// and PostgREST starts collapsing it to an object.
HealthLog? healthLogFromEmbeddedRows(Object? embedded) {
  final row = switch (embedded) {
    final Map<String, dynamic> single => single,
    final List<dynamic> many =>
      many.isEmpty ? null : many.first as Map<String, dynamic>,
    _ => null,
  };
  if (row == null) return null;
  return healthLogFromSupabaseRow(row);
}

HealthLog healthLogFromSupabaseRow(Map<String, dynamic> row) {
  final mealRows = row['meals'];
  return HealthLog(
    id: row['id'] as String,
    entryId: row['entry_id'] as String,
    steps: (row['steps'] as num?)?.toInt() ?? 0,
    caloriesEaten: (row['calories_eaten'] as num?)?.toInt() ?? 0,
    caloriesBurned: (row['calories_burned'] as num?)?.toInt(),
    meals: mealRows is List
        ? mealRows
              .map((meal) => mealFromSupabaseRow(meal as Map<String, dynamic>))
              .toList()
        : const [],
    aiAdvice: row['ai_advice'] as String?,
  );
}

Meal mealFromSupabaseRow(Map<String, dynamic> row) {
  return Meal(
    id: row['id'] as String,
    name: (row['name'] as String?) ?? '',
    calories: (row['calories'] as num?)?.toInt() ?? 0,
    mealType: _enumFromRow(row['meal_type'], MealType.values, MealType.snack),
    portion: _enumFromRow(
      row['portion'],
      PortionSize.values,
      PortionSize.regular,
    ),
    photoPath: row['photo_url'] as String?,
  );
}

/// The full insert shape, including the columns RLS checks.
///
/// `user_id` is not on [JournalEntry] — nothing in the app models entry
/// ownership, because until now the only repository was in-memory. It is passed
/// in from the repository's [CurrentUserIdProvider] instead of being invented
/// here, so there is one answer to "who is writing this" per process.
Map<String, dynamic> journalEntryToSupabaseRow(
  JournalEntry entry, {
  required String userId,
}) {
  return {
    'id': entry.id,
    'user_id': userId,
    'trip_id': entry.tripId,
    ...journalEntryEditableFieldsToSupabaseRow(entry),
    'created_at': entry.createdAt.toIso8601String(),
  };
}

/// What an edit is allowed to change.
///
/// Deliberately excludes `id`, `user_id`, `trip_id` and `created_at`: an entry
/// does not change owner or trip, and `created_at` is the entry's timestamp for
/// day-grouping (see `deriveEntryTimestamp`) rather than a row audit field, so
/// rewriting it on every save would silently move backfilled entries.
Map<String, dynamic> journalEntryEditableFieldsToSupabaseRow(
  JournalEntry entry,
) {
  return {
    'title': entry.title,
    'body': entry.body,
    'mood': entry.mood.name,
    'photo_urls': entry.photoPaths,
    'location': entry.location?.toJson(),
    // Denormalised calendar day of the entry timestamp. Written as date-only so
    // the value is valid whether the column is `date` or `timestamptz`.
    'entry_date': formatDateOnly(entry.createdAt),
    'updated_at': entry.updatedAt.toIso8601String(),
  };
}

Map<String, dynamic> healthLogToSupabaseRow(
  HealthLog log, {
  required String userId,
}) {
  return {
    'id': log.id,
    'user_id': userId,
    'entry_id': log.entryId,
    'steps': log.steps,
    'calories_eaten': log.caloriesEaten,
    'calories_burned': log.caloriesBurned,
    'ai_advice': log.aiAdvice,
  };
}

Map<String, dynamic> mealToSupabaseRow(
  Meal meal, {
  required String userId,
  required String healthLogId,
}) {
  return {
    'id': meal.id,
    'user_id': userId,
    'health_log_id': healthLogId,
    'name': meal.name,
    'calories': meal.calories,
    'meal_type': meal.mealType.name,
    'portion': meal.portion.name,
    'photo_url': meal.photoPath,
  };
}

String formatDateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}

GeoTag? _geoTagFromRow(Object? value) {
  if (value is! Map) return null;
  final json = Map<String, dynamic>.from(value);
  // Latitude/longitude are the only required parts of a GeoTag. A blob missing
  // them is corrupt rather than "no location", but the entry around it is still
  // perfectly readable — so drop the tag instead of failing the whole list.
  if (json['latitude'] is! num || json['longitude'] is! num) return null;
  final latitude = (json['latitude'] as num).toDouble();
  final longitude = (json['longitude'] as num).toDouble();
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    return null;
  }
  return GeoTag.fromJson(json);
}

/// Unknown enum values degrade to a default rather than throwing.
///
/// These columns are plain text, so a row written by a future build — or by
/// hand in the SQL editor — can carry a name this build has never heard of.
/// One such row should not make the whole trip's timeline unreadable.
Mood _moodFromRow(Object? value) =>
    _enumFromRow(value, Mood.values, Mood.neutral);

T _enumFromRow<T extends Enum>(Object? value, List<T> values, T fallback) {
  if (value is! String) return fallback;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return fallback;
}
