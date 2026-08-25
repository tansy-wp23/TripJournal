-- Make journal writes atomic and reject malformed GeoTag JSON without
-- rewriting any existing user data.

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'journal_entries_location_geo_tag_check'
      and conrelid = 'public.journal_entries'::regclass
  ) then
    alter table public.journal_entries
      add constraint journal_entries_location_geo_tag_check
      check (
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
      ) not valid;
  end if;
end;
$$;

-- Do not silently null or delete old locations. A malformed legacy row blocks
-- validation so an operator can inspect it and decide how to repair it.
do $$
declare
  v_invalid_count bigint;
begin
  select count(*)
  into v_invalid_count
  from public.journal_entries
  where not (
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
  );

  if v_invalid_count > 0 then
    raise exception
      'journal_entries contains % invalid location row(s); no rows were changed',
      v_invalid_count;
  end if;
end;
$$;

alter table public.journal_entries
  validate constraint journal_entries_location_geo_tag_check;

-- The storage policies already target this bucket. Creating it here is
-- idempotent and makes fresh/test projects match configured production ones.
insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
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

  perform 1
  from public.trips
  where id = v_trip_id
    and user_id = v_user_id
    and deleted_at is null
  for update;
  if not found then
    raise exception 'trip_not_found' using errcode = 'P0001';
  end if;

  select trip_id
  into v_existing_trip_id
  from public.journal_entries
  where id = v_entry_id
    and user_id = v_user_id
  for update;

  if found then
    if v_existing_trip_id <> v_trip_id then
      raise exception 'entry_trip_cannot_change' using errcode = '22023';
    end if;

    update public.journal_entries
    set
      title = p_entry ->> 'title',
      body = p_entry ->> 'body',
      mood = p_entry ->> 'mood',
      photo_urls = coalesce(
        array(select jsonb_array_elements_text(p_entry -> 'photo_urls')),
        '{}'
      ),
      location = nullif(p_entry -> 'location', 'null'::jsonb),
      entry_date = (p_entry ->> 'entry_date')::date,
      updated_at = (p_entry ->> 'updated_at')::timestamptz
    where id = v_entry_id
      and user_id = v_user_id;
  else
    insert into public.journal_entries (
      id,
      trip_id,
      user_id,
      title,
      body,
      mood,
      photo_urls,
      location,
      entry_date,
      created_at,
      updated_at
    ) values (
      v_entry_id,
      v_trip_id,
      v_user_id,
      p_entry ->> 'title',
      p_entry ->> 'body',
      p_entry ->> 'mood',
      coalesce(
        array(select jsonb_array_elements_text(p_entry -> 'photo_urls')),
        '{}'
      ),
      nullif(p_entry -> 'location', 'null'::jsonb),
      (p_entry ->> 'entry_date')::date,
      (p_entry ->> 'created_at')::timestamptz,
      (p_entry ->> 'updated_at')::timestamptz
    );
  end if;

  -- Replacing the owned one-to-one log also cascades its old meals. If any
  -- later insert fails, PostgreSQL rolls this delete and the entry write back.
  delete from public.health_logs
  where entry_id = v_entry_id
    and user_id = v_user_id;

  if p_health_log is not null then
    if (p_health_log ->> 'entry_id')::uuid <> v_entry_id then
      raise exception 'health_log_entry_mismatch' using errcode = '22023';
    end if;

    v_health_log_id := (p_health_log ->> 'id')::uuid;
    insert into public.health_logs (
      id,
      entry_id,
      user_id,
      steps,
      calories_eaten,
      calories_burned,
      ai_advice
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
        or (v_meal ->> 'health_log_id')::uuid <> v_health_log_id
      then
        raise exception 'meal_health_log_mismatch' using errcode = '22023';
      end if;

      insert into public.meals (
        id,
        health_log_id,
        user_id,
        name,
        calories,
        meal_type,
        portion,
        photo_url
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

comment on function public.save_journal_entry_bundle(jsonb, jsonb, jsonb) is
  'Atomically creates or updates one journal entry, its optional health log, '
  'and replacement meal list. Ownership is always auth.uid().';

-- One row per user keeps Places throttling durable across Edge Function cold
-- starts and instances without accumulating request history.
create table if not exists public.places_rate_limits (
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
  ) values (
    v_user_id, v_now, 1, v_now
  )
  on conflict (user_id) do nothing
  returning window_started_at, request_count
  into v_window_started_at, v_request_count;

  if found then
    return jsonb_build_object(
      'allowed', true,
      'remaining', 19,
      'retry_after_seconds', 0
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
      'allowed', true,
      'remaining', 19,
      'retry_after_seconds', 0
    );
  end if;

  if v_request_count >= 20 then
    v_retry_after := greatest(
      1,
      ceil(extract(epoch from (v_window_started_at + interval '60 seconds' - v_now)))::integer
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

comment on table public.places_rate_limits is
  'One durable 60-second Google Places request window per authenticated user.';
