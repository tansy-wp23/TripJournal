import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creation-order migration backfills and protects the timestamp', () {
    final sql = File(
      'supabase/migrations/202608290001_journal_entry_creation_order.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('add column creation_order_at timestamptz'));
    expect(sql, contains('set creation_order_at = updated_at'));
    expect(sql, contains('alter column creation_order_at set not null'));
    expect(sql, contains('alter column creation_order_at set default now()'));
    expect(sql, contains('new.creation_order_at := old.creation_order_at'));
    expect(sql, contains('before update on public.journal_entries'));
  });
}
