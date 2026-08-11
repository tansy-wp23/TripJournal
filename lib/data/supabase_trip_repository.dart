import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trip.dart';
import 'trip_repository.dart';
import 'trip_supabase_mapper.dart';

class SupabaseTripRepository implements TripRepository {
  SupabaseTripRepository(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SupabaseClient _client;
  final DateTime Function() _clock;

  @override
  Future<List<Trip>> getTrips(String userId) async {
    final rows = await _client
        .from('trips')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);
    return rows.map(tripFromSupabaseRow).toList();
  }

  @override
  Future<List<Trip>> getDeletedTrips(String userId) async {
    final rows = await _client
        .from('trips')
        .select()
        .eq('user_id', userId)
        .not('deleted_at', 'is', null);
    final now = _clock();
    return rows
        .map(tripFromSupabaseRow)
        .where((trip) => trip.isRecoverableAt(now))
        .toList();
  }

  @override
  Future<Trip?> getTrip(String id) async {
    final row = await _client.from('trips').select().eq('id', id).maybeSingle();
    return row == null ? null : tripFromSupabaseRow(row);
  }

  @override
  Future<void> addTrip(Trip trip) async {
    await _client.from('trips').insert(tripToSupabaseRow(trip));
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    await _client
        .from('trips')
        .update(tripEditableFieldsToSupabaseRow(trip))
        .eq('id', trip.id);
  }

  @override
  Future<void> moveToTrash(String id) async {
    await _client.rpc('move_trip_to_trash', params: {'p_trip_id': id});
  }

  @override
  Future<void> restoreTrip(Trip trip) async {
    final row = tripToSupabaseRow(trip);
    await _client.rpc(
      'restore_trip',
      params: {
        'p_trip_id': trip.id,
        'p_title': trip.title,
        'p_destination': trip.destination,
        'p_cover_photo_url': trip.coverPhotoPath,
        'p_start_date': row['start_date'],
        'p_end_date': row['end_date'],
        'p_notes': trip.notes,
      },
    );
  }
}
