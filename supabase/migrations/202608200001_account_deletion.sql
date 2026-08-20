-- ============================================================================
-- Phase 9 — Account Deletion (Permanent)
--
-- Adds 'deletion' to the verification_codes purpose check constraint so the
-- existing VerificationCode infrastructure can be reused for the permanent
-- account-deletion flow (same send/resend/validate mechanism as deactivation
-- and reactivation).
--
-- The auth.users row deletion cascades to profiles and verification_codes
-- automatically (both already have `on delete cascade` FKs from the Phase 6
-- migration), so no separate cleanup is needed for this module's own tables.
-- ============================================================================

alter table public.verification_codes
  drop constraint if exists verification_codes_purpose_check;

alter table public.verification_codes
  add constraint verification_codes_purpose_check
  check (purpose in ('deactivation', 'reactivation', 'deletion'));