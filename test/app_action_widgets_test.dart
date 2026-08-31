import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/widgets/app_action_menu.dart';
import 'package:tripjournal/widgets/app_content_toolbar.dart';
import 'package:tripjournal/widgets/app_navigation_tile.dart';
import 'package:tripjournal/widgets/app_page_header.dart';

void main() {
  testWidgets(
    'AppActionMenu labels routine actions and separates destructive actions',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                AppActionMenu<String>(
                  tooltip: 'More actions',
                  onSelected: (value) => selected = value,
                  items: const [
                    AppActionMenuItem(
                      value: 'edit',
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                    ),
                    AppActionMenuItem(
                      key: Key('delete-action'),
                      value: 'delete',
                      label: 'Move to Trash',
                      icon: Icons.delete_outline,
                      destructive: true,
                      startsSection: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byTooltip('More actions')),
        const Size(48, 48),
      );
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Move to Trash'), findsOneWidget);
      expect(find.byType(PopupMenuDivider), findsOneWidget);

      final destructiveText = tester.widget<Text>(find.text('Move to Trash'));
      final context = tester.element(find.text('Move to Trash'));
      expect(destructiveText.style?.color, Theme.of(context).colorScheme.error);

      await tester.tap(find.byKey(const Key('delete-action')));
      await tester.pumpAndSettle();
      expect(selected, 'delete');
    },
  );

  testWidgets('AppContentToolbar exposes result and active-filter context', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppContentToolbar(
            resultLabel: '5 entries',
            activeFilterLabel: '2 filters active',
            children: [Text('Search'), Text('Filter')],
          ),
        ),
      ),
    );

    expect(find.text('5 entries'), findsOneWidget);
    expect(find.text('2 filters active'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(
      tester.getSize(find.byType(AppContentToolbar)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('AppPageHeader wraps a long title without clipping its action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPageHeader(
            eyebrow: 'ADMIN',
            title: 'A deliberately long monitoring dashboard title',
            subtitle: 'Supporting context remains readable.',
            action: FilledButton(
              onPressed: () {},
              child: const Text('Export report'),
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('A deliberately long monitoring dashboard title'),
      findsOneWidget,
    );
    expect(find.text('Export report'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppNavigationTile provides a labelled 48dp navigation target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppNavigationTile(
            icon: Icons.people_outline,
            title: 'Manage users',
            subtitle: 'Review profiles and access state',
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('Manage users'), findsOneWidget);
    expect(find.text('Review profiles and access state'), findsOneWidget);
    expect(
      tester.getSize(find.byType(AppNavigationTile)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(AppNavigationTile));
    expect(taps, 1);
  });
}
