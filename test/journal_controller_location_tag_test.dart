import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_journal_repository.dart';
import 'package:tripjournal/features/journal/ai/daily_advice_service.dart';
import 'package:tripjournal/features/journal/controller/journal_controller.dart';
import 'package:tripjournal/features/journal/location/location_tag_service.dart';
import 'package:tripjournal/models/geo_tag.dart';
import 'package:tripjournal/models/journal_entry.dart';
import 'package:tripjournal/models/mood.dart';

void main() {
  late RecordingLocationTagService locationTagService;
  late JournalController controller;

  setUp(() {
    locationTagService = RecordingLocationTagService();
    controller = JournalController(
      MockJournalRepository(),
      MockDailyAdviceService(),
      locationTagService: locationTagService,
    );
  });

  JournalEntry entry({GeoTag? location}) {
    final now = DateTime.now();
    return JournalEntry(
      id: 'location-tag-entry',
      tripId: 'trip-001',
      title: 'Kyoto walk',
      body: 'A walk through the city.',
      mood: Mood.happy,
      photoPaths: const [],
      location: location,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('enriches and persists a GPS location tag on create', () async {
    final error = await controller.create(
      entry(location: const GeoTag(latitude: 35.0116, longitude: 135.7681)),
    );

    expect(error, isNull);
    expect(locationTagService.calls, 1);
    expect(controller.entries.single.location?.latitude, 35.0116);
    expect(controller.entries.single.location?.longitude, 135.7681);
    expect(controller.entries.single.location?.placeName, 'Kyoto');
    expect(controller.entries.single.location?.locationTag, '#Kyoto');
  });

  test('does not call the geocoder when GPS location is absent', () async {
    final error = await controller.create(entry());

    expect(error, isNull);
    expect(locationTagService.calls, 0);
    expect(controller.entries.single.location, isNull);
  });
}

class RecordingLocationTagService implements LocationTagService {
  int calls = 0;

  @override
  Future<GeoTag> enrich(GeoTag location) async {
    calls++;
    return location.copyWith(placeName: 'Kyoto', locationTag: '#Kyoto');
  }
}
