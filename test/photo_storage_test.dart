import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/data/mock_photo_storage.dart';
import 'package:tripjournal/data/photo_storage.dart';

void main() {
  late PhotoStorage storage;

  setUp(() => storage = MockPhotoStorage());

  // Under `flutter test` there is no plugin behind path_provider's method
  // channel, so every case below exercises the fallback. That is deliberate:
  // this is the path every widget test that adds a photo will take, so it has
  // to be quiet and lossless rather than a failure.
  group('MockPhotoStorage without a filesystem to copy into', () {
    test('echoes the picker path so the photo is never lost', () async {
      final saved = await storage.savePhoto(XFile('/tmp/pick/meal.jpg'));
      expect(saved, '/tmp/pick/meal.jpg');
    });

    // The trailing segment comes from XFile.name, which each platform derives
    // differently (the dart:io implementation splits on the OS path
    // separator), so these assert the scheme rather than the exact filename.
    test('synthesizes a stable URI for web blob and data paths', () async {
      final blob = await storage.savePhoto(XFile('blob:http://localhost/abc', name: 'shot.jpg'));
      final data = await storage.savePhoto(XFile('data:image/jpeg;base64,AAAA', name: 'shot.jpg'));

      expect(blob, startsWith('mock-photo://local/'));
      expect(data, startsWith('mock-photo://local/'));
    });

    test('synthesizes a URI for an empty path rather than returning nothing', () async {
      // An empty name collapses the trailing segment, so this asserts only
      // that a non-empty synthetic URI comes back rather than the raw path.
      final saved = await storage.savePhoto(XFile('', name: 'shot.jpg'));
      expect(saved, startsWith('mock-photo://local'));
    });
  });

  group('savePhoto never throws', () {
    // A throw here would abort a whole multi-select batch, because
    // _addFromGallery's loop sits inside one try/catch.
    test('for a file that does not exist', () async {
      expect(
        await storage.savePhoto(XFile('/definitely/not/here/ghost.jpg')),
        '/definitely/not/here/ghost.jpg',
      );
    });

    test('for a path with no extension', () async {
      expect(await storage.savePhoto(XFile('/tmp/pick/noext')), '/tmp/pick/noext');
    });
  });

  group('deletePhoto', () {
    test('is a no-op for null', () async {
      await expectLater(storage.deletePhoto(null), completes);
    });

    test('is a no-op for an empty path', () async {
      await expectLater(storage.deletePhoto(''), completes);
    });

    test('ignores a path this storage never owned', () async {
      // Entry photos saved before this feature existed still hold raw picker
      // paths — removing one must never delete the user's gallery original.
      await expectLater(storage.deletePhoto('/storage/emulated/0/DCIM/holiday.jpg'), completes);
    });
  });
}
