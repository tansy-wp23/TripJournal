import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/auth/widgets/otp_code_input.dart';

void main() {
  group('OtpCodeInput', () {
    testWidgets('auto-advances focus when a digit is entered', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OtpCodeInput()),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('otp-digit-0')),
        '1',
      );
      await tester.pump();

      // Focus should have advanced to box 1.
      final focusNode = tester.widget<TextField>(
        find.byKey(const Key('otp-digit-1')),
      ).focusNode;
      expect(focusNode?.hasFocus, isTrue);
    });

    testWidgets('backspace on an empty box clears the previous digit and '
        'moves focus back', (tester) async {
      String? lastCode;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpCodeInput(onChanged: (code) => lastCode = code),
          ),
        ),
      );

      // Enter digits 1-4 in boxes 0-3, leaving box 4 empty.
      for (var i = 0; i < 4; i++) {
        await tester.enterText(
          find.byKey(Key('otp-digit-$i')),
          '${i + 1}',
        );
        await tester.pump();
      }

      // Move focus to the empty box 4.
      final box4Focus = tester.widget<TextField>(
        find.byKey(const Key('otp-digit-4')),
      ).focusNode;
      box4Focus?.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      // Box 3 should be cleared.
      final box3Controller = tester.widget<TextField>(
        find.byKey(const Key('otp-digit-3')),
      ).controller;
      expect(box3Controller?.text, isEmpty);
      expect(lastCode, '123');

      // Focus should be back on box 3.
      final box3Focus = tester.widget<TextField>(
        find.byKey(const Key('otp-digit-3')),
      ).focusNode;
      expect(box3Focus?.hasFocus, isTrue);
    });

    testWidgets('calls onCompleted when all digits are entered',
        (tester) async {
      String? completed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpCodeInput(onCompleted: (code) => completed = code),
          ),
        ),
      );

      for (var i = 0; i < 6; i++) {
        await tester.enterText(
          find.byKey(Key('otp-digit-$i')),
          '${i + 1}',
        );
        await tester.pump();
      }

      expect(completed, '123456');
    });

    testWidgets('backspace on a box with digits clears only that digit',
        (tester) async {
      String? lastCode;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpCodeInput(onChanged: (code) => lastCode = code),
          ),
        ),
      );

      // Enter digits 1-4 in boxes 0-3.
      for (var i = 0; i < 4; i++) {
        await tester.enterText(
          find.byKey(Key('otp-digit-$i')),
          '${i + 1}',
        );
        await tester.pump();
      }

      // Press backspace on the last filled box (box 3, has '4').
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      // Box 3 should be cleared (the text field's own backspace).
      final box3Controller = tester.widget<TextField>(
        find.byKey(const Key('otp-digit-3')),
      ).controller;
      expect(box3Controller?.text, isEmpty);
      expect(lastCode, '123');
    });
  });
}