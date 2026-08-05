import '../models/trip.dart';

Trip tripFromSupabaseRow(Map<String, dynamic> row) {
  return Trip(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    title: row['title'] as String,
    coverPhotoPath: row['cover_photo_url'] as String?,
    startDate: DateTime.parse(row['start_date'] as String),
    endDate: DateTime.parse(row['end_date'] as String),
    notes: row['notes'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    deletedAt: row['deleted_at'] == null
        ? null
        : DateTime.parse(row['deleted_at'] as String),
  );
}

Map<String, dynamic> tripToSupabaseRow(Trip trip) {
  return {
    'id': trip.id,
    'user_id': trip.userId,
    'title': trip.title,
    'cover_photo_url': trip.coverPhotoPath,
    'start_date': _formatDateOnly(trip.startDate),
    'end_date': _formatDateOnly(trip.endDate),
    'notes': trip.notes,
    'created_at': trip.createdAt.toIso8601String(),
    'updated_at': trip.updatedAt.toIso8601String(),
    'deleted_at': trip.deletedAt?.toIso8601String(),
  };
}

Map<String, dynamic> tripEditableFieldsToSupabaseRow(Trip trip) {
  return {
    'title': trip.title,
    'cover_photo_url': trip.coverPhotoPath,
    'start_date': _formatDateOnly(trip.startDate),
    'end_date': _formatDateOnly(trip.endDate),
    'notes': trip.notes,
  };
}

String _formatDateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
