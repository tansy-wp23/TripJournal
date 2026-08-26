-- Journal + Health Tracking module — where the meal was eaten, and what the
-- user thought of it. Both optional, same as rating: purely descriptive,
-- never required to save a meal.

alter table public.meals
  add column if not exists restaurant_name text
    check (restaurant_name is null or char_length(restaurant_name) <= 100),
  add column if not exists food_review text
    check (food_review is null or char_length(food_review) <= 250);

comment on column public.meals.restaurant_name is
  'Where the meal was eaten. Null = not recorded. Max 100 chars.';
comment on column public.meals.food_review is
  'Free-text note about the meal. Null = no review. Max 250 chars.';

-- save_journal_entry_bundle's meal insert names its columns explicitly and
-- never picked up `rating` (added by 202608250003_meal_rating.sql), so meal
-- ratings have been silently dropped in Supabase mode since that migration.
-- Recreated here with rating, restaurant_name and food_review all included —
-- otherwise these new columns would fall into the exact same trap.
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
  'restaurant_name and food_review are all included in the insert.';
