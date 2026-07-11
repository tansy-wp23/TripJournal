import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/validation/photo_validation.dart';

void main() {
  group('validatePhotoCount', () {
    test('adding a 6th photo (currentCount == 5) is blocked', () {
      expect(validatePhotoCount(5), 'You can add up to 5 photos per entry.');
    });

    test('adding up to the 5th photo (currentCount < 5) is allowed', () {
      expect(validatePhotoCount(0), isNull);
      expect(validatePhotoCount(4), isNull);
    });
  });

  group('remainingPhotoAllowance', () {
    test('a fresh entry (0 photos) allows all 5', () {
      expect(remainingPhotoAllowance(0), 5);
    });

    test('scales down as photos are added', () {
      expect(remainingPhotoAllowance(2), 3);
      expect(remainingPhotoAllowance(4), 1);
    });

    test('is 0 at the cap, never negative even past it', () {
      expect(remainingPhotoAllowance(5), 0);
      expect(remainingPhotoAllowance(6), 0);
    });
  });

  group('validatePhotoSize', () {
    const mb = 1024 * 1024;

    test('a 33 MB file is rejected', () {
      expect(validatePhotoSize(33 * mb), 'This image is too large (max 32 MB).');
    });

    test('exactly 32 MB is accepted (the boundary is inclusive)', () {
      expect(validatePhotoSize(32 * mb), isNull);
    });

    test('a normal-sized file is accepted', () {
      expect(validatePhotoSize(2 * mb), isNull);
    });
  });
}
