alter table public.trips add column if not exists destination text;

revoke update on table public.trips from authenticated;
grant update (title, destination, cover_photo_url, start_date, end_date, notes)
  on table public.trips to authenticated;

drop function if exists public.restore_trip(uuid, text, text, date, date, text);

create or replace function public.restore_trip(
  p_trip_id uuid,
  p_title text,
  p_destination text,
  p_cover_photo_url text,
  p_start_date date,
  p_end_date date,
  p_notes text
)
returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_deleted_at timestamptz;
begin
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));
  select trip.deleted_at into v_deleted_at
  from public.trips as trip
  where trip.id = p_trip_id
    and trip.user_id = auth.uid()
    and trip.deleted_at is not null
  for update;
  if not found then
    raise exception 'trip_not_found' using errcode = 'P0001';
  end if;
  if public.trip_is_purge_claimed(p_trip_id) then
    raise exception 'trip_purge_in_progress' using errcode = 'P0001';
  end if;
  if v_deleted_at + interval '30 days' <= now() then
    raise exception 'trip_restore_expired' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.trips as other
    where other.user_id = auth.uid()
      and other.id <> p_trip_id
      and other.deleted_at is null
      and other.start_date <= p_end_date
      and other.end_date >= p_start_date
  ) then
    raise exception 'trip_restore_overlap' using errcode = 'P0001';
  end if;
  update public.trips
  set title = p_title,
      destination = p_destination,
      cover_photo_url = p_cover_photo_url,
      start_date = p_start_date,
      end_date = p_end_date,
      notes = p_notes,
      updated_at = now(),
      deleted_at = null
  where id = p_trip_id;
end;
$$;

revoke execute on function public.restore_trip(
  uuid, text, text, text, date, date, text
) from public, anon, service_role;
grant execute on function public.restore_trip(
  uuid, text, text, text, date, date, text
) to authenticated;
