import 'geo_tag.dart';
import 'health_log.dart';
import 'mood.dart';

class JournalEntry {
  final String id;
  final String tripId;
  final String title;
  final String body;
  final Mood mood;
  final List<String> photoPaths;
  final GeoTag? location;
  final DateTime? entryDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime creationOrderAt;
  final HealthLog? healthLog;

  const JournalEntry({
    required this.id,
    required this.tripId,
    required this.title,
    required this.body,
    required this.mood,
    required this.photoPaths,
    this.location,
    this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    DateTime? creationOrderAt,
    this.healthLog,
  }) : creationOrderAt = creationOrderAt ?? updatedAt;

  /// The entry's logical, timezone-independent journal day.
  ///
  /// Supabase persists this separately as `entry_date`. Older local data and
  /// callers that predate that field fall back to the local calendar day of
  /// [createdAt].
  DateTime get calendarDate {
    final value = entryDate ?? createdAt.toLocal();
    return DateTime(value.year, value.month, value.day);
  }

  /// A title is never required — the "title OR body" rule (see
  /// IMPLEMENTATION_PLAN_VALIDATION.md) allows a body-only entry. Anywhere
  /// the UI needs one label for an entry (lists, app bars) should use this
  /// instead of the raw [title], which may be empty.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title;
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) return '(Untitled entry)';
    return trimmedBody.length > 40
        ? '${trimmedBody.substring(0, 40)}…'
        : trimmedBody;
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final updatedAt = DateTime.parse(json['updatedAt'] as String);
    return JournalEntry(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      mood: Mood.values.byName(json['mood'] as String),
      photoPaths: (json['photoPaths'] as List<dynamic>)
          .map((p) => p as String)
          .toList(),
      location: json['location'] == null
          ? null
          : GeoTag.fromJson(json['location'] as Map<String, dynamic>),
      entryDate: json['entryDate'] == null
          ? null
          : DateTime.tryParse(json['entryDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: updatedAt,
      creationOrderAt: json['creationOrderAt'] == null
          ? null
          : DateTime.parse(json['creationOrderAt'] as String),
      healthLog: json['healthLog'] == null
          ? null
          : HealthLog.fromJson(json['healthLog'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'title': title,
      'body': body,
      'mood': mood.name,
      'photoPaths': photoPaths,
      'location': location?.toJson(),
      'entryDate': calendarDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'creationOrderAt': creationOrderAt.toIso8601String(),
      'healthLog': healthLog?.toJson(),
    };
  }

  JournalEntry copyWith({
    String? id,
    String? tripId,
    String? title,
    String? body,
    Mood? mood,
    List<String>? photoPaths,
    GeoTag? location,
    bool clearLocation = false,
    DateTime? entryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? creationOrderAt,
    HealthLog? healthLog,
  }) {
    assert(!(clearLocation && location != null));
    return JournalEntry(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      body: body ?? this.body,
      mood: mood ?? this.mood,
      photoPaths: photoPaths ?? this.photoPaths,
      location: clearLocation ? null : (location ?? this.location),
      entryDate: entryDate ?? this.entryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      creationOrderAt: creationOrderAt ?? this.creationOrderAt,
      healthLog: healthLog ?? this.healthLog,
    );
  }
}
