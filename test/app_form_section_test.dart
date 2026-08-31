import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripjournal/widgets/app_form_section.dart';

void main() {
  testWidgets('exposes its title as a heading and keeps supporting content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFormSection(
            title: 'Trip details',
            icon: Icons.luggage_outlined,
            helperText: 'Name the journey and where you are going.',
            action: TextButton(onPressed: () {}, child: const Text('Choose')),
            child: const Text('Form fields'),
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.text('Trip details'));
    expect(semantics.flagsCollection.isHeader, isTrue);
    expect(
      find.text('Name the journey and where you are going.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Choose'), findsOneWidget);
    expect(find.text('Form fields'), findsOneWidget);
  });

  testWidgets('lays out without overflow on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AppFormSection(
              title: 'A deliberately long section heading',
              icon: Icons.auto_awesome_outlined,
              helperText: 'Helpful context that may wrap over several lines.',
              action: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('A longer action'),
              ),
              child: const TextField(),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
