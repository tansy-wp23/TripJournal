-- Older deployed databases predate the canonical schema's summary column.
-- Nullable keeps every existing trip compatible and requires no backfill.
alter table public.trips
  add column if not exists summary text;

-- Trip summaries are user-editable content. RLS continues to restrict updates
-- to the row owner; the column grant prevents lifecycle fields from becoming
-- directly editable by authenticated clients.
revoke update on table public.trips from authenticated;
grant update (
  title,
  destination,
  cover_photo_url,
  start_date,
  end_date,
  notes,
  summary
) on table public.trips to authenticated;
