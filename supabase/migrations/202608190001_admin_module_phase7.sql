-- ============================================================================
-- Admin module — Phase 7 real backend: is_admin_user() helper, admin
-- read-all access to profiles, and the admin_audit_log table.
--
-- Phase 7 of ADMIN_MODULE_IMPLEMENTATION_PLAN.md.
--
-- Cross-module note: this migration adds one new RLS policy to
-- public.profiles (owned by the User Management module) —
-- "profiles_select_admin" below. It is purely additive: a new SELECT
-- policy, OR'd with the existing "profiles_select_own" policy by Postgres
-- RLS semantics, so every existing non-admin caller's access is unchanged.
-- Flagged here and in docs/admin/PROGRESS.md per the plan's cross-module
-- coordination rule — team decision 2026-08-19 to proceed without a
-- separate review cycle, since the change is additive-only (see
-- docs/admin/PROGRESS.md Phase 7 entry).
-- ============================================================================


-- ============================================================================
-- 1. is_admin_user() — mirrors is_active_user() (User Management Phase 8,
--    202608160001_is_active_user.sql), same SECURITY DEFINER + pinned
--    search_path rationale: it needs to read auth.uid()'s own profile row
--    without recursing through the RLS policy it's used inside.
-- ============================================================================
create or replace function public.is_admin_user()
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles
    where profiles.user_id = auth.uid()
      and profiles.role = 'admin'
      and profiles.status = 'active'
  )
$$;

comment on function public.is_admin_user() is
  'True if the calling session belongs to an active profile with role = admin. Mirrors is_active_user() from the User Management module (202608160001_is_active_user.sql).';


-- ============================================================================
-- 2. profiles: admin read-all (PB-03 "Search and View User"). Additive
--    only — does not replace or narrow profiles_select_own /
--    profiles_update_own. Deliberately no admin UPDATE policy on profiles:
--    admin-initiated writes (suspend/reactivate) go through the
--    admin-suspend-user / admin-reactivate-user Edge Functions (service
--    role), which also need to call auth.admin.signOut() — a privilege no
--    RLS policy can grant, so a direct-write policy would be an incomplete
--    substitute for that path anyway.
-- ============================================================================
drop policy if exists "profiles_select_admin" on public.profiles;
create policy "profiles_select_admin"
  on public.profiles for select
  using (public.is_admin_user());


-- ============================================================================
-- 3. ADMIN_AUDIT_LOG (Architecture Decisions 5 and 6 of
--    ADMIN_MODULE_IMPLEMENTATION_PLAN.md — one generic table for every
--    admin-initiated action, target-type-generic since Sprint 2).
-- ============================================================================
create table if not exists public.admin_audit_log (
  log_id        uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references auth.users(id) on delete cascade,
  target_type   text not null check (target_type in ('user', 'issueReport')),
  target_id     text not null,
  action        text not null check (action in (
                  'suspend', 'reactivate',
                  'issueMarkInProgress', 'issueMarkResolved', 'issueReopen'
                )),
  reason        text,
  created_at    timestamptz not null default now()
);

comment on table public.admin_audit_log is
  'One generic audit table for every admin-initiated action (Architecture Decision 5/6). target_id is a plain text id, not an FK, because it can point at either auth.users(id) (target_type = user) or public.issue_reports(report_id) (target_type = issueReport, added Phase 14).';

create index if not exists admin_audit_log_target_idx
  on public.admin_audit_log (target_type, target_id, created_at desc);
create index if not exists admin_audit_log_created_at_idx
  on public.admin_audit_log (created_at desc);

alter table public.admin_audit_log enable row level security;

-- Insert-only from privileged contexts in practice — the
-- admin-suspend-user / admin-reactivate-user Edge Functions use the
-- service-role client, which bypasses RLS entirely. This INSERT policy is
-- defense in depth / documents intent for any future direct-client write
-- path, not the primary write mechanism.
drop policy if exists "admin_audit_log_insert_admin" on public.admin_audit_log;
create policy "admin_audit_log_insert_admin"
  on public.admin_audit_log for insert
  with check (public.is_admin_user() and admin_user_id = auth.uid());

drop policy if exists "admin_audit_log_select_admin" on public.admin_audit_log;
create policy "admin_audit_log_select_admin"
  on public.admin_audit_log for select
  using (public.is_admin_user());


-- ============================================================================
-- 4. ADMIN_ACCESS_ATTEMPT_LOG — rejected admin sign-in attempts (team
--    decision 2026-08-12, see AdminAccessAttemptLog's doc comment).
--    Deliberately NOT gated by is_admin_user() on insert: the whole point
--    is recording an attempt from someone who just failed that exact
--    check, so requiring it here would make every real attempt
--    unrecordable. Instead, the inserting caller may only record an
--    attempt about themselves (auth.uid() = attempted_user_id) — the
--    client (AdminAuthController) always calls this right after its own
--    role check fails, so it can only ever describe its own rejection.
-- ============================================================================
create table if not exists public.admin_access_attempt_log (
  log_id             uuid primary key default gen_random_uuid(),
  attempted_user_id  uuid not null references auth.users(id) on delete cascade,
  attempted_email    text not null,
  reason             text not null check (reason in (
                        'notAnAdmin', 'noProfileFound', 'adminAccountNotActive'
                      )),
  created_at         timestamptz not null default now()
);

comment on table public.admin_access_attempt_log is
  'Rejected admin sign-in attempts — a separate table from admin_audit_log because the attempter has no admin actor role yet (see AdminAccessAttemptLog doc comment).';

create index if not exists admin_access_attempt_log_created_at_idx
  on public.admin_access_attempt_log (created_at desc);
create index if not exists admin_access_attempt_log_user_idx
  on public.admin_access_attempt_log (attempted_user_id, created_at desc);

alter table public.admin_access_attempt_log enable row level security;

drop policy if exists "admin_access_attempt_log_insert_self" on public.admin_access_attempt_log;
create policy "admin_access_attempt_log_insert_self"
  on public.admin_access_attempt_log for insert
  with check (auth.uid() = attempted_user_id);

drop policy if exists "admin_access_attempt_log_select_admin" on public.admin_access_attempt_log;
create policy "admin_access_attempt_log_select_admin"
  on public.admin_access_attempt_log for select
  using (public.is_admin_user());
