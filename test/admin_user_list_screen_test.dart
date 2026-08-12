import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripjournal/features/admin/screens/admin_user_detail_screen.dart';
import 'package:tripjournal/features/admin/screens/admin_user_list_screen.dart';
import 'package:tripjournal/models/profile.dart';

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

    testWidgets('an initial status filter narrows results and shows a '
        'filter chip', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdminUserListScreen(
              title: 'Suspended Users',
              initialStatusFilter: AccountStatus.suspended,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Suspended Users'), findsWidgets); // AppBar + chip
      expect(find.byKey(const Key('admin-user-filter-chip')), findsOneWidget);
      expect(find.text('Chong Mei Ling'), findsOneWidget);
      expect(find.text('Alice Tan'), findsNothing);
    });

    testWidgets('an initial role filter narrows to admins only',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdminUserListScreen(
              title: 'Administrators',
              initialRoleFilter: UserRole.admin,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Admin Account'), findsOneWidget);
      expect(find.text('Alice Tan'), findsNothing);
    });

    testWidgets('with no initial filter, no filter chip is shown',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminUserListScreen())),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-user-filter-chip')), findsNothing);
    });

    testWidgets('deleting the filter chip clears the filter and shows '
        'everyone', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdminUserListScreen(
              title: 'Suspended Users',
              initialStatusFilter: AccountStatus.suspended,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Alice Tan'), findsNothing);

      await tester.tap(find.descendant(
        of: find.byKey(const Key('admin-user-filter-chip')),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-user-filter-chip')), findsNothing);
      expect(find.text('Alice Tan'), findsOneWidget);
    });

    testWidgets('a filter matching nobody shows a filter-specific empty '
        'state', (tester) async {
      // No profile in the default seed is both suspended AND an admin.
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdminUserListScreen(
              title: 'Impossible Filter',
              initialStatusFilter: AccountStatus.suspended,
              initialRoleFilter: UserRole.admin,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('No users match this filter.'), findsOneWidget);
    });
  });
}
