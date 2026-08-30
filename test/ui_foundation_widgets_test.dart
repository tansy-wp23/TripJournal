import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripjournal/theme/app_theme.dart';
import 'package:tripjournal/widgets/app_section_header.dart';
import 'package:tripjournal/widgets/aurora_panel.dart';

void main() {
  testWidgets('AuroraPanel exposes semantics and renders in both themes', (
    tester,
  ) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: AuroraPanel(
              semanticLabel: 'Active trip',
              child: Text('Kuala Lumpur'),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Active trip'), findsOneWidget);
      expect(find.text('Kuala Lumpur'), findsOneWidget);
    }
  });

  testWidgets('AuroraPanel provides an optional full-surface action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AuroraPanel(
            semanticLabel: 'Open active trip',
            onTap: () => taps++,
            child: const Text('Kuala Lumpur'),
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Open active trip'));

    expect(taps, 1);
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('AppSectionHeader omits an action unless it is actionable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: AppSectionHeader(title: 'Your trips')),
      ),
    );

    expect(find.text('Your trips'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('AppSectionHeader exposes and invokes its optional action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppSectionHeader(
            title: 'Your trips',
            actionLabel: 'See all',
            onAction: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'See all'));

    expect(taps, 1);
  });
}
