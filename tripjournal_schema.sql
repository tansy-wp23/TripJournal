-- ============================================================================
-- TripJournal — Database Schema (Sang You's modules: Trip + Wellness Journal)
-- Paste into the Supabase SQL Editor and Run.
-- ============================================================================
--
-- DECISIONS BAKED IN:
--   * user_id references auth.users(id) directly  [SAFE DEFAULT — see note]
--   * Entry photos: stored as a text[] array column on journal_entries (simple)
--   * Food/meal photos: PERSISTED on meals.photo_url  [REVERSED 2026-08-19]
--     Originally "NOT persisted (transient input to AI detection only)". The
--     app outgrew that: Meal.photoPath keeps the user's photo whether or not
--     detection recognised the food, the PDF export prints meal photos, and
--     the trip slideshow has a food-photo toggle. Keeping the column is what
--     makes those shipped features survive a restart.
--   * Entry location: journal_entries.location jsonb (GeoTag) — added with the
--     entry location picker, see migration 202608190001
--   * Row Level Security (RLS) enabled on every table, with per-user policies
--
-- ⚠️ REVISIT AT INTEGRATION:
--   user_id currently references auth.users(id). If the auth/profile owner
--   later adds a `profiles` table and the team standardises on linking to it,
--   change the REFERENCES clause to profiles(id). The stored UUID values do
--   NOT change (profiles.id == auth.users.id), so this is a low-pain migration
--   (ALTER the foreign key only). RLS policies and app code are unaffected.
--
-- 📸 PHOTOS: actual image files are NOT stored in these tables. They go in a
--   Supabase STORAGE bucket; only the resulting URL strings are saved here
--   (journal_entries.photo_urls). The trip-covers and journal-photos buckets
--   and their access policies are configured below.
-- ============================================================================


-- ============================================================================
-- 1. TRIPS
-- Parent container. Journal entries belong to a trip.
-- ============================================================================
create table public.trips (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  title          text not null check (char_length(title) <= 100),
  destination    text,
  cover_photo_url text,                              -- single cover image URL (Storage); nullable
  start_date     date not null,
  end_date       date not null,
  notes          text,                              -- trip-level Notes/Reminders; optional
  summary        text,                              -- generated summary, optionally user-edited
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint trips_end_after_start check (end_date >= start_date)
);

comment on table public.trips is 'Trips owned by a user; container for journal entries.';
comment on column public.trips.notes is 'Trip-level Notes/Reminders (things to prepare/remember). Not per-day, not itinerary.';

create index trips_user_id_idx on public.trips (user_id);
create index trips_user_deleted_at_idx on public.trips (user_id, deleted_at);


-- ============================================================================
-- 2. JOURNAL_ENTRIES
-- Belongs to a trip. Multiple entries per day allowed.
-- Entry photos stored as an array of Storage URL strings (max 5 enforced).
-- ============================================================================
create table public.journal_entries (
  id           uuid primary key default gen_random_uuid(),
  trip_id      uuid not null references public.trips(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  title        text check (char_length(title) <= 100),
  body         text check (char_length(body) <= 5000),
  mood         text,                                -- e.g. 'happy','tired','excited','stressed','neutral'
  photo_urls   text[] not null default '{}',        -- Storage URLs; app enforces max 5
  location     jsonb,                               -- GeoTag; null when untagged
  entry_date   date not null,                       -- which calendar day of the trip this belongs to
  created_at   timestamptz not null default now(),  -- entry timestamp (orders multiple same-day entries)
  updated_at   timestamptz not null default now(),
  -- must have a title OR a body (at least one non-empty)
  constraint entry_title_or_body check (
    (title is not null and char_length(trim(title)) > 0)
    or (body is not null and char_length(trim(body)) > 0)
  ),
  -- at most 5 photos (DB backstop; app also enforces + warns)
  constraint entry_max_5_photos check (array_length(photo_urls, 1) is null or array_length(photo_urls, 1) <= 5),
  constraint journal_entries_location_geo_tag_check check (
    case
      when location is null then true
      when jsonb_typeof(location) <> 'object' then false
      when jsonb_typeof(location -> 'latitude') <> 'number' then false
      when jsonb_typeof(location -> 'longitude') <> 'number' then false
      when not ((location ->> 'latitude')::numeric between -90 and 90) then false
      when not ((location ->> 'longitude')::numeric between -180 and 180) then false
      when location ? 'placeName'
        and jsonb_typeof(location -> 'placeName') not in ('string', 'null') then false
      when location ? 'formattedAddress'
        and jsonb_typeof(location -> 'formattedAddress') not in ('string', 'null') then false
      when location ? 'placeId'
        and jsonb_typeof(location -> 'placeId') not in ('string', 'null') then false
      else true
    end
  )
);

comment on table public.journal_entries is 'Journal entries belonging to a trip; multiple per day allowed.';
comment on column public.journal_entries.photo_urls is 'Array of Supabase Storage URLs. Actual files live in Storage, not here. App enforces max 5.';
comment on column public.journal_entries.location is 'GeoTag as JSON: latitude, longitude, placeName, formattedAddress, placeId. Null for an entry with no location tagged.';
comment on column public.journal_entries.entry_date is 'Calendar day within the trip range. Must fall within trips.start_date..end_date (enforced in app).';

create index journal_entries_trip_id_idx on public.journal_entries (trip_id);
create index journal_entries_user_id_idx on public.journal_entries (user_id);
create index journal_entries_entry_date_idx on public.journal_entries (entry_date);


-- ============================================================================
-- 3. HEALTH_LOGS
-- One health log per journal entry (steps, calories eaten/burned, AI advice).
-- Meals live in their own table linked to the health log.
-- ============================================================================
create table public.health_logs (
  id              uuid primary key default gen_random_uuid(),
  entry_id        uuid not null unique references public.journal_entries(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  steps           integer check (steps is null or (steps >= 0 and steps <= 100000)),
  calories_eaten  integer check (calories_eaten is null or calories_eaten >= 0),  -- summed from meals
  calories_burned integer check (calories_burned is null or calories_burned >= 0), -- from health platform; nullable
  ai_advice       text,                              -- AI daily advice text (food + steps + mood)
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.health_logs is 'Per-entry health log: steps, calories eaten/burned, AI advice.';
comment on column public.health_logs.calories_eaten is 'Sum of the entry meals calories. NOT the same as calories_burned.';
comment on column public.health_logs.calories_burned is 'Energy burned (health platform). Nullable if no health data. No net calc is stored.';

create index health_logs_entry_id_idx on public.health_logs (entry_id);
create index health_logs_user_id_idx on public.health_logs (user_id);


-- ============================================================================
-- 4. MEALS
-- Belongs to a health log. Name required, calories >= 0 (default 0), portion.
-- Food photos ARE persisted on photo_url (reversed 2026-08-19 — see header).
-- ============================================================================
create table public.meals (
  id            uuid primary key default gen_random_uuid(),
  health_log_id uuid not null references public.health_logs(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  name          text not null check (char_length(trim(name)) > 0),
  calories      integer not null default 0 check (calories >= 0),  -- blank defaults to 0
  portion       text not null default 'regular' check (portion in ('small','regular','large')),
  meal_type     text check (meal_type in ('breakfast','lunch','dinner','snack')),
  photo_url     text,                              -- Storage URL; null if typed by hand
  rating        smallint check (rating is null or (rating between 1 and 5)),  -- 1-5 stars; null = not rated
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.meals is 'Meals for a health log. Food photos ARE stored as a Storage URL on photo_url.';
comment on column public.meals.photo_url is 'Storage URL of the photo this meal was logged from. Null for a meal typed in by hand. Kept even when AI detection failed to recognise the food.';
comment on column public.meals.portion is 'small/regular/large. Used to scale the calorie estimate (editable).';

create index meals_health_log_id_idx on public.meals (health_log_id);
create index meals_user_id_idx on public.meals (user_id);


-- ============================================================================
-- ROW LEVEL SECURITY
-- Enable RLS + policies so each user can only see/modify their OWN rows.
-- Every table carries user_id; policies check it against auth.uid().
-- ============================================================================

-- ---- trips ----
alter table public.trips enable row level security;

create policy "trips_select_own" on public.trips
  for select using (auth.uid() = user_id);
create policy "trips_insert_own" on public.trips
  for insert with check (auth.uid() = user_id);
create policy "trips_update_own" on public.trips
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Required by the SECURITY INVOKER trip lifecycle RPCs below. RLS still
-- limits both privileges to rows owned by auth.uid().
grant select, update on table public.trips to authenticated;

-- ---- journal_entries ----
alter table public.journal_entries enable row level security;

create policy "entries_select_own" on public.journal_entries
  for select using (auth.uid() = user_id);
create policy "entries_insert_own" on public.journal_entries
  for insert with check (auth.uid() = user_id);
create policy "entries_update_own" on public.journal_entries
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "entries_delete_own" on public.journal_entries
  for delete using (auth.uid() = user_id);

-- ---- health_logs ----
alter table public.health_logs enable row level security;

create policy "health_select_own" on public.health_logs
  for select using (auth.uid() = user_id);
create policy "health_insert_own" on public.health_logs
  for insert with check (auth.uid() = user_id);
create policy "health_update_own" on public.health_logs
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "health_delete_own" on public.health_logs
  for delete using (auth.uid() = user_id);

-- ---- meals ----
alter table public.meals enable row level security;

create policy "meals_select_own" on public.meals
  for select using (auth.uid() = user_id);
create policy "meals_insert_own" on public.meals
  for insert with check (auth.uid() = user_id);
create policy "meals_update_own" on public.meals
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "meals_delete_own" on public.meals
  for delete using (auth.uid() = user_id);


-- ============================================================================
-- OPTIONAL: keep updated_at fresh automatically on UPDATE.
-- (Otherwise set updated_at from the app on each write.)
-- ============================================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trips_set_updated_at
  before update on public.trips
  for each row execute function public.set_updated_at();

create trigger entries_set_updated_at
  before update on public.journal_entries
  for each row execute function public.set_updated_at();

create trigger health_set_updated_at
  before update on public.health_logs
  for each row execute function public.set_updated_at();

create trigger meals_set_updated_at
  before update on public.meals
  for each row execute function public.set_updated_at();


-- ============================================================================
-- TRIP TRASH LIFECYCLE
-- Trips are soft-deleted and restored through authenticated SECURITY INVOKER
-- RPCs so ownership remains enforced by the trips RLS policies.
-- ============================================================================
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
  p_destination text,
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
    destination = p_destination,
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
revoke execute on function public.restore_trip(uuid, text, text, text, date, date, text) from public, anon;
grant execute on function public.move_trip_to_trash(uuid) to authenticated;
grant execute on function public.restore_trip(uuid, text, text, text, date, date, text) to authenticated;


-- ============================================================================
-- TRIP COVER STORAGE
-- Public reads are available through object URLs, while object mutations and
-- authenticated listing are restricted to the owner's top-level folder.
-- ============================================================================
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

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'journal-photos',
  'journal-photos',
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

-- ============================================================================
-- DURABLE PURGE CLAIM SAFETY
-- The scheduled service claims an immutable Storage snapshot before deleting
-- any object. Claimed trip/journal rows and their Storage objects are frozen
-- until the token-matched final cascade succeeds.
-- ============================================================================
create table public.trip_purge_claims (
  trip_id uuid primary key references public.trips(id) on delete cascade,
  claim_token uuid not null unique,
  owner_id uuid not null references auth.users(id) on delete cascade,
  cutoff_at timestamptz not null,
  cover_photo_url text,
  journal_photo_urls text[] not null default '{}',
  created_at timestamptz not null default now(),
  lease_expires_at timestamptz not null
);

create index trip_purge_claims_lease_idx
  on public.trip_purge_claims (lease_expires_at, trip_id);

-- Bind every journal row to a trip owned by the same user. NOT VALID keeps
-- the FK write-safe while it is installed; validation then fails the
-- schema application rather than preserving any cross-owner rows.
create unique index trips_id_user_id_uidx
  on public.trips (id, user_id);

alter table public.journal_entries
  add constraint journal_entries_trip_owner_fkey
  foreign key (trip_id, user_id)
  references public.trips (id, user_id)
  on delete cascade
  not valid;

alter table public.journal_entries
  validate constraint journal_entries_trip_owner_fkey;

alter table public.trip_purge_claims enable row level security;
revoke all on table public.trip_purge_claims
  from public, anon, authenticated, service_role;

create or replace function public.trip_is_purge_claimed(p_trip_id uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.trip_purge_claims as claim
    where claim.trip_id = p_trip_id
  )
$$;

revoke execute on function public.trip_is_purge_claimed(uuid)
  from public, anon, service_role;
grant execute on function public.trip_is_purge_claimed(uuid)
  to authenticated;

create or replace function public.guard_claimed_trip_mutation()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_claim_token uuid;
begin
  select claim.claim_token into v_claim_token
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
create trigger trips_guard_purge_claim
  before update or delete on public.trips
  for each row execute function public.guard_claimed_trip_mutation();

create or replace function public.guard_claimed_journal_mutation()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_old_trip_id uuid;
  v_new_trip_id uuid;
begin
  v_old_trip_id := case when tg_op in ('UPDATE', 'DELETE') then old.trip_id end;
  v_new_trip_id := case when tg_op in ('INSERT', 'UPDATE') then new.trip_id end;

  if tg_op = 'DELETE' and exists (
    select 1 from public.trip_purge_claims as claim
    where claim.trip_id = v_old_trip_id
      and current_setting('tripjournal.purge_claim_token', true)
        = claim.claim_token::text
  ) then
    return old;
  end if;

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
create trigger journal_entries_guard_purge_claim
  before insert or update or delete on public.journal_entries
  for each row execute function public.guard_claimed_journal_mutation();

revoke update on table public.trips from authenticated;
grant update (
  title,
  destination,
  cover_photo_url,
  start_date,
  end_date,
  notes,
  summary
)
  on table public.trips to authenticated;

drop policy "trips_insert_own" on public.trips;
create policy "trips_insert_own" on public.trips
  for insert to authenticated
  with check (auth.uid() = user_id and deleted_at is null);

drop policy "trips_update_own" on public.trips;
create policy "trips_update_own" on public.trips
  for update to authenticated
  using (
    auth.uid() = user_id and not public.trip_is_purge_claimed(id)
  )
  with check (
    auth.uid() = user_id and not public.trip_is_purge_claimed(id)
  );

drop policy "entries_insert_own" on public.journal_entries;
create policy "entries_insert_own" on public.journal_entries
  for insert to authenticated
  with check (
    auth.uid() = user_id and not public.trip_is_purge_claimed(trip_id)
  );

drop policy "entries_update_own" on public.journal_entries;
create policy "entries_update_own" on public.journal_entries
  for update to authenticated
  using (
    auth.uid() = user_id and not public.trip_is_purge_claimed(trip_id)
  )
  with check (
    auth.uid() = user_id and not public.trip_is_purge_claimed(trip_id)
  );

drop policy "entries_delete_own" on public.journal_entries;
create policy "entries_delete_own" on public.journal_entries
  for delete to authenticated
  using (
    auth.uid() = user_id and not public.trip_is_purge_claimed(trip_id)
  );

-- Replace the earlier invoker lifecycle definitions. Column grants now keep
-- deleted_at server-owned, while these definer functions still bind auth.uid.
create or replace function public.move_trip_to_trash(p_trip_id uuid)
returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_deleted_at timestamptz;
begin
  select trip.deleted_at into v_deleted_at
  from public.trips as trip
  where trip.id = p_trip_id and trip.user_id = auth.uid()
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

revoke execute on function public.move_trip_to_trash(uuid)
  from public, anon, service_role;
revoke execute on function public.restore_trip(
  uuid, text, text, text, date, date, text
) from public, anon, service_role;
grant execute on function public.move_trip_to_trash(uuid) to authenticated;
grant execute on function public.restore_trip(
  uuid, text, text, text, date, date, text
) to authenticated;

create or replace function public.storage_trip_mutation_allowed(
  p_name text,
  p_allow_missing_parent boolean
)
returns boolean
language plpgsql volatile security definer
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
  select trip.user_id into v_owner_id
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

drop policy "trip_covers_insert_own" on storage.objects;
create policy "trip_covers_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'trip-covers'
    and public.storage_trip_mutation_allowed(name, true)
  );
drop policy "trip_covers_update_own" on storage.objects;
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
drop policy "trip_covers_delete_own" on storage.objects;
create policy "trip_covers_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'trip-covers'
    and public.storage_trip_mutation_allowed(name, true)
  );

create policy "journal_photos_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'journal-photos'
    and public.storage_trip_mutation_allowed(name, false)
  );
create policy "journal_photos_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'journal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
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
language plpgsql security definer
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
    raise exception 'invalid_purge_claim_request' using errcode = '22023';
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
    select claim.* into v_claim
    from public.trip_purge_claims as claim
    where claim.trip_id = v_trip_id
    for update;
    if found then
      if v_claim.lease_expires_at > clock_timestamp() then continue; end if;
      update public.trip_purge_claims as claim
      set claim_token = gen_random_uuid(),
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
      ) into v_journal_photo_urls
      from public.journal_entries as entry
      cross join lateral unnest(entry.photo_urls)
        with ordinality as photo(url, ordinality)
      where entry.trip_id = v_trip_id;
      insert into public.trip_purge_claims (
        trip_id, claim_token, owner_id, cutoff_at, cover_photo_url,
        journal_photo_urls, lease_expires_at
      ) values (
        v_trip_id, gen_random_uuid(), v_owner_id, p_cutoff,
        v_cover_photo_url, v_journal_photo_urls,
        clock_timestamp() + interval '1 hour'
      ) returning * into v_claim;
    end if;
    return query select
      v_claim.trip_id, v_claim.claim_token, v_claim.owner_id,
      v_claim.cover_photo_url, v_claim.journal_photo_urls;
  end loop;
end;
$$;

create or replace function public.complete_trip_purge(
  p_trip_id uuid,
  p_claim_token uuid
)
returns boolean
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_claim public.trip_purge_claims%rowtype;
  v_deleted_at timestamptz;
begin
  select claim.* into v_claim
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
  select trip.deleted_at into v_deleted_at
  from public.trips as trip
  where trip.id = p_trip_id
  for update;
  if not found then return true; end if;
  if v_deleted_at is null or v_deleted_at > v_claim.cutoff_at then
    raise exception 'purge_claim_ineligible' using errcode = 'P0001';
  end if;
  perform set_config(
    'tripjournal.purge_claim_token', p_claim_token::text, true
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

-- ============================================================================
-- ATOMIC JOURNAL BUNDLE WRITES
-- ============================================================================
grant select, delete on table public.journal_entries to authenticated;
revoke insert, update on table public.journal_entries from authenticated;
grant select on table public.health_logs to authenticated;
revoke insert, update, delete on table public.health_logs from authenticated;
grant select on table public.meals to authenticated;
revoke insert, update, delete on table public.meals from authenticated;

create or replace function public.save_journal_entry_bundle(
  p_entry jsonb,
  p_health_log jsonb,
  p_meals jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_entry_id uuid;
  v_trip_id uuid;
  v_existing_trip_id uuid;
  v_health_log_id uuid;
  v_meal jsonb;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;
  if jsonb_typeof(p_entry) <> 'object' then
    raise exception 'invalid_entry_payload' using errcode = '22023';
  end if;
  if p_health_log is not null and jsonb_typeof(p_health_log) <> 'object' then
    raise exception 'invalid_health_log_payload' using errcode = '22023';
  end if;
  if p_meals is null or jsonb_typeof(p_meals) <> 'array' then
    raise exception 'invalid_meals_payload' using errcode = '22023';
  end if;
  if p_health_log is null and jsonb_array_length(p_meals) <> 0 then
    raise exception 'meals_require_health_log' using errcode = '22023';
  end if;

  v_entry_id := (p_entry ->> 'id')::uuid;
  v_trip_id := (p_entry ->> 'trip_id')::uuid;
  perform 1 from public.trips
  where id = v_trip_id and user_id = v_user_id and deleted_at is null
  for update;
  if not found then
    raise exception 'trip_not_found' using errcode = 'P0001';
  end if;

  select trip_id into v_existing_trip_id
  from public.journal_entries
  where id = v_entry_id and user_id = v_user_id
  for update;

  if found then
    if v_existing_trip_id <> v_trip_id then
      raise exception 'entry_trip_cannot_change' using errcode = '22023';
    end if;
    update public.journal_entries set
      title = p_entry ->> 'title',
      body = p_entry ->> 'body',
      mood = p_entry ->> 'mood',
      photo_urls = coalesce(
        array(select jsonb_array_elements_text(p_entry -> 'photo_urls')), '{}'
      ),
      location = nullif(p_entry -> 'location', 'null'::jsonb),
      entry_date = (p_entry ->> 'entry_date')::date,
      updated_at = (p_entry ->> 'updated_at')::timestamptz
    where id = v_entry_id and user_id = v_user_id;
  else
    insert into public.journal_entries (
      id, trip_id, user_id, title, body, mood, photo_urls, location,
      entry_date, created_at, updated_at
    ) values (
      v_entry_id,
      v_trip_id,
      v_user_id,
      p_entry ->> 'title',
      p_entry ->> 'body',
      p_entry ->> 'mood',
      coalesce(
        array(select jsonb_array_elements_text(p_entry -> 'photo_urls')), '{}'
      ),
      nullif(p_entry -> 'location', 'null'::jsonb),
      (p_entry ->> 'entry_date')::date,
      (p_entry ->> 'created_at')::timestamptz,
      (p_entry ->> 'updated_at')::timestamptz
    );
  end if;

  delete from public.health_logs
  where entry_id = v_entry_id and user_id = v_user_id;

  if p_health_log is not null then
    if (p_health_log ->> 'entry_id')::uuid <> v_entry_id then
      raise exception 'health_log_entry_mismatch' using errcode = '22023';
    end if;
    v_health_log_id := (p_health_log ->> 'id')::uuid;
    insert into public.health_logs (
      id, entry_id, user_id, steps, calories_eaten, calories_burned, ai_advice
    ) values (
      v_health_log_id,
      v_entry_id,
      v_user_id,
      (p_health_log ->> 'steps')::integer,
      (p_health_log ->> 'calories_eaten')::integer,
      (p_health_log ->> 'calories_burned')::integer,
      p_health_log ->> 'ai_advice'
    );

    for v_meal in select value from jsonb_array_elements(p_meals)
    loop
      if jsonb_typeof(v_meal) <> 'object'
        or (v_meal ->> 'health_log_id')::uuid <> v_health_log_id then
        raise exception 'meal_health_log_mismatch' using errcode = '22023';
      end if;
      insert into public.meals (
        id, health_log_id, user_id, name, calories, meal_type, portion, photo_url
      ) values (
        (v_meal ->> 'id')::uuid,
        v_health_log_id,
        v_user_id,
        v_meal ->> 'name',
        (v_meal ->> 'calories')::integer,
        v_meal ->> 'meal_type',
        coalesce(v_meal ->> 'portion', 'regular'),
        v_meal ->> 'photo_url'
      );
    end loop;
  end if;
  return v_entry_id;
end;
$$;

revoke execute on function public.save_journal_entry_bundle(jsonb, jsonb, jsonb)
  from public, anon;
grant execute on function public.save_journal_entry_bundle(jsonb, jsonb, jsonb)
  to authenticated;

-- ============================================================================
-- DURABLE PLACES RATE LIMIT
-- ============================================================================
create table public.places_rate_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  request_count integer not null check (request_count between 0 and 20),
  updated_at timestamptz not null default now()
);
alter table public.places_rate_limits enable row level security;
revoke all on table public.places_rate_limits from public, anon, authenticated;

create or replace function public.consume_places_rate_limit()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_window_started_at timestamptz;
  v_request_count integer;
  v_retry_after integer;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;
  insert into public.places_rate_limits (
    user_id, window_started_at, request_count, updated_at
  ) values (v_user_id, v_now, 1, v_now)
  on conflict (user_id) do nothing
  returning window_started_at, request_count
  into v_window_started_at, v_request_count;

  if found then
    return jsonb_build_object(
      'allowed', true, 'remaining', 19, 'retry_after_seconds', 0
    );
  end if;

  select window_started_at, request_count
  into v_window_started_at, v_request_count
  from public.places_rate_limits
  where user_id = v_user_id
  for update;

  if v_window_started_at + interval '60 seconds' <= v_now then
    update public.places_rate_limits
    set window_started_at = v_now, request_count = 1, updated_at = v_now
    where user_id = v_user_id;
    return jsonb_build_object(
      'allowed', true, 'remaining', 19, 'retry_after_seconds', 0
    );
  end if;
  if v_request_count >= 20 then
    v_retry_after := greatest(
      1,
      ceil(extract(epoch from (
        v_window_started_at + interval '60 seconds' - v_now
      )))::integer
    );
    return jsonb_build_object(
      'allowed', false,
      'remaining', 0,
      'retry_after_seconds', v_retry_after
    );
  end if;
  update public.places_rate_limits
  set request_count = request_count + 1, updated_at = v_now
  where user_id = v_user_id;
  return jsonb_build_object(
    'allowed', true,
    'remaining', 19 - v_request_count,
    'retry_after_seconds', 0
  );
end;
$$;

revoke execute on function public.consume_places_rate_limit()
  from public, anon;
grant execute on function public.consume_places_rate_limit()
  to authenticated;

-- ============================================================================
-- Public trip publishing: adds is_public visibility, publisher identity
-- snapshot, and cross-user SELECT policies for trips + child tables.
-- ============================================================================

alter table public.trips
  add column if not exists is_public              boolean      not null default false,
  add column if not exists published_at           timestamptz,
  add column if not exists publisher_display_name text,
  add column if not exists publisher_avatar_url   text;

create index if not exists trips_public_published_idx
  on public.trips (published_at desc)
  where is_public = true and deleted_at is null;

grant update (is_public, published_at, publisher_display_name, publisher_avatar_url)
  on table public.trips to authenticated;

grant update (summary) on table public.trips to authenticated;

drop policy if exists "trips_select_public" on public.trips;
create policy "trips_select_public" on public.trips
  for select to authenticated
  using (is_public = true and deleted_at is null);

drop policy if exists "entries_select_public" on public.journal_entries;
create policy "entries_select_public" on public.journal_entries
  for select to authenticated
  using (
    exists (
      select 1 from public.trips as t
      where t.id = trip_id and t.is_public = true and t.deleted_at is null
    )
  );

drop policy if exists "health_logs_select_public" on public.health_logs;
create policy "health_logs_select_public" on public.health_logs
  for select to authenticated
  using (
    exists (
      select 1
      from public.journal_entries as e
      join public.trips as t on t.id = e.trip_id
      where e.id = entry_id and t.is_public = true and t.deleted_at is null
    )
  );

drop policy if exists "meals_select_public" on public.meals;
create policy "meals_select_public" on public.meals
  for select to authenticated
  using (
    exists (
      select 1
      from public.health_logs as hl
      join public.journal_entries as e on e.id = hl.entry_id
      join public.trips as t on t.id = e.trip_id
      where hl.id = health_log_id and t.is_public = true and t.deleted_at is null
    )
  );

-- ============================================================================
-- END. Next steps (NOT SQL):
--   1. Android: add INTERNET permission to the manifest.
--   2. Confirm Data API exposes the public schema tables (default privileges).
-- ============================================================================
