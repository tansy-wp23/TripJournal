-- ============================================================================
-- TripJournal — Database Schema (Sang You's modules: Trip + Wellness Journal)
-- Paste into the Supabase SQL Editor and Run.
-- ============================================================================
--
-- DECISIONS BAKED IN:
--   * user_id references auth.users(id) directly  [SAFE DEFAULT — see note]
--   * Entry photos: stored as a text[] array column on journal_entries (simple)
--   * Food/meal photos: NOT persisted (photo is a transient input to AI
--     detection only) — meals has no photo column
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
--   (journal_entries.photo_urls). Create the bucket separately in the
--   dashboard (Storage → New bucket, e.g. "journal-photos") and set its access
--   policies. That is a dashboard step, not part of this SQL.
-- ============================================================================


-- ============================================================================
-- 1. TRIPS
-- Parent container. Journal entries belong to a trip.
-- ============================================================================
create table public.trips (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  title          text not null check (char_length(title) <= 100),
  cover_photo_url text,                              -- single cover image URL (Storage); nullable
  start_date     date not null,
  end_date       date not null,
  notes          text,                              -- trip-level Notes/Reminders; optional
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
  entry_date   date not null,                       -- which calendar day of the trip this belongs to
  created_at   timestamptz not null default now(),  -- entry timestamp (orders multiple same-day entries)
  updated_at   timestamptz not null default now(),
  -- must have a title OR a body (at least one non-empty)
  constraint entry_title_or_body check (
    (title is not null and char_length(trim(title)) > 0)
    or (body is not null and char_length(trim(body)) > 0)
  ),
  -- at most 5 photos (DB backstop; app also enforces + warns)
  constraint entry_max_5_photos check (array_length(photo_urls, 1) is null or array_length(photo_urls, 1) <= 5)
);

comment on table public.journal_entries is 'Journal entries belonging to a trip; multiple per day allowed.';
comment on column public.journal_entries.photo_urls is 'Array of Supabase Storage URLs. Actual files live in Storage, not here. App enforces max 5.';
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
-- Food photos are NOT persisted (photo is a transient input to AI detection).
-- ============================================================================
create table public.meals (
  id            uuid primary key default gen_random_uuid(),
  health_log_id uuid not null references public.health_logs(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  name          text not null check (char_length(trim(name)) > 0),
  calories      integer not null default 0 check (calories >= 0),  -- blank defaults to 0
  portion       text not null default 'regular' check (portion in ('small','regular','large')),
  meal_type     text check (meal_type in ('breakfast','lunch','dinner','snack')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.meals is 'Meals for a health log. Food photos are NOT stored (transient detection input only).';
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
-- END. Next steps (NOT SQL):
--   1. Storage → create a separate bucket (e.g. "journal-photos") for entry
--      images. The trip-covers bucket and policies are configured above.
--   2. Android: add INTERNET permission to the manifest.
--   3. Confirm Data API exposes the public schema tables (default privileges).
-- ============================================================================
