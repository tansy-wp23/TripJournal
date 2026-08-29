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
    expect(
      sql,
      contains('create index journal_entries_trip_day_creation_order_idx'),
    );
    expect(sql, contains('new.creation_order_at := old.creation_order_at'));
    expect(
      sql,
      contains('create trigger journal_entries_preserve_creation_order'),
    );
    expect(sql, contains('before update on public.journal_entries'));
  });

  test('baseline schema preserves immutable creation order', () {
    final sql = File('tripjournal_schema.sql').readAsStringSync().toLowerCase();

    expect(
      sql,
      contains('creation_order_at timestamptz not null default now()'),
    );
    expect(
      sql,
      contains('create index journal_entries_trip_day_creation_order_idx'),
    );
    expect(
      sql,
      contains(
        'create or replace function '
        'public.preserve_journal_entry_creation_order()',
      ),
    );
    expect(sql, contains('new.creation_order_at := old.creation_order_at'));
    expect(
      sql,
      contains('create trigger journal_entries_preserve_creation_order'),
    );
    expect(sql, contains('before update on public.journal_entries'));
    expect(
      sql,
      contains(
        'execute function public.preserve_journal_entry_creation_order()',
      ),
    );
  });
}
