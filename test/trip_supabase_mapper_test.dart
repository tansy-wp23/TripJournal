import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/trip_supabase_mapper.dart';
import 'package:tripjournal/models/trip.dart';

void main() {
  group('tripFromSupabaseRow', () {
    test('maps every snake_case database field to the Trip model', () {
      final trip = tripFromSupabaseRow({
        'id': 'trip-123',
        'user_id': 'user-456',
        'title': 'Penang Weekend',
        'destination': 'Penang, Malaysia',
        'cover_photo_url': 'trip-covers/penang.jpg',
        'start_date': '2026-08-05',
        'end_date': '2026-08-07',
        'notes': 'Try the char kway teow.',
        'summary': 'A short Penang recap.',
        'created_at': '2026-07-01T02:03:04.000Z',
        'updated_at': '2026-07-02T03:04:05.000Z',
        'deleted_at': '2026-08-10T04:05:06.000Z',
      });

      expect(trip.id, 'trip-123');
      expect(trip.userId, 'user-456');
      expect(trip.title, 'Penang Weekend');
      expect(trip.destination, 'Penang, Malaysia');
      expect(trip.coverPhotoPath, 'trip-covers/penang.jpg');
      expect(trip.startDate, DateTime(2026, 8, 5));
      expect(trip.endDate, DateTime(2026, 8, 7));
      expect(trip.notes, 'Try the char kway teow.');
      expect(trip.summary, 'A short Penang recap.');
      expect(trip.createdAt, DateTime.utc(2026, 7, 1, 2, 3, 4));
      expect(trip.updatedAt, DateTime.utc(2026, 7, 2, 3, 4, 5));
      expect(trip.deletedAt, DateTime.utc(2026, 8, 10, 4, 5, 6));
    });
  });

  group('tripToSupabaseRow', () {
    test('maps every model field to snake_case database columns', () {
      final row = tripToSupabaseRow(
        Trip(
          id: 'trip-123',
          userId: 'user-456',
          title: 'Penang Weekend',
          destination: 'Penang, Malaysia',
          coverPhotoPath: 'trip-covers/penang.jpg',
          startDate: DateTime(2026, 8, 5, 15, 30),
          endDate: DateTime(2026, 8, 7, 23, 59),
          notes: 'Try the char kway teow.',
          summary: 'A short Penang recap.',
          createdAt: DateTime.utc(2026, 7, 1, 2, 3, 4),
          updatedAt: DateTime.utc(2026, 7, 2, 3, 4, 5),
        ),
      );

      expect(row, {
        'id': 'trip-123',
        'user_id': 'user-456',
        'title': 'Penang Weekend',
        'destination': 'Penang, Malaysia',
        'cover_photo_url': 'trip-covers/penang.jpg',
        'start_date': '2026-08-05',
        'end_date': '2026-08-07',
        'notes': 'Try the char kway teow.',
        'summary': 'A short Penang recap.',
        'created_at': '2026-07-01T02:03:04.000Z',
        'updated_at': '2026-07-02T03:04:05.000Z',
        'deleted_at': null,
      });
      expect(row['start_date'], '2026-08-05');
      expect(row['end_date'], '2026-08-07');
      expect(row['deleted_at'], isNull);
      expect(row['summary'], 'A short Penang recap.');
      expect(row, isNot(contains('createdAt')));
    });
  });

  test('editable row excludes ownership and purge lifecycle columns', () {
    final row = tripEditableFieldsToSupabaseRow(
      Trip(
        id: 'trip-123',
        userId: 'user-456',
        title: 'Penang Weekend',
        destination: 'Penang, Malaysia',
        coverPhotoPath: 'trip-covers/penang.jpg',
        startDate: DateTime(2026, 8, 5),
        endDate: DateTime(2026, 8, 7),
        notes: 'Try the char kway teow.',
        summary: 'A short Penang recap.',
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 2),
        deletedAt: DateTime.utc(2026, 8, 10),
      ),
    );

    expect(row, {
      'title': 'Penang Weekend',
      'destination': 'Penang, Malaysia',
      'cover_photo_url': 'trip-covers/penang.jpg',
      'start_date': '2026-08-05',
      'end_date': '2026-08-07',
      'notes': 'Try the char kway teow.',
      'summary': 'A short Penang recap.',
    });
  });

  test('missing summary remains compatible with legacy rows', () {
    final trip = tripFromSupabaseRow({
      'id': 'trip-legacy',
      'user_id': 'user-456',
      'title': 'Legacy Trip',
      'destination': null,
      'cover_photo_url': null,
      'start_date': '2026-08-05',
      'end_date': '2026-08-07',
      'notes': null,
      'created_at': '2026-07-01T02:03:04.000Z',
      'updated_at': '2026-07-02T03:04:05.000Z',
      'deleted_at': null,
    });

    expect(trip.summary, isNull);
  });
}
