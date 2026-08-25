\set ON_ERROR_STOP on

begin;

-- Current Supabase images prevent direct SQL deletion from storage.objects
-- unless this transaction-scoped test flag is enabled. No real object files
-- exist here; the flag only lets this SQL fixture exercise TripJournal's RLS.
set local storage.allow_delete_query = 'true';

insert into auth.users (id)
values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002')
on conflict (id) do nothing;

insert into public.trips (
  id,
  user_id,
  title,
  start_date,
  end_date,
  created_at,
  updated_at
) values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  '00000000-0000-0000-0000-000000000002',
  'Foreign trip',
  date '2026-10-01',
  date '2026-10-02',
  now(),
  now()
);

-- Seed invalid/foreign objects as the database owner so authenticated DELETE
-- policy behavior can be tested independently from INSERT policy behavior.
insert into storage.objects (bucket_id, name, owner_id)
values (
  'trip-covers',
  '00000000-0000-0000-0000-000000000001/not-a-uuid/malformed-delete.jpg',
  '00000000-0000-0000-0000-000000000001'
), (
  'trip-covers',
  '00000000-0000-0000-0000-000000000001/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/foreign-parent.jpg',
  '00000000-0000-0000-0000-000000000001'
), (
  'trip-covers',
  '00000000-0000-0000-0000-000000000002/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/cross-owner.jpg',
  '00000000-0000-0000-0000-000000000002'
), (
  'journal-photos',
  '00000000-0000-0000-0000-000000000001/cccccccc-cccc-4ccc-8ccc-cccccccccccc/orphan-delete.jpg',
  '00000000-0000-0000-0000-000000000001'
);

-- A cover is uploaded before its trip row is created by Task 6. The INSERT
-- policy must allow that canonical owner/trip path without weakening later
-- UPDATE or DELETE checks.
set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000001';

insert into storage.objects (bucket_id, name, owner_id)
values (
  'trip-covers',
  '00000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/pre-row.jpg',
  '00000000-0000-0000-0000-000000000001'
);

delete from storage.objects
where bucket_id = 'trip-covers'
  and name = '00000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/pre-row.jpg';

do $$
begin
  if exists (
    select 1 from storage.objects
    where bucket_id = 'trip-covers'
      and name = '00000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/pre-row.jpg'
  ) then
    raise exception 'pre-row cover rollback DELETE was blocked';
  end if;

  delete from storage.objects
  where bucket_id = 'trip-covers'
    and name = '00000000-0000-0000-0000-000000000001/not-a-uuid/malformed-delete.jpg';
  if found then raise exception 'malformed cover DELETE succeeded'; end if;

  delete from storage.objects
  where bucket_id = 'trip-covers'
    and name = '00000000-0000-0000-0000-000000000001/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/foreign-parent.jpg';
  if found then raise exception 'foreign-parent cover DELETE succeeded'; end if;

  delete from storage.objects
  where bucket_id = 'trip-covers'
    and name = '00000000-0000-0000-0000-000000000002/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/cross-owner.jpg';
  if found then raise exception 'cross-owner cover DELETE succeeded'; end if;

  delete from storage.objects
  where bucket_id = 'journal-photos'
    and name = '00000000-0000-0000-0000-000000000001/cccccccc-cccc-4ccc-8ccc-cccccccccccc/orphan-delete.jpg';
  if found then raise exception 'orphan journal-photo DELETE succeeded'; end if;
end;
$$;

do $$
begin
  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values (
      'trip-covers',
      '99999999-9999-4999-8999-999999999999/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/foreign.jpg',
      '00000000-0000-0000-0000-000000000001'
    );
    raise exception 'expected foreign owner INSERT to fail';
  exception
    when insufficient_privilege then null;
  end;

  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values (
      'trip-covers',
      '00000000-0000-0000-0000-000000000001/not-a-uuid/malformed.jpg',
      '00000000-0000-0000-0000-000000000001'
    );
    raise exception 'expected malformed trip path INSERT to fail';
  exception
    when insufficient_privilege then null;
  end;

  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values (
      'trip-covers',
      'bare-file.jpg',
      '00000000-0000-0000-0000-000000000001'
    );
    raise exception 'expected short path INSERT to fail';
  exception
    when insufficient_privilege then null;
  end;

  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values (
      'trip-covers',
      '00000000-0000-0000-0000-000000000001/AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA/noncanonical.jpg',
      '00000000-0000-0000-0000-000000000001'
    );
    raise exception 'expected noncanonical trip UUID INSERT to fail';
  exception
    when insufficient_privilege then null;
  end;

  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values (
      'journal-photos',
      '00000000-0000-0000-0000-000000000001/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/orphan.jpg',
      '00000000-0000-0000-0000-000000000001'
    );
    raise exception 'expected journal photo without a parent trip to fail';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;

reset role;

insert into public.trips (
  id,
  user_id,
  title,
  cover_photo_url,
  start_date,
  end_date,
  created_at,
  updated_at
) values (
  '11111111-1111-4111-8111-111111111111',
  '00000000-0000-0000-0000-000000000001',
  'Expired trip',
  'http://127.0.0.1:54321/storage/v1/object/public/trip-covers/00000000-0000-0000-0000-000000000001/11111111-1111-4111-8111-111111111111/cover.jpg',
  date '2026-07-01',
  date '2026-07-02',
  now(),
  now()
), (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '00000000-0000-0000-0000-000000000001',
  'Mutable trip',
  null,
  date '2026-09-01',
  date '2026-09-02',
  now(),
  now()
);

insert into public.journal_entries (
  id,
  trip_id,
  user_id,
  title,
  photo_urls,
  entry_date
) values (
  '33333333-3333-4333-8333-333333333333',
  '11111111-1111-4111-8111-111111111111',
  '00000000-0000-0000-0000-000000000001',
  'Claim snapshot entry',
  array[
    'http://127.0.0.1:54321/storage/v1/object/public/journal-photos/00000000-0000-0000-0000-000000000001/11111111-1111-4111-8111-111111111111/photo.jpg'
  ],
  date '2026-07-01'
);

set local role authenticated;

-- Journal ownership must be derived from the parent trip, not merely from a
-- client-supplied journal_entries.user_id value.
-- Seed the owned row as the database owner: app writes now go through the
-- atomic bundle RPC, so authenticated callers deliberately lack direct INSERT.
reset role;
insert into public.journal_entries (
  id,
  trip_id,
  user_id,
  title,
  photo_urls,
  entry_date
) values (
  '44444444-4444-4444-8444-444444444444',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '00000000-0000-0000-0000-000000000001',
  'Owned entry',
  '{}',
  date '2026-09-01'
);

set local role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000001';

do $$
begin
  begin
    insert into public.journal_entries (
      id,
      trip_id,
      user_id,
      title,
      photo_urls,
      entry_date
    ) values (
      '55555555-5555-4555-8555-555555555555',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      '00000000-0000-0000-0000-000000000001',
      'Cross-owner entry',
      '{}',
      date '2026-10-01'
    );
    raise exception 'cross-owner journal INSERT succeeded';
  exception
    when foreign_key_violation or insufficient_privilege then null;
  end;

  begin
    update public.journal_entries
    set trip_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
    where id = '44444444-4444-4444-8444-444444444444';
    raise exception 'cross-owner journal reassignment succeeded';
  exception
    when foreign_key_violation or insufficient_privilege then null;
  end;
end;
$$;

-- An existing, unclaimed parent still allows canonical post-row object
-- mutations. This guards the normal cover replacement and journal upload
-- flows while journal photos without a parent remain forbidden.
insert into storage.objects (bucket_id, name, owner_id)
values (
  'trip-covers',
  '00000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/post-row.jpg',
  '00000000-0000-0000-0000-000000000001'
), (
  'journal-photos',
  '00000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/post-row.jpg',
  '00000000-0000-0000-0000-000000000001'
);
update storage.objects
set name = '00000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/post-row-renamed.jpg'
where bucket_id = 'trip-covers'
  and name = '00000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/post-row.jpg';
update storage.objects
set name = '00000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/post-row-renamed.jpg'
where bucket_id = 'journal-photos'
  and name = '00000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/post-row.jpg';
delete from storage.objects
where bucket_id = 'trip-covers'
  and name = '00000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/post-row-renamed.jpg';
delete from storage.objects
where bucket_id = 'journal-photos'
  and name = '00000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/post-row-renamed.jpg';

select public.move_trip_to_trash(
  '11111111-1111-4111-8111-111111111111'
);

do $$
begin
  begin
    update public.trips
    set deleted_at = timestamptz '2020-01-01 00:00:00+00'
    where id = '11111111-1111-4111-8111-111111111111';
    raise exception 'expected lifecycle backdate to fail';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;

reset role;

update public.trips
set deleted_at = timestamptz '2026-08-01 00:00:00+00'
where id = '11111111-1111-4111-8111-111111111111';

insert into storage.objects (bucket_id, name, owner_id)
values (
  'trip-covers',
  '00000000-0000-0000-0000-000000000001/11111111-1111-4111-8111-111111111111/cover.jpg',
  '00000000-0000-0000-0000-000000000001'
), (
  'journal-photos',
  '00000000-0000-0000-0000-000000000001/11111111-1111-4111-8111-111111111111/photo.jpg',
  '00000000-0000-0000-0000-000000000001'
);

set local role service_role;
create temporary table first_claim as
select *
from public.claim_expired_trip_purges(
  timestamptz '2026-08-05 02:15:00+00',
  100
);

do $$
declare
  v_count integer;
  v_claim first_claim%rowtype;
begin
  select count(*) into v_count from first_claim;
  if v_count <> 1 then
    raise exception 'expected one claim, got %', v_count;
  end if;
  select * into strict v_claim from first_claim;
  if v_claim.owner_id <> '00000000-0000-0000-0000-000000000001'::uuid then
    raise exception 'claim owner mismatch';
  end if;
  if cardinality(v_claim.journal_photo_urls) <> 1 then
    raise exception 'journal snapshot mismatch';
  end if;

  select count(*) into v_count
  from public.claim_expired_trip_purges(
    timestamptz '2026-08-05 02:15:00+00',
    100
  );
  if v_count <> 0 then
    raise exception 'active claim was handed to a second worker';
  end if;
end;
$$;

set local role authenticated;

do $$
begin
  begin
    perform public.restore_trip(
      '11111111-1111-4111-8111-111111111111',
      'Restore blocked',
      'Blocked destination',
      null,
      date '2026-07-01',
      date '2026-07-02',
      null
    );
    raise exception 'expected restore during purge to fail';
  exception
    when raise_exception then
      if sqlerrm <> 'trip_purge_in_progress' then raise; end if;
  end;

  begin
    perform public.move_trip_to_trash(
      '11111111-1111-4111-8111-111111111111'
    );
    raise exception 'expected re-trash during purge to fail';
  exception
    when raise_exception then
      if sqlerrm <> 'trip_purge_in_progress' then raise; end if;
  end;

  begin
    update public.trips
    set cover_photo_url = null
    where id = '11111111-1111-4111-8111-111111111111';
    raise exception 'expected claimed trip edit to fail';
  exception
    when raise_exception or insufficient_privilege then null;
  end;

  begin
    update public.journal_entries
    set photo_urls = '{}'
    where id = '33333333-3333-4333-8333-333333333333';
    raise exception 'expected claimed journal edit to fail';
  exception
    when raise_exception or insufficient_privilege then null;
  end;

  begin
    insert into public.journal_entries (
      trip_id,
      user_id,
      title,
      photo_urls,
      entry_date
    ) values (
      '11111111-1111-4111-8111-111111111111',
      '00000000-0000-0000-0000-000000000001',
      'Late entry',
      '{}',
      date '2026-07-01'
    );
    raise exception 'expected claimed journal insert to fail';
  exception
    when raise_exception or insufficient_privilege then null;
  end;

  begin
    delete from storage.objects
    where name = '00000000-0000-0000-0000-000000000001/11111111-1111-4111-8111-111111111111/cover.jpg';
    if found then
      raise exception 'claimed cover delete unexpectedly succeeded';
    end if;
    raise exception 'expected claimed cover delete to fail';
  exception
    when raise_exception or insufficient_privilege then null;
  end;
end;
$$;

reset role;

-- A failed cleanup leaves the durable snapshot. Expiring only the lease must
-- rotate the worker token without changing snapshot contents.
update public.trip_purge_claims
set lease_expires_at = now() - interval '1 second';

set local role service_role;
create temporary table retry_claim as
select *
from public.claim_expired_trip_purges(
  timestamptz '2026-08-05 02:15:00+00',
  100
);

do $$
declare
  v_first first_claim%rowtype;
  v_retry retry_claim%rowtype;
begin
  select * into strict v_first from first_claim;
  select * into strict v_retry from retry_claim;

  if v_first.claim_token = v_retry.claim_token then
    raise exception 'stale retry did not rotate token';
  end if;
  if v_first.owner_id <> v_retry.owner_id
    or v_first.cover_photo_url is distinct from v_retry.cover_photo_url
    or v_first.journal_photo_urls is distinct from v_retry.journal_photo_urls
  then
    raise exception 'durable retry changed immutable snapshot';
  end if;

  begin
    perform public.complete_trip_purge(
      v_first.trip_id,
      v_first.claim_token
    );
    raise exception 'expected stale token completion to fail';
  exception
    when raise_exception then
      if sqlerrm <> 'purge_claim_mismatch' then raise; end if;
  end;

  if not public.complete_trip_purge(v_retry.trip_id, v_retry.claim_token) then
    raise exception 'current token did not complete purge';
  end if;
end;
$$;

reset role;

do $$
begin
  if exists (
    select 1 from public.trips
    where id = '11111111-1111-4111-8111-111111111111'
  ) then
    raise exception 'purged trip still exists';
  end if;
  if exists (
    select 1 from public.trip_purge_claims
    where trip_id = '11111111-1111-4111-8111-111111111111'
  ) then
    raise exception 'completed claim still exists';
  end if;
end;
$$;

rollback;
