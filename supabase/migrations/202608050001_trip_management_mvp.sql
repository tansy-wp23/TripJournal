alter table public.trips
  add column if not exists deleted_at timestamptz;

create index if not exists trips_user_deleted_at_idx
  on public.trips (user_id, deleted_at);

drop policy if exists "trips_delete_own" on public.trips;

-- SECURITY INVOKER functions need the caller's underlying table privileges;
-- RLS still limits both operations to rows owned by auth.uid().
grant select, update on table public.trips to authenticated;

create or replace function public.move_trip_to_trash(p_trip_id uuid)
returns void
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  update public.trips
  set
    deleted_at = now(),
    updated_at = now()
  where id = p_trip_id
    and user_id = auth.uid()
    and deleted_at is null;

  if not found then
    raise exception 'trip_not_found' using errcode = 'P0001';
  end if;
end;
$$;

create or replace function public.restore_trip(
  p_trip_id uuid,
  p_title text,
  p_cover_photo_url text,
  p_start_date date,
  p_end_date date,
  p_notes text
)
returns void
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_deleted_at timestamptz;
begin
  -- Serialize restores per user so concurrent requests cannot both pass the
  -- active-trip overlap check before either update commits.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));

  select deleted_at
  into v_deleted_at
  from public.trips
  where id = p_trip_id
    and user_id = auth.uid()
    and deleted_at is not null
  for update;

  if not found then
    raise exception 'trip_not_found' using errcode = 'P0001';
  end if;

  if v_deleted_at + interval '30 days' <= now() then
    raise exception 'trip_restore_expired' using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.trips
    where user_id = auth.uid()
      and id <> p_trip_id
      and deleted_at is null
      and start_date <= p_end_date
      and end_date >= p_start_date
  ) then
    raise exception 'trip_restore_overlap' using errcode = 'P0001';
  end if;

  update public.trips
  set
    title = p_title,
    cover_photo_url = p_cover_photo_url,
    start_date = p_start_date,
    end_date = p_end_date,
    notes = p_notes,
    updated_at = now(),
    deleted_at = null
  where id = p_trip_id
    and user_id = auth.uid()
    and deleted_at is not null;
end;
$$;

revoke execute on function public.move_trip_to_trash(uuid) from public, anon;
revoke execute on function public.restore_trip(uuid, text, text, date, date, text) from public, anon;
grant execute on function public.move_trip_to_trash(uuid) to authenticated;
grant execute on function public.restore_trip(uuid, text, text, date, date, text) to authenticated;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'trip-covers',
  'trip-covers',
  true,
  33554432,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "trip_covers_insert_own" on storage.objects;
create policy "trip_covers_insert_own" on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'trip-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "trip_covers_select_own" on storage.objects;
create policy "trip_covers_select_own" on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'trip-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "trip_covers_update_own" on storage.objects;
create policy "trip_covers_update_own" on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'trip-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'trip-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "trip_covers_delete_own" on storage.objects;
create policy "trip_covers_delete_own" on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'trip-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
