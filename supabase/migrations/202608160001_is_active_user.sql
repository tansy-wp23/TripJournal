-- ============================================================================
-- User Management module — Phase 8 hardening: shared is_active_user() check.
--
-- Architecture Decision 7 says a deactivated/suspended user still holds a valid
-- Supabase session/JWT (Supabase Auth doesn't know about Profile.status). This
-- function gives every OTHER module's RLS policies a single, shared predicate
-- to exclude those users from reading/writing their data — complementing this
-- module's client-side gate in AuthController.status (which fetches the profile
-- to read `status` and route deactivated/suspended sign-ins).
--
-- See docs/user-management/PROGRESS.md (Phase 8) and
-- lib/features/auth/README.md ("Cross-module: excluding deactivated users").
-- ============================================================================

-- SECURITY DEFINER + read on public.profiles: bypasses the caller's own
-- profile-row RLS so the existence/status check is not recursive and a
-- deactivated user can still be *identified* as such (their row is readable to
-- this function even though the select policy below would otherwise... note
-- the select policy is intentionally NOT gated — see the note below).
-- `stable` because auth.uid() is session-stable and the profile status is not
-- expected to change mid-request. search_path is pinned to prevent
-- search-path hijacking of a SECURITY DEFINER function.
create or replace function public.is_active_user()
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
      and profiles.status = 'active'
  )
$$;

-- Apply the gate to this module's own profiles UPDATE path as defense in depth:
-- only a user whose profile is `active` may mutate it (reactivation is performed
-- server-side by account-reactivate-confirm, never through a client update, so
-- gating UPDATE here does not break the reactivation flow).
--
-- IMPORTANT (deviation from the Phase 8 plan wording): the profiles SELECT
-- policy is deliberately NOT changed to require is_active_user(). The
-- AuthController.signInWithGoogle() flow fetches the profile immediately after
-- sign-in to branch on status (PB-06: deactivated → reactivation screen; Admin
-- Phase 5: suspended → blocked). If SELECT were gated by is_active_user(), a
-- deactivated/suspended user's getProfile() would return null, collapsing both
-- cases onto AuthStatus.signedOut and breaking the gate. So SELECT stays as
-- auth.uid() = user_id; only UPDATE is hardened here.
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = user_id and is_active_user())
  with check (auth.uid() = user_id and is_active_user());
