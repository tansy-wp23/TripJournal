\set ON_ERROR_STOP on

begin;

insert into auth.users (id)
values
  ('10000000-0000-4000-8000-000000000001'),
  ('10000000-0000-4000-8000-000000000002')
on conflict (id) do nothing;

insert into public.trips (
  id, user_id, title, destination, start_date, end_date, created_at, updated_at
) values (
  '20000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  'Atomic journal test',
  'Penang',
  date '2026-08-01',
  date '2026-08-03',
  now(),
  now()
);

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-4000-8000-000000000001';

select public.save_journal_entry_bundle(
  jsonb_build_object(
    'id', '30000000-0000-4000-8000-000000000001',
    'trip_id', '20000000-0000-4000-8000-000000000001',
    'title', 'Kek Lok Si',
    'body', 'A long walk.',
    'mood', 'happy',
    'photo_urls', jsonb_build_array('https://cdn.example/entry.jpg'),
    'location', jsonb_build_object(
      'latitude', 5.4141,
      'longitude', 100.3288,
      'placeName', 'Kek Lok Si'
    ),
    'entry_date', '2026-08-01',
    'created_at', '2026-08-01T02:00:00Z',
    'updated_at', '2026-08-01T03:00:00Z'
  ),
  jsonb_build_object(
    'id', '40000000-0000-4000-8000-000000000001',
    'entry_id', '30000000-0000-4000-8000-000000000001',
    'steps', 9000,
    'calories_eaten', 550,
    'calories_burned', 430,
    'ai_advice', 'Keep hydrated.'
  ),
  jsonb_build_array(jsonb_build_object(
    'id', '50000000-0000-4000-8000-000000000001',
    'health_log_id', '40000000-0000-4000-8000-000000000001',
    'name', 'Ramen',
    'calories', 550,
    'meal_type', 'lunch',
    'portion', 'large',
    'photo_url', 'https://cdn.example/meal.jpg'
  ))
);

do $$
begin
  if (select count(*) from public.journal_entries where id = '30000000-0000-4000-8000-000000000001') <> 1 then
    raise exception 'bundle did not create exactly one entry';
  end if;
  if (select count(*) from public.health_logs where entry_id = '30000000-0000-4000-8000-000000000001') <> 1 then
    raise exception 'bundle did not create exactly one health log';
  end if;
  if (select count(*) from public.meals where health_log_id = '40000000-0000-4000-8000-000000000001') <> 1 then
    raise exception 'bundle did not create exactly one meal';
  end if;
end;
$$;

do $$
begin
  begin
    perform public.save_journal_entry_bundle(
      jsonb_build_object(
        'id', '30000000-0000-4000-8000-000000000001',
        'trip_id', '20000000-0000-4000-8000-000000000001',
        'title', 'This update must roll back',
        'body', 'Changed body',
        'mood', 'neutral',
        'photo_urls', '[]'::jsonb,
        'location', null,
        'entry_date', '2026-08-01',
        'created_at', '2026-08-01T02:00:00Z',
        'updated_at', '2026-08-01T04:00:00Z'
      ),
      jsonb_build_object(
        'id', '40000000-0000-4000-8000-000000000001',
        'entry_id', '30000000-0000-4000-8000-000000000001',
        'steps', 1,
        'calories_eaten', 1
      ),
      jsonb_build_array(jsonb_build_object(
        'id', '50000000-0000-4000-8000-000000000009',
        'health_log_id', '40000000-0000-4000-8000-000000000001',
        'name', 'Invalid update meal',
        'calories', -1,
        'meal_type', 'snack',
        'portion', 'regular'
      ))
    );
    raise exception 'invalid bundle update unexpectedly saved';
  exception
    when check_violation then null;
  end;

  if (
    select title from public.journal_entries
    where id = '30000000-0000-4000-8000-000000000001'
  ) <> 'Kek Lok Si' then
    raise exception 'failed bundle update did not restore the previous entry';
  end if;
end;
$$;

set local "request.jwt.claim.sub" = '10000000-0000-4000-8000-000000000002';
do $$
begin
  begin
    perform public.save_journal_entry_bundle(
      jsonb_build_object(
        'id', '30000000-0000-4000-8000-000000000008',
        'trip_id', '20000000-0000-4000-8000-000000000001',
        'title', 'Cross-owner entry',
        'body', '',
        'mood', 'neutral',
        'photo_urls', '[]'::jsonb,
        'location', null,
        'entry_date', '2026-08-01',
        'created_at', '2026-08-01T02:00:00Z',
        'updated_at', '2026-08-01T02:00:00Z'
      ),
      null,
      '[]'::jsonb
    );
    raise exception 'cross-owner bundle unexpectedly saved';
  exception
    when raise_exception then
      if sqlerrm <> 'trip_not_found' then raise; end if;
  end;
end;
$$;
set local "request.jwt.claim.sub" = '10000000-0000-4000-8000-000000000001';

do $$
begin
  begin
    perform public.save_journal_entry_bundle(
      jsonb_build_object(
        'id', '30000000-0000-4000-8000-000000000002',
        'trip_id', '20000000-0000-4000-8000-000000000001',
        'title', 'Must roll back',
        'body', '',
        'mood', 'neutral',
        'photo_urls', '[]'::jsonb,
        'location', null,
        'entry_date', '2026-08-02',
        'created_at', '2026-08-02T02:00:00Z',
        'updated_at', '2026-08-02T02:00:00Z'
      ),
      jsonb_build_object(
        'id', '40000000-0000-4000-8000-000000000002',
        'entry_id', '30000000-0000-4000-8000-000000000002',
        'steps', 1,
        'calories_eaten', 1
      ),
      jsonb_build_array(jsonb_build_object(
        'id', '50000000-0000-4000-8000-000000000002',
        'health_log_id', '40000000-0000-4000-8000-000000000002',
        'name', 'Invalid meal',
        'calories', -1,
        'meal_type', 'snack',
        'portion', 'regular'
      ))
    );
    raise exception 'invalid meal unexpectedly saved';
  exception
    when check_violation then null;
  end;

  if exists (
    select 1 from public.journal_entries
    where id = '30000000-0000-4000-8000-000000000002'
  ) then
    raise exception 'failed bundle left a partial entry';
  end if;

  begin
    insert into public.health_logs (
      id, entry_id, user_id, steps, calories_eaten
    ) values (
      '40000000-0000-4000-8000-000000000009',
      '30000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000001',
      1,
      0
    );
    raise exception 'authenticated caller bypassed the atomic journal RPC';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;

reset role;

do $$
begin
  begin
    insert into public.journal_entries (
      id, trip_id, user_id, title, photo_urls, location, entry_date
    ) values (
      '30000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000001',
      'Invalid location',
      '{}',
      '{"latitude":91,"longitude":100}'::jsonb,
      date '2026-08-03'
    );
    raise exception 'out-of-range location unexpectedly saved';
  exception
    when check_violation then null;
  end;
end;
$$;
rollback;
