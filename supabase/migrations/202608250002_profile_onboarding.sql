-- ============================================================================
-- User Management module — Profile Onboarding (post-registration).
--
-- Adds the fields collected by the first-login onboarding screen to the
-- existing `public.profiles` table (created in
-- 202608140001_user_management.sql). Additive only — no existing column is
-- altered or dropped.
-- ============================================================================

alter table public.profiles
  add column if not exists date_of_birth date,
  add column if not exists country text,
  add column if not exists travel_interests text[] not null default '{}',
  add column if not exists profile_completed boolean not null default false;

comment on column public.profiles.date_of_birth is
  'Optional. Collected on the onboarding screen; never in the future (app-level validation).';
comment on column public.profiles.country is
  'Optional. Free-text country name chosen from the app''s static country list.';
comment on column public.profiles.travel_interests is
  'Optional tags the user picked on onboarding (e.g. Scenery, History). Empty array = none chosen.';
comment on column public.profiles.profile_completed is
  'Drives first-login onboarding routing (AuthController.status). false = show '
  'the onboarding screen next login; set true either by finishing it or by '
  'explicitly skipping it — never left false indefinitely once the user has '
  'seen the screen once.';

-- Backfill: every profile that already exists as of this migration has, by
-- definition, already been using the app without onboarding — do not force
-- it retroactively on existing users. Only rows created AFTER this migration
-- (via the handle_new_user trigger, which does not set this column and so
-- gets the `false` default) are genuinely first-time and should see it.
update public.profiles set profile_completed = true where profile_completed = false;

-- No RLS changes needed: the existing profiles_select_own / profiles_update_own
-- policies (auth.uid() = user_id) already cover these new columns since they
-- are not column-scoped.
