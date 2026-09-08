-- Journal + Health Tracking module — parked drafts.
--
-- Backing out of a half-written entry offers "Save draft", which stores a real
-- journal_entries row flagged as a draft. Drafts are visible only in the trip
-- timeline (badged) and the editor; the client filters them out of every other
-- read, and the public-trip policy below refuses to serve them at all.

alter table public.journal_entries
  add column if not exists is_draft boolean not null default false;

comment on column public.journal_entries.is_draft is
  'True while the entry is a parked draft. Excluded from stats, the map, the '
  'AI summary, PDF export and every public/shared view. Saving normally (which '
  'enforces the title-or-body rule) publishes it.';

-- A draft is allowed to be just a photo, a mood or a step count, so the
-- content rule now binds published rows only. Strictly a loosening: every row
-- that satisfied the old constraint still satisfies this one.
alter table public.journal_entries
  drop constraint if exists entry_title_or_body;

alter table public.journal_entries
  add constraint entry_title_or_body check (
    is_draft
    or (title is not null and char_length(trim(title)) > 0)
    or (body is not null and char_length(trim(body)) > 0)
  );

-- The client has INSERT/UPDATE revoked on journal_entries (see
-- 202608250001_journal_bundle_and_location_constraints.sql), so this function
-- is the only write path — a new column is invisible to the app until it is
-- named here. Recreated from the 202608260003 version with is_draft added to
-- both branches; coalesced so a client that omits the field still writes a
-- normal entry.
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
      updated_at = (p_entry ->> 'updated_at')::timestamptz,
      -- Publishing a draft is an ordinary update that sends false.
      is_draft = coalesce((p_entry ->> 'is_draft')::boolean, false)
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
      updated_at,
      is_draft
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
      (p_entry ->> 'updated_at')::timestamptz,
      coalesce((p_entry ->> 'is_draft')::boolean, false)
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
        photo_url,
        rating,
        restaurant_name,
        food_review
      ) values (
        (v_meal ->> 'id')::uuid,
        v_health_log_id,
        v_user_id,
        v_meal ->> 'name',
        (v_meal ->> 'calories')::integer,
        v_meal ->> 'meal_type',
        coalesce(v_meal ->> 'portion', 'regular'),
        v_meal ->> 'photo_url',
        (v_meal ->> 'rating')::smallint,
        v_meal ->> 'restaurant_name',
        v_meal ->> 'food_review'
      );
    end loop;
  end if;

  return v_entry_id;
end;
$$;

comment on function public.save_journal_entry_bundle(jsonb, jsonb, jsonb) is
  'Atomically creates or updates one journal entry, its optional health log, '
  'and replacement meal list. Ownership is always auth.uid(). Meal rating, '
  'restaurant_name and food_review are included, as is the entry is_draft flag.';

-- Defence in depth for the one leak that would actually matter: a draft inside
-- a published trip must never be readable by another viewer, even if some
-- future caller forgets the client-side filter. Mirrors the policy shape from
-- 202608270001_guest_mode_anon_access.sql with the draft exclusion added.
DROP POLICY IF EXISTS "entries_select_public" ON public.journal_entries;
CREATE POLICY "entries_select_public" ON public.journal_entries
  FOR SELECT
  TO authenticated, anon
  USING (
    is_draft = false
    AND EXISTS (
      SELECT 1 FROM public.trips AS t
      WHERE t.id = trip_id
        AND t.is_public = true
        AND t.deleted_at IS NULL
    )
  );

-- The child rows hang off the entry, so exclude them for the same reason:
-- hiding the entry but leaving its health log and meals publicly readable
-- would be a half-closed door.
DROP POLICY IF EXISTS "health_logs_select_public" ON public.health_logs;
CREATE POLICY "health_logs_select_public" ON public.health_logs
  FOR SELECT
  TO authenticated, anon
  USING (
    EXISTS (
      SELECT 1
      FROM public.journal_entries AS e
      JOIN public.trips AS t ON t.id = e.trip_id
      WHERE e.id = entry_id
        AND e.is_draft = false
        AND t.is_public = true
        AND t.deleted_at IS NULL
    )
  );

DROP POLICY IF EXISTS "meals_select_public" ON public.meals;
CREATE POLICY "meals_select_public" ON public.meals
  FOR SELECT
  TO authenticated, anon
  USING (
    EXISTS (
      SELECT 1
      FROM public.health_logs AS hl
      JOIN public.journal_entries AS e ON e.id = hl.entry_id
      JOIN public.trips AS t ON t.id = e.trip_id
      WHERE hl.id = health_log_id
        AND e.is_draft = false
        AND t.is_public = true
        AND t.deleted_at IS NULL
    )
  );
