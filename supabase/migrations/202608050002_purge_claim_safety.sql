-- Durable purge claims close the gap between external Storage deletion and
-- the final database cascade. A failed worker keeps the same immutable
-- snapshot; a stale lease rotates only the worker token.
create table if not exists public.trip_purge_claims (
  trip_id uuid primary key references public.trips(id) on delete cascade,
  claim_token uuid not null unique,
  owner_id uuid not null references auth.users(id) on delete cascade,
  cutoff_at timestamptz not null,
  cover_photo_url text,
  journal_photo_urls text[] not null default '{}',
  created_at timestamptz not null default now(),
  lease_expires_at timestamptz not null
);

create index if not exists trip_purge_claims_lease_idx
  on public.trip_purge_claims (lease_expires_at, trip_id);

alter table public.trip_purge_claims enable row level security;
revoke all on table public.trip_purge_claims
  from public, anon, authenticated, service_role;

create or replace function public.trip_is_purge_claimed(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.trip_purge_claims as claim
    where claim.trip_id = p_trip_id
  )
$$;

revoke execute on function public.trip_is_purge_claimed(uuid)
  from public, anon, service_role;
grant execute on function public.trip_is_purge_claimed(uuid)
  to authenticated;

create or replace function public.guard_claimed_trip_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_claim_token uuid;
begin
  select claim.claim_token
  into v_claim_token
  from public.trip_purge_claims as claim
  where claim.trip_id = old.id;

  if v_claim_token is null then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if tg_op = 'DELETE'
    and current_setting('tripjournal.purge_claim_token', true)
      = v_claim_token::text
  then
    return old;
  end if;

  raise exception 'trip_purge_in_progress' using errcode = 'P0001';
end;
$$;

revoke execute on function public.guard_claimed_trip_mutation()
  from public, anon, authenticated, service_role;

drop trigger if exists trips_guard_purge_claim on public.trips;
create trigger trips_guard_purge_claim
  before update or delete on public.trips
  for each row execute function public.guard_claimed_trip_mutation();

create or replace function public.guard_claimed_journal_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_old_trip_id uuid;
  v_new_trip_id uuid;
begin
  v_old_trip_id := case when tg_op in ('UPDATE', 'DELETE') then old.trip_id end;
  v_new_trip_id := case when tg_op in ('INSERT', 'UPDATE') then new.trip_id end;

  -- The final token-guarded trip DELETE cascades to journal rows. Permit only
  -- that exact claim token; ordinary journal deletes remain blocked.
  if tg_op = 'DELETE' and exists (
    select 1
    from public.trip_purge_claims as claim
    where claim.trip_id = v_old_trip_id
      and current_setting('tripjournal.purge_claim_token', true)
        = claim.claim_token::text
  ) then
    return old;
  end if;

  -- Every journal membership mutation locks its parent trip. The claim RPC
  -- uses FOR UPDATE SKIP LOCKED, so either this mutation commits first or the
  -- claim wins and this trigger observes the durable claim after waiting.
  perform 1
  from public.trips as trip
  where trip.id in (v_old_trip_id, v_new_trip_id)
  order by trip.id
  for update;

  if (v_old_trip_id is not null and
      public.trip_is_purge_claimed(v_old_trip_id))
    or (v_new_trip_id is not null and
        public.trip_is_purge_claimed(v_new_trip_id))
  then
    raise exception 'trip_purge_in_progress' using errcode = 'P0001';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke execute on function public.guard_claimed_journal_mutation()
  from public, anon, authenticated, service_role;

drop trigger if exists journal_entries_guard_purge_claim
  on public.journal_entries;
create trigger journal_entries_guard_purge_claim
  before insert or update or delete on public.journal_entries
  for each row execute function public.guard_claimed_journal_mutation();

-- Authenticated clients may edit only user-facing columns. Lifecycle fields
-- are owned by the RPCs, preventing a client from backdating deleted_at to
-- manufacture an immediately purgeable row.
revoke update on table public.trips from authenticated;
grant select on table public.trips to authenticated;
grant update (
  title,
  cover_photo_url,
  start_date,
  end_date,
  notes
) on table public.trips to authenticated;

drop policy if exists "trips_insert_own" on public.trips;
create policy "trips_insert_own" on public.trips
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and deleted_at is null
  );

drop policy if exists "trips_update_own" on public.trips;
create policy "trips_update_own" on public.trips
  for update
  to authenticated
  using (
    auth.uid() = user_id
    and not public.trip_is_purge_claimed(id)
  )
  with check (
    auth.uid() = user_id
    and not public.trip_is_purge_claimed(id)
  );

drop policy if exists "entries_insert_own" on public.journal_entries;
create policy "entries_insert_own" on public.journal_entries
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and not public.trip_is_purge_claimed(trip_id)
  );

drop policy if exists "entries_update_own" on public.journal_entries;
create policy "entries_update_own" on public.journal_entries
  for update
  to authenticated
  using (
    auth.uid() = user_id
    and not public.trip_is_purge_claimed(trip_id)
  )
  with check (
    auth.uid() = user_id
    and not public.trip_is_purge_claimed(trip_id)
  );

drop policy if exists "entries_delete_own" on public.journal_entries;
create policy "entries_delete_own" on public.journal_entries
  for delete
  to authenticated
  using (
    auth.uid() = user_id
    and not public.trip_is_purge_claimed(trip_id)
  );

-- Lifecycle RPCs own deleted_at and run with their creator's table rights.
-- Every row lookup still binds auth.uid() before any mutation.
create or replace function public.move_trip_to_trash(p_trip_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_deleted_at timestamptz;
begin
  select trip.deleted_at
  into v_deleted_at
  from public.trips as trip
  where trip.id = p_trip_id
    and trip.user_id = auth.uid()
  for update;

  if not found then
    raise exception 'trip_not_found' using errcode = 'P0001';
  end if;
  if public.trip_is_purge_claimed(p_trip_id) then
    raise exception 'trip_purge_in_progress' using errcode = 'P0001';
  end if;
  if v_deleted_at is not null then
    raise exception 'trip_not_found' using errcode = 'P0001';
  end if;

  update public.trips
  set deleted_at = now(), updated_at = now()
  where id = p_trip_id;
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
security definer
set search_path = public, pg_temp
as $$
declare
  v_deleted_at timestamptz;
begin
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));

  select trip.deleted_at
  into v_deleted_at
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
    select 1
    from public.trips as other
    where other.user_id = auth.uid()
      and other.id <> p_trip_id
      and other.deleted_at is null
      and other.start_date <= p_end_date
      and other.end_date >= p_start_date
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
  where id = p_trip_id;
end;
$$;

revoke execute on function public.move_trip_to_trash(uuid)
  from public, anon, service_role;
revoke execute on function public.restore_trip(
  uuid, text, text, date, date, text
) from public, anon, service_role;
grant execute on function public.move_trip_to_trash(uuid)
  to authenticated;
grant execute on function public.restore_trip(
  uuid, text, text, date, date, text
) to authenticated;

create or replace function public.storage_trip_mutation_allowed(
  p_name text,
  p_allow_missing_parent boolean
)
returns boolean
language plpgsql
volatile
security definer
set search_path = public, storage, pg_temp
as $$
declare
  v_folders text[];
  v_trip_id uuid;
  v_owner_id uuid;
begin
  if auth.uid() is null then return false; end if;
  v_folders := storage.foldername(p_name);
  if cardinality(v_folders) < 2
    or v_folders[1] <> auth.uid()::text
  then
    return false;
  end if;

  begin
    v_trip_id := v_folders[2]::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  if v_folders[2] <> v_trip_id::text then return false; end if;

  select trip.user_id
  into v_owner_id
  from public.trips as trip
  where trip.id = v_trip_id
  for update;

  if not found then return p_allow_missing_parent; end if;
  if v_owner_id <> auth.uid() then return false; end if;
  return not public.trip_is_purge_claimed(v_trip_id);
end;
$$;

revoke execute on function public.storage_trip_mutation_allowed(text, boolean)
  from public, anon, service_role;
grant execute on function public.storage_trip_mutation_allowed(text, boolean)
  to authenticated;

drop policy if exists "trip_covers_insert_own" on storage.objects;
create policy "trip_covers_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'trip-covers'
    and public.storage_trip_mutation_allowed(name, true)
  );

drop policy if exists "trip_covers_update_own" on storage.objects;
create policy "trip_covers_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'trip-covers'
    and public.storage_trip_mutation_allowed(name, false)
  )
  with check (
    bucket_id = 'trip-covers'
    and public.storage_trip_mutation_allowed(name, false)
  );

drop policy if exists "trip_covers_delete_own" on storage.objects;
create policy "trip_covers_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'trip-covers'
    and public.storage_trip_mutation_allowed(name, false)
  );

drop policy if exists "journal_photos_insert_own" on storage.objects;
create policy "journal_photos_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'journal-photos'
    and public.storage_trip_mutation_allowed(name, false)
  );

drop policy if exists "journal_photos_select_own" on storage.objects;
create policy "journal_photos_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'journal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "journal_photos_update_own" on storage.objects;
create policy "journal_photos_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'journal-photos'
    and public.storage_trip_mutation_allowed(name, false)
  )
  with check (
    bucket_id = 'journal-photos'
    and public.storage_trip_mutation_allowed(name, false)
  );

drop policy if exists "journal_photos_delete_own" on storage.objects;
create policy "journal_photos_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'journal-photos'
    and public.storage_trip_mutation_allowed(name, false)
  );

create or replace function public.claim_expired_trip_purges(
  p_cutoff timestamptz,
  p_limit integer default 100
)
returns table (
  trip_id uuid,
  claim_token uuid,
  owner_id uuid,
  cover_photo_url text,
  journal_photo_urls text[]
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_trip_id uuid;
  v_claim public.trip_purge_claims%rowtype;
  v_owner_id uuid;
  v_cover_photo_url text;
  v_journal_photo_urls text[];
begin
  if p_cutoff is null or p_limit < 1 or p_limit > 500 then
    raise exception 'invalid_purge_claim_request'
      using errcode = '22023';
  end if;

  for v_trip_id in
    select trip.id
    from public.trips as trip
    where trip.deleted_at is not null
      and trip.deleted_at <= p_cutoff
      and (
        not exists (
          select 1 from public.trip_purge_claims as active
          where active.trip_id = trip.id
        )
        or exists (
          select 1 from public.trip_purge_claims as stale
          where stale.trip_id = trip.id
            and stale.lease_expires_at <= clock_timestamp()
        )
      )
    order by trip.deleted_at, trip.id
    for update skip locked
    limit p_limit
  loop
    select claim.*
    into v_claim
    from public.trip_purge_claims as claim
    where claim.trip_id = v_trip_id
    for update;

    if found then
      if v_claim.lease_expires_at > clock_timestamp() then
        continue;
      end if;
      update public.trip_purge_claims as claim
      set
        claim_token = gen_random_uuid(),
        lease_expires_at = clock_timestamp() + interval '1 hour'
      where claim.trip_id = v_trip_id
      returning claim.* into v_claim;
    else
      select trip.user_id, trip.cover_photo_url
      into v_owner_id, v_cover_photo_url
      from public.trips as trip
      where trip.id = v_trip_id;

      select coalesce(
        array_agg(photo.url order by entry.id, photo.ordinality)
          filter (where photo.url is not null),
        '{}'::text[]
      )
      into v_journal_photo_urls
      from public.journal_entries as entry
      cross join lateral unnest(entry.photo_urls)
        with ordinality as photo(url, ordinality)
      where entry.trip_id = v_trip_id;

      insert into public.trip_purge_claims (
        trip_id,
        claim_token,
        owner_id,
        cutoff_at,
        cover_photo_url,
        journal_photo_urls,
        lease_expires_at
      ) values (
        v_trip_id,
        gen_random_uuid(),
        v_owner_id,
        p_cutoff,
        v_cover_photo_url,
        v_journal_photo_urls,
        clock_timestamp() + interval '1 hour'
      )
      returning * into v_claim;
    end if;

    return query
    select
      v_claim.trip_id,
      v_claim.claim_token,
      v_claim.owner_id,
      v_claim.cover_photo_url,
      v_claim.journal_photo_urls;
  end loop;
end;
$$;

create or replace function public.complete_trip_purge(
  p_trip_id uuid,
  p_claim_token uuid
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_claim public.trip_purge_claims%rowtype;
  v_deleted_at timestamptz;
begin
  select claim.*
  into v_claim
  from public.trip_purge_claims as claim
  where claim.trip_id = p_trip_id
  for update;

  if not found then
    if not exists (select 1 from public.trips where id = p_trip_id) then
      return true;
    end if;
    raise exception 'purge_claim_mismatch' using errcode = 'P0001';
  end if;
  if v_claim.claim_token <> p_claim_token then
    raise exception 'purge_claim_mismatch' using errcode = 'P0001';
  end if;

  select trip.deleted_at
  into v_deleted_at
  from public.trips as trip
  where trip.id = p_trip_id
  for update;

  if not found then return true; end if;
  if v_deleted_at is null or v_deleted_at > v_claim.cutoff_at then
    raise exception 'purge_claim_ineligible' using errcode = 'P0001';
  end if;

  perform set_config(
    'tripjournal.purge_claim_token',
    p_claim_token::text,
    true
  );
  delete from public.trips where id = p_trip_id;
  if not found then
    raise exception 'purge_delete_failed' using errcode = 'P0001';
  end if;
  return true;
end;
$$;

revoke execute on function public.claim_expired_trip_purges(
  timestamptz, integer
) from public, anon, authenticated;
revoke execute on function public.complete_trip_purge(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.claim_expired_trip_purges(
  timestamptz, integer
) to service_role;
grant execute on function public.complete_trip_purge(uuid, uuid)
  to service_role;
