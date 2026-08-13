import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/trip_cover_storage.dart';
import 'package:tripjournal/features/trip/widgets/trip_cover_photo.dart';

Future<Container> _buildDirectly(
  WidgetTester tester,
  TripCoverPhoto coverPhoto,
) async {
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
  return coverPhoto.build(context) as Container;
}

void main() {
  testWidgets('shows the placeholder icon when photoPath is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TripCoverPhoto(height: 100)),
    );
    expect(find.byIcon(Icons.photo), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'shows the placeholder icon for a local path whose file is missing',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TripCoverPhoto(
            // A device-style path, not an `assets/` one — seeded asset paths
            // now resolve to real bundled photos.
            photoPath: '/no/such/directory/kyoto_arrival_1.jpg',
            height: 100,
          ),
        ),
      );
      expect(find.byIcon(Icons.photo), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets('renders an http cover with a network image using cover fit', (
    tester,
  ) async {
    final container = await _buildDirectly(
      tester,
      const TripCoverPhoto(
        photoPath: 'http://images.example.com/trip-cover.jpg',
        width: 160,
        height: 90,
      ),
    );

    final image = container.child! as Image;
    expect(image.image, isA<NetworkImage>());
    expect(image.fit, BoxFit.cover);
    expect(image.width, 160);
    expect(image.height, 90);
  });

  testWidgets('renders an https cover with a network image', (tester) async {
    final container = await _buildDirectly(
      tester,
      const TripCoverPhoto(
        photoPath: 'https://images.example.com/trip-cover.webp',
        height: 100,
      ),
    );

    expect((container.child! as Image).image, isA<NetworkImage>());
  });

  testWidgets('renders an existing local file using cover fit', (tester) async {
    final directory = Directory.systemTemp.createTempSync(
      'trip-cover-photo-test-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/cover.png');
    file.writeAsBytesSync([1]);

    final container = await _buildDirectly(
      tester,
      TripCoverPhoto(photoPath: file.path, width: 160, height: 90),
    );

    final image = container.child! as Image;
    expect(image.image, isA<FileImage>());
    expect(image.fit, BoxFit.cover);
    expect(image.width, 160);
    expect(image.height, 90);
  });

  testWidgets('renders browser-backed XFile bytes with a memory image', (
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

    final container = await _buildDirectly(
      tester,
      TripCoverPhoto(coverDraft: draft, width: 160, height: 90),
    );

    final image = container.child! as Image;
    expect(image.image, isA<MemoryImage>());
    expect((image.image as MemoryImage).bytes, bytes);
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('image errors use the placeholder fallback', (tester) async {
    final container = await _buildDirectly(
      tester,
      const TripCoverPhoto(
        photoPath: 'https://images.example.com/broken.jpg',
        height: 100,
      ),
    );

    final image = container.child! as Image;
    expect(image.errorBuilder, isNotNull);
    final context = tester.element(find.byType(SizedBox));
    final fallback = image.errorBuilder!(
      context,
      Exception('decode failed'),
      null,
    );
    await tester.pumpWidget(MaterialApp(home: fallback));

    expect(find.byIcon(Icons.photo), findsOneWidget);
  });
}
