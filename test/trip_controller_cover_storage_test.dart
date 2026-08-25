import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/journal_repository.dart';
import 'package:tripjournal/data/mock_trip_cover_storage.dart';
import 'package:tripjournal/data/trip_cover_storage.dart';
import 'package:tripjournal/data/trip_repository.dart';
import 'package:tripjournal/features/trip/controller/trip_controller.dart';
import 'package:tripjournal/features/trip/mock_user.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';
import 'package:tripjournal/models/trip.dart';

void main() {
  late _RecordingTripRepository repository;
  late _RecordingTripCoverStorage storage;
  late _RecordingJournalRepository journalRepository;
  late TripController controller;
  late List<String> events;

  setUp(() async {
    events = [];
    repository = _RecordingTripRepository(events);
    storage = _RecordingTripCoverStorage(events);
    journalRepository = _RecordingJournalRepository();
    controller = TripController(repository, journalRepository, storage);
    await controller.loadTrips(kMockUserId);
  });

  test('create validates before uploading a local cover', () async {
    final invalid = _trip(
      id: 'new-trip',
      title: '',
      coverPhotoPath: r'C:\photos\cover.jpg',
    );

    final error = await controller.createTrip(invalid);

    expect(error, 'Please enter a trip title.');
    expect(storage.uploads, isEmpty);
    expect(repository.addedTrips, isEmpty);
  });

  test('create uploads a local cover and persists the returned URL', () async {
    final trip = _trip(id: 'new-trip', coverPhotoPath: r'C:\photos\cover.jpg');

    final error = await controller.createTrip(trip);

    expect(error, isNull);
    expect(storage.uploads, [
      const _UploadCall(
        userId: kMockUserId,
        tripId: 'new-trip',
        localPath: r'C:\photos\cover.jpg',
      ),
    ]);
    expect(repository.addedTrips.single.coverPhotoPath, storage.uploadedUrl);
  });

  test(
    'invalid byte-backed cover is rejected before repository write',
    () async {
      final validatingController = TripController(
        repository,
        journalRepository,
        MockTripCoverStorage(),
      );
      final draft = await TripCoverDraft.fromXFile(
        XFile.fromData(
          Uint8List.fromList(ascii.encode('GIF89a')),
          path: 'disguised.jpg',
          name: 'disguised.jpg',
          mimeType: 'image/jpeg',
        ),
      );

      final error = await validatingController.createTrip(
        _trip(id: 'invalid-cover'),
        coverDraft: draft,
      );

      expect(error, contains('damaged or does not match'));
      expect(repository.addedTrips, isEmpty);
    },
  );

  test('create database failure rolls back the newly uploaded cover', () async {
    repository.failAdd = true;
    final trip = _trip(id: 'new-trip', coverPhotoPath: r'C:\photos\cover.jpg');

    final error = await controller.createTrip(trip);

    expect(error, contains('add failed'));
    expect(storage.deletedUrls, [storage.uploadedUrl]);
    expect(repository.trips, isEmpty);
  });

  test(
    'create remains successful when only the post-write refresh fails',
    () async {
      repository.failNextGetTrips = true;
      final trip = _trip(
        id: 'new-trip',
        coverPhotoPath: r'C:\photos\cover.jpg',
      );

      final error = await controller.createTrip(trip);

      expect(error, isNull);
      expect(repository.addedTrips, hasLength(1));
      expect(storage.deletedUrls, isEmpty);
      expect(controller.trips.single.coverPhotoPath, storage.uploadedUrl);
      expect(controller.refreshWarning, contains('refresh failed'));

      controller.clearRefreshWarning();
      expect(controller.refreshWarning, isNull);
    },
  );

  test('http and https covers are persisted without another upload', () async {
    for (final remoteCover in [
      'http://images.example.test/cover.jpg',
      'https://images.example.test/cover.jpg',
    ]) {
      repository = _RecordingTripRepository(events);
      controller = TripController(repository, journalRepository, storage);
      await controller.loadTrips(kMockUserId);

      final error = await controller.createTrip(
        _trip(id: remoteCover, coverPhotoPath: remoteCover),
      );

      expect(error, isNull);
      expect(repository.addedTrips.single.coverPhotoPath, remoteCover);
    }
    expect(storage.uploads, isEmpty);
  });

  test('edit validates before uploading a replacement cover', () async {
    final original = _trip(id: 'existing', coverPhotoPath: _oldCoverUrl);
    repository.trips.add(original);
    await controller.loadTrips(kMockUserId);

    final error = await controller.editTrip(
      _trip(
        id: 'existing',
        title: '',
        coverPhotoPath: r'C:\photos\replacement.png',
      ),
    );

    expect(error, 'Please enter a trip title.');
    expect(storage.uploads, isEmpty);
    expect(repository.updatedTrips, isEmpty);
  });

  test(
    'edit success deletes the previous remote cover after persistence',
    () async {
      final original = _trip(id: 'existing', coverPhotoPath: _oldCoverUrl);
      repository.trips.add(original);
      await controller.loadTrips(kMockUserId);

      final error = await controller.editTrip(
        _trip(id: 'existing', coverPhotoPath: r'C:\photos\replacement.png'),
      );

      expect(error, isNull);
      expect(
        repository.updatedTrips.single.coverPhotoPath,
        storage.uploadedUrl,
      );
      expect(storage.deletedUrls, [_oldCoverUrl]);
      expect(events, [
        'upload',
        'persist:${storage.uploadedUrl}',
        'delete:$_oldCoverUrl',
      ]);
    },
  );

  test(
    'edit failure deletes only the new upload and retains the previous URL',
    () async {
      final original = _trip(id: 'existing', coverPhotoPath: _oldCoverUrl);
      repository.trips.add(original);
      repository.failUpdate = true;
      await controller.loadTrips(kMockUserId);

      final error = await controller.editTrip(
        _trip(id: 'existing', coverPhotoPath: r'C:\photos\replacement.png'),
      );

      expect(error, contains('update failed'));
      expect(storage.deletedUrls, [storage.uploadedUrl]);
      expect(repository.trips.single.coverPhotoPath, _oldCoverUrl);
    },
  );

  test(
    'edit failure does not delete an upload URL identical to the previous cover',
    () async {
      final original = _trip(id: 'existing', coverPhotoPath: _oldCoverUrl);
      repository.trips.add(original);
      repository.failUpdate = true;
      storage.uploadedUrl = _oldCoverUrl;
      await controller.loadTrips(kMockUserId);

      final error = await controller.editTrip(
        _trip(id: 'existing', coverPhotoPath: r'C:\photos\replacement.png'),
      );

      expect(error, contains('update failed'));
      expect(storage.deletedUrls, isEmpty);
      expect(repository.trips.single.coverPhotoPath, _oldCoverUrl);
    },
  );

  test(
    'edit remains successful when only the post-write refresh fails',
    () async {
      final original = _trip(id: 'existing', coverPhotoPath: _oldCoverUrl);
      repository.trips.add(original);
      await controller.loadTrips(kMockUserId);
      repository.failNextGetTrips = true;

      final error = await controller.editTrip(
        _trip(id: 'existing', coverPhotoPath: r'C:\photos\replacement.png'),
      );

      expect(error, isNull);
      expect(repository.updatedTrips, hasLength(1));
      expect(controller.trips.single.coverPhotoPath, storage.uploadedUrl);
      expect(storage.deletedUrls, [_oldCoverUrl]);
      expect(controller.refreshWarning, contains('refresh failed'));
    },
  );

  test(
    'removing a cover persists null before deleting the previous URL',
    () async {
      final original = _trip(id: 'existing', coverPhotoPath: _oldCoverUrl);
      repository.trips.add(original);
      await controller.loadTrips(kMockUserId);

      final error = await controller.editTrip(_trip(id: 'existing'));

      expect(error, isNull);
      expect(repository.updatedTrips.single.coverPhotoPath, isNull);
      expect(storage.uploads, isEmpty);
      expect(storage.deletedUrls, [_oldCoverUrl]);
      expect(events, ['persist:null', 'delete:$_oldCoverUrl']);
    },
  );

  test(
    'old-cover cleanup failure is non-blocking and its warning is clearable',
    () async {
      final original = _trip(id: 'existing', coverPhotoPath: _oldCoverUrl);
      repository.trips.add(original);
      storage.failDeletesFor.add(_oldCoverUrl);
      await controller.loadTrips(kMockUserId);

      final error = await controller.editTrip(
        _trip(id: 'existing', coverPhotoPath: r'C:\photos\replacement.png'),
      );

      expect(error, isNull);
      expect(repository.trips.single.coverPhotoPath, storage.uploadedUrl);
      expect(controller.cleanupWarning, contains('cleanup failed'));

      controller.clearCleanupWarning();

      expect(controller.cleanupWarning, isNull);
    },
  );

  test('moveToTrash never deletes journal entries', () async {
    final original = _trip(id: 'existing');
    repository.trips.add(original);
    await controller.loadTrips(kMockUserId);

    final error = await controller.moveToTrash(original.id);

    expect(error, isNull);
    expect(repository.movedToTrashIds, ['existing']);
    expect(journalRepository.deletedEntryIds, isEmpty);
  });

  test('moveToTrash remains successful when only the refresh fails', () async {
    final original = _trip(id: 'existing');
    repository.trips.add(original);
    await controller.loadTrips(kMockUserId);
    repository.failNextGetTrips = true;

    final error = await controller.moveToTrash(original.id);

    expect(error, isNull);
    expect(controller.trips, isEmpty);
    expect(controller.refreshWarning, contains('refresh failed'));
  });

  test(
    'moveToTrash reports a real mutation failure and retains local state',
    () async {
      final original = _trip(id: 'existing');
      repository.trips.add(original);
      await controller.loadTrips(kMockUserId);
      repository.failMove = true;

      final error = await controller.moveToTrash(original.id);

      expect(error, contains('move failed'));
      expect(controller.trips.single.id, original.id);
      expect(controller.refreshWarning, isNull);
    },
  );

  test('concurrent creates upload and persist only once', () async {
    storage.uploadGate = Completer<void>();
    final trip = _trip(id: 'new-trip', coverPhotoPath: r'C:\photos\cover.jpg');

    final first = controller.createTrip(trip);
    await Future<void>.delayed(Duration.zero);
    final second = controller.createTrip(trip);
    await Future<void>.delayed(Duration.zero);
    storage.uploadGate!.complete();
    final results = await Future.wait([first, second]);

    expect(storage.uploads, hasLength(1));
    expect(repository.addedTrips, hasLength(1));
    expect(results.where((result) => result == null), hasLength(1));
    expect(results.where((result) => result != null), hasLength(1));
  });

  test('concurrent edits cannot double-upload a replacement cover', () async {
    final original = _trip(id: 'existing', coverPhotoPath: _oldCoverUrl);
    repository.trips.add(original);
    await controller.loadTrips(kMockUserId);
    storage.uploadGate = Completer<void>();
    final replacement = _trip(
      id: 'existing',
      coverPhotoPath: r'C:\photos\replacement.png',
    );

    final first = controller.editTrip(replacement);
    await Future<void>.delayed(Duration.zero);
    final second = controller.editTrip(replacement);
    await Future<void>.delayed(Duration.zero);
    storage.uploadGate!.complete();
    final results = await Future.wait([first, second]);

    expect(storage.uploads, hasLength(1));
    expect(repository.updatedTrips, hasLength(1));
    expect(results.where((result) => result == null), hasLength(1));
    expect(results.where((result) => result != null), hasLength(1));
  });
}

const _oldCoverUrl =
    'https://project.supabase.co/storage/v1/object/public/trip-covers/'
    '$kMockUserId/existing/old.jpg';

Trip _trip({
  required String id,
  String title = 'Valid Trip',
  String? coverPhotoPath,
}) {
  return Trip(
    id: id,
    userId: kMockUserId,
    title: title,
    coverPhotoPath: coverPhotoPath,
    startDate: DateTime(2040, 1, 1),
    endDate: DateTime(2040, 1, 2),
    createdAt: DateTime.utc(2039, 12, 1),
    updatedAt: DateTime.utc(2039, 12, 1),
  );
}

final class _RecordingTripRepository implements TripRepository {
  _RecordingTripRepository(this.events);

  final List<Trip> trips = [];
  final List<Trip> addedTrips = [];
  final List<Trip> updatedTrips = [];
  final List<String> movedToTrashIds = [];
  final List<String> events;
  bool failAdd = false;
  bool failUpdate = false;
  bool failMove = false;
  bool failNextGetTrips = false;

  @override
  Future<List<Trip>> getTrips(String userId) async {
    if (failNextGetTrips) {
      failNextGetTrips = false;
      throw StateError('refresh failed');
    }
    return trips
        .where((trip) => trip.userId == userId && trip.deletedAt == null)
        .toList();
  }

  @override
  Future<List<Trip>> getDeletedTrips(String userId) async => const [];

  @override
  Future<Trip?> getTrip(String id) async {
    for (final trip in trips) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  @override
  Future<void> addTrip(Trip trip) async {
    addedTrips.add(trip);
    if (failAdd) throw StateError('add failed');
    trips.add(trip);
  }

  @override
  Future<void> updateTrip(Trip trip) async {
    updatedTrips.add(trip);
    if (failUpdate) throw StateError('update failed');
    events.add('persist:${trip.coverPhotoPath}');
    final index = trips.indexWhere((candidate) => candidate.id == trip.id);
    trips[index] = trip;
  }

  @override
  Future<void> moveToTrash(String id) async {
    movedToTrashIds.add(id);
    if (failMove) throw StateError('move failed');
    trips.removeWhere((trip) => trip.id == id);
  }

  @override
  Future<void> restoreTrip(Trip trip) async {}

  @override
  Future<List<Trip>> getPublicTrips() async => const [];
}

final class _UploadCall {
  const _UploadCall({
    required this.userId,
    required this.tripId,
    required this.localPath,
  });

  final String userId;
  final String tripId;
  final String localPath;

  @override
  bool operator ==(Object other) =>
      other is _UploadCall &&
      other.userId == userId &&
      other.tripId == tripId &&
      other.localPath == localPath;

  @override
  int get hashCode => Object.hash(userId, tripId, localPath);
}

final class _RecordingTripCoverStorage implements TripCoverStorage {
  _RecordingTripCoverStorage(this.events);

  String uploadedUrl =
      'https://project.supabase.co/storage/v1/object/public/trip-covers/'
      '$kMockUserId/new-trip/new.jpg';
  final List<_UploadCall> uploads = [];
  final List<String?> deletedUrls = [];
  final Set<String> failDeletesFor = {};
  final List<String> events;
  Completer<void>? uploadGate;

  @override
  Future<String> uploadCover({
    required String userId,
    required String tripId,
    required TripCoverDraft cover,
  }) async {
    uploads.add(
      _UploadCall(userId: userId, tripId: tripId, localPath: cover.path),
    );
    events.add('upload');
    await uploadGate?.future;
    return uploadedUrl;
  }

  @override
  Future<void> deleteCoverUrl(String? publicUrl) async {
    deletedUrls.add(publicUrl);
    events.add('delete:$publicUrl');
    if (failDeletesFor.contains(publicUrl)) {
      throw StateError('cleanup failed');
    }
  }
}

final class _RecordingJournalRepository implements JournalRepository {
  final List<String> deletedEntryIds = [];

  @override
  Future<List<JournalEntry>> getEntries(String tripId) async => [
    JournalEntry(
      id: 'journal-entry',
      tripId: tripId,
      title: 'Retained journal entry',
      body: 'This entry must survive moving its trip to trash.',
      mood: Mood.happy,
      photoPaths: const [],
      createdAt: DateTime.utc(2040, 1, 1),
      updatedAt: DateTime.utc(2040, 1, 1),
    ),
  ];

  @override
  Future<JournalEntry?> getEntry(String id) async => null;

  @override
  Future<void> addEntry(JournalEntry entry) async {}

  @override
  Future<void> updateEntry(JournalEntry entry) async {}

  @override
  Future<void> deleteEntry(String id) async {
    deletedEntryIds.add(id);
  }
}
