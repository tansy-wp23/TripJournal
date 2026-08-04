import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_trip_cover_storage.dart';
import 'package:tripjournal/data/trip_cover_storage.dart';
import 'package:tripjournal/data/trip_cover_upload.dart';
import 'package:tripjournal/data/trip_cover_upload_preparer_web.dart'
    as web_preparer;
import 'package:tripjournal/features/trip/widgets/trip_cover_photo.dart';

void main() {
  testWidgets('browser XFile bytes preview without persisting its blob URL', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final draft = await TripCoverDraft.fromXFile(
      XFile.fromData(
        bytes,
        path: 'browser-cover.png',
        name: 'browser-cover.png',
        mimeType: 'image/png',
      ),
    );
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox();
          },
        ),
      ),
    );

    final preview =
        TripCoverPhoto(coverDraft: draft, width: 160, height: 90).build(context)
            as Container;
    final image = preview.child! as Image;
    final storedReference = await MockTripCoverStorage().uploadCover(
      userId: 'user-id',
      tripId: 'trip-id',
      cover: draft,
    );

    expect(image.image, isA<MemoryImage>());
    expect((image.image as MemoryImage).bytes, bytes);
    expect(draft.path, startsWith('blob:'));
    expect(storedReference, startsWith('mock-cover://'));
    expect(storedReference, isNot(contains('blob:')));
  }, skip: !kIsWeb);

  test('web rejects unsupported bytes instead of renaming them JPEG', () async {
    final draft = await TripCoverDraft.fromXFile(
      XFile.fromData(
        Uint8List.fromList(ascii.encode('GIF89a')),
        path: 'cover.gif',
        name: 'cover.gif',
        mimeType: 'image/gif',
      ),
    );

    await expectLater(
      web_preparer.prepareTripCoverUpload(draft),
      throwsA(isA<UnsupportedTripCoverFormatException>()),
    );
  });
}
