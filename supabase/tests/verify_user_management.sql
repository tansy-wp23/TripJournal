-- Phase 6 verification: tables, trigger, and RLS policies exist.
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
order by check_name, result;