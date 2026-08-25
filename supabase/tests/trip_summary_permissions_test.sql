\set ON_ERROR_STOP on

begin;

insert into auth.users (id)
values
  ('60000000-0000-4000-8000-000000000001'),
  ('60000000-0000-4000-8000-000000000002')
on conflict (id) do nothing;

insert into public.trips (
  id, user_id, title, destination, start_date, end_date, summary,
  created_at, updated_at
) values
  (
    '70000000-0000-4000-8000-000000000001',
    '60000000-0000-4000-8000-000000000001',
    'Summary owner trip',
    'Penang',
    date '2026-08-01',
    date '2026-08-03',
    null,
    now(),
    now()
  ),
  (
    '70000000-0000-4000-8000-000000000002',
    '60000000-0000-4000-8000-000000000002',
    'Other user trip',
    'Kuala Lumpur',
    date '2026-09-01',
    date '2026-09-03',
    null,
    now(),
    now()
  );

set local role authenticated;
set local "request.jwt.claim.sub" = '60000000-0000-4000-8000-000000000001';

update public.trips
set summary = 'Saved by the owner.'
where id = '70000000-0000-4000-8000-000000000001';

do $$
begin
  if not exists (
    select 1
    from public.trips
    where id = '70000000-0000-4000-8000-000000000001'
      and summary = 'Saved by the owner.'
  ) then
    raise exception 'owner summary update did not persist';
  end if;
end;
$$;

update public.trips
set summary = 'Must not be written.'
where id = '70000000-0000-4000-8000-000000000002';

reset role;

do $$
begin
  if exists (
    select 1
    from public.trips
    where id = '70000000-0000-4000-8000-000000000002'
      and summary = 'Must not be written.'
  ) then
    raise exception 'RLS allowed updating another user summary';
  end if;
end;
$$;

rollback;
