-- Phase 6 + Phase 8 verification: tables, trigger, RLS policies, and the
-- shared is_active_user() hardening function.
select 'tables' as check_name, table_name as result
from information_schema.tables
where table_schema = 'public'
  and table_name in ('profiles', 'verification_codes')
union all
select 'trigger', tgname
from pg_trigger
where tgname = 'on_auth_user_created'
union all
select 'policy', policyname || ' on ' || tablename
from pg_policies
where schemaname = 'public'
  and tablename in ('profiles', 'verification_codes')
union all
select 'function', routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'is_active_user'
order by check_name, result;
