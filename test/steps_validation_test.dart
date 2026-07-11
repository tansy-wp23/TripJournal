import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/validation/steps_validation.dart';

void main() {
  test('a negative step count is rejected', () {
    expect(validateSteps(-1), 'Please enter a valid number.');
  });

  test('exactly the soft cap (100,000) is accepted', () {
    expect(validateSteps(100000), isNull);
  });

  test('one over the soft cap (100,001) is rejected', () {
    expect(validateSteps(100001), 'That step count seems unusually high — please check.');
  });

  test('a normal value is accepted', () {
    expect(validateSteps(8200), isNull);
  });

  test('0 is accepted', () {
    expect(validateSteps(0), isNull);
  });
}
