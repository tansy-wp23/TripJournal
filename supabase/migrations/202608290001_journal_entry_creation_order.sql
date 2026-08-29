alter table public.journal_entries
  add column creation_order_at timestamptz;

-- `updated_at` is only a one-time best-effort legacy backfill: older rows
-- have no historical insertion-order value to recover.
update public.journal_entries
set creation_order_at = updated_at
where creation_order_at is null;

alter table public.journal_entries
  alter column creation_order_at set default now(),
  alter column creation_order_at set not null;

create index journal_entries_trip_day_creation_order_idx
  on public.journal_entries (trip_id, entry_date, creation_order_at, id);

create or replace function public.preserve_journal_entry_creation_order()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- All later updates preserve the frozen value assigned at creation time.
  new.creation_order_at := old.creation_order_at;
  return new;
end;
$$;

create trigger journal_entries_preserve_creation_order
before update on public.journal_entries
for each row execute function public.preserve_journal_entry_creation_order();
