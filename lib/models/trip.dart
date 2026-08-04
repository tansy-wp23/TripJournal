DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Owned by the Journal module (see IMPLEMENTATION_PLAN_HOMEPAGE.md) as the
/// single source of truth; Trip Management (teammate) builds on top of this
/// same model/interface.
///
/// [startDate] / [endDate] are conceptually date-only. Callers should pass
/// already-normalised (midnight) values; the computed helpers below
/// re-normalise defensively so callers don't have to get this right.
class Trip {
  final String id;
  final String userId;
  final String title;
  final String? coverPhotoPath;
  final DateTime startDate;
  final DateTime endDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Trip({
    required this.id,
    required this.userId,
    required this.title,
    this.coverPhotoPath,
    required this.startDate,
    required this.endDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  DateTime? get trashExpiresAt =>
      deletedAt?.toUtc().add(const Duration(days: 30));

  bool isRecoverableAt(DateTime now) {
    final expiry = trashExpiresAt;
    return expiry != null && now.toUtc().isBefore(expiry);
  }

  int remainingRecoveryDaysAt(DateTime now) {
    final expiry = trashExpiresAt;
    if (expiry == null) return 0;
    final microseconds = expiry.difference(now.toUtc()).inMicroseconds;
    if (microseconds <= 0) return 0;
    return (microseconds - 1) ~/ Duration.microsecondsPerDay + 1;
  }

  /// Inclusive day count, e.g. a single-day trip (start == end) is 1.
  int get durationDays => _dateOnly(endDate).difference(_dateOnly(startDate)).inDays + 1;

  /// True if [date] falls within [startDate, endDate] inclusive.
  bool isActiveOn(DateTime date) {
    final day = _dateOnly(date);
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// Every calendar day from [startDate] to [endDate], inclusive.
  List<DateTime> get dayList {
    final start = _dateOnly(startDate);
    final days = durationDays;
    return List.generate(days, (i) => start.add(Duration(days: i)));
  }

  /// True if [other]'s date range intersects this trip's, inclusive of
  /// touching endpoints — this trip ending the day [other] starts DOES
  /// count as an overlap. See IMPLEMENTATION_PLAN_ENHANCEMENTS.md §6.
  bool overlapsWith(Trip other) {
    final aStart = _dateOnly(startDate);
    final aEnd = _dateOnly(endDate);
    final bStart = _dateOnly(other.startDate);
    final bEnd = _dateOnly(other.endDate);
    return !aStart.isAfter(bEnd) && !bStart.isAfter(aEnd);
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      coverPhotoPath: json['coverPhotoPath'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'coverPhotoPath': coverPhotoPath,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  Trip copyWith({
    String? id,
    String? userId,
    String? title,
    String? coverPhotoPath,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    );
  }
}
