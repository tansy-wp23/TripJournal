\set ON_ERROR_STOP on

begin;

insert into auth.users (id)
values
  ('60000000-0000-4000-8000-000000000001'),
  ('60000000-0000-4000-8000-000000000002')
on conflict (id) do nothing;

set local role authenticated;
set local "request.jwt.claim.sub" = '60000000-0000-4000-8000-000000000001';

do $$
declare
  v_result jsonb;
  v_index integer;
begin
  for v_index in 1..20 loop
    v_result := public.consume_places_rate_limit();
    if not (v_result ->> 'allowed')::boolean then
      raise exception 'request % was limited before the configured maximum', v_index;
    end if;
  end loop;

  v_result := public.consume_places_rate_limit();
  if (v_result ->> 'allowed')::boolean then
    raise exception 'request 21 unexpectedly passed';
  end if;
  if (v_result ->> 'remaining')::integer <> 0 then
    raise exception 'limited response did not report zero remaining';
  end if;
  if (v_result ->> 'retry_after_seconds')::integer not between 1 and 60 then
    raise exception 'limited response returned an invalid retry delay';
  end if;
end;
$$;

-- A second user receives an independent window.
set local "request.jwt.claim.sub" = '60000000-0000-4000-8000-000000000002';
do $$
declare
  v_result jsonb;
begin
  v_result := public.consume_places_rate_limit();
  if not (v_result ->> 'allowed')::boolean
    or (v_result ->> 'remaining')::integer <> 19
  then
    raise exception 'rate limit was not isolated per user';
  end if;
end;
$$;

-- Callers can consume a window only through the RPC, not rewrite counters.
do $$
begin
  begin
    update public.places_rate_limits set request_count = 0;
    raise exception 'authenticated user unexpectedly changed rate limit state';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;

reset role;
update public.places_rate_limits
set window_started_at = clock_timestamp() - interval '61 seconds'
where user_id = '60000000-0000-4000-8000-000000000001';

set local role authenticated;
set local "request.jwt.claim.sub" = '60000000-0000-4000-8000-000000000001';
do $$
declare
  v_result jsonb;
begin
  v_result := public.consume_places_rate_limit();
  if not (v_result ->> 'allowed')::boolean
    or (v_result ->> 'remaining')::integer <> 19
  then
    raise exception 'expired rate limit window did not reset';
  end if;
end;
$$;

reset role;
rollback;
