import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/screens/admin_user_detail_screen.dart';
import 'package:tripjournal/features/admin/screens/admin_user_list_screen.dart';

void main() {
  group('AdminUserListScreen', () {
    testWidgets('loads and shows every seeded user on open', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminUserListScreen())),
      );
      await tester.pump(); // triggers the post-frame loadAll callback
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-user-search-results')), findsOneWidget);
      expect(find.text('Alice Tan'), findsOneWidget);
      expect(find.text('Admin Account'), findsOneWidget);
    });

    testWidgets('typing a query narrows results to matching users after '
        'the debounce', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminUserListScreen())),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('admin-user-search-field')), 'alice');
      await tester.pump(const Duration(milliseconds: 350)); // past the debounce
      await tester.pumpAndSettle();

      expect(find.text('Alice Tan'), findsOneWidget);
      expect(find.text('Brandon Lee'), findsNothing);
    });

    testWidgets('a query matching nobody shows the empty state, not a '
        'blank list', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminUserListScreen())),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('admin-user-search-field')),
        'nonexistent-name-xyz',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-user-search-empty-state')), findsOneWidget);
      expect(find.byKey(const Key('admin-user-search-results')), findsNothing);
    });

    testWidgets('tapping a user navigates to AdminUserDetailScreen',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminUserListScreen())),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice Tan'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminUserDetailScreen), findsOneWidget);
    });
  });
}
