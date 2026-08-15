-- ============================================================================
-- User Management module — Profile + VerificationCode tables, handle_new_user
-- trigger, and RLS policies.
--
-- Phase 6 of USER_MANAGEMENT_IMPLEMENTATION_PLAN.md
--
-- Architecture decisions this encodes (see plan "Architecture Decisions"):
--   * No LinkedProvider / Session tables — superseded by Supabase Auth.
--   * Profile.userID is a 1:1 FK to auth.users.id.
--   * VerificationCode is fully hand-built (Supabase Auth has no OTP concept).
--   * Deactivated accounts are gated client-side (Architecture Decision 7);
--     Phase 8 adds the shared is_active_user() check for other modules' RLS.
-- ============================================================================


-- ============================================================================
-- 1. PROFILE
-- ============================================================================
create table if not exists public.profiles (
  user_id         uuid primary key references auth.users(id) on delete cascade,
  email           text not null,
  display_name    text not null default '',
  avatar_url      text,
  role            text not null default 'user'
                    check (role in ('user', 'admin')),
  status          text not null default 'active'
                    check (status in ('active', 'deactivated', 'suspended')),
  deactivated_at  timestamptz,
  last_login_at   timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.profiles is
  'App-specific profile fields that Supabase Auth knows nothing about. user_id is a 1:1 FK to auth.users.id.';
comment on column public.profiles.status is
  'active | deactivated | suspended. Deactivated = user closed it themselves (self-service reactivation). Suspended = admin action (Admin module).';

-- Keep updated_at fresh on every row change.
create or replace function public.handle_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.handle_updated_at();


-- ============================================================================
-- 2. VERIFICATION_CODE
-- ============================================================================
create table if not exists public.verification_codes (
  code_id       uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  code_hash     text not null,          -- sha256 hex of the plaintext code; never store plaintext
  purpose       text not null check (purpose in ('deactivation', 'reactivation')),
  attempt_count integer not null default 0,
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null,
  used_at       timestamptz
);

comment on table public.verification_codes is
  'One-time codes emailed to confirm an action (deactivation/reactivation). Only the hash is stored.';

create index if not exists verification_codes_user_purpose_idx
  on public.verification_codes (user_id, purpose, created_at desc);


-- ============================================================================
-- 3. HANDLE_NEW_USER TRIGGER
-- ============================================================================
-- Server-side source of truth for account creation (PB-03). When a user signs
-- up via Supabase Auth, auto-create their Profile row with status = active.
-- The client-side createProfileIfMissing() in the Flutter app is a defensive
-- fallback, not the primary mechanism.
-- SECURITY DEFINER is required here: this trigger fires on auth.users insert
-- as the supabase_auth_admin role, which has no table-level grants on
-- public.profiles. Running as the function owner (postgres) instead lets the
-- insert succeed. search_path is pinned to prevent search-path hijacking of
-- a SECURITY DEFINER function. (handle_updated_at above stays INVOKER on
-- purpose — it fires on updates the authenticated user is already permitted
-- to make via RLS, so no privilege elevation is needed there.)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (user_id, email, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name',
             new.raw_user_meta_data ->> 'name',
             ''),
    coalesce(new.raw_user_meta_data ->> 'avatar_url',
             new.raw_user_meta_data ->> 'picture')
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ============================================================================
-- 4. ROW LEVEL SECURITY
-- ============================================================================
alter table public.profiles enable row level security;
alter table public.verification_codes enable row level security;

-- Profiles: a user can select/update only their own row; no direct
-- insert/delete from clients (the trigger owns inserts; deletes are
-- cascade-only from auth.users).
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = user_id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- VerificationCode: no direct client access at all. Only privileged
-- SECURITY DEFINER functions / Edge Functions touch this table.
drop policy if exists "verification_codes_no_client_access" on public.verification_codes;
create policy "verification_codes_no_client_access"
  on public.verification_codes for all
  using (false)
  with check (false);