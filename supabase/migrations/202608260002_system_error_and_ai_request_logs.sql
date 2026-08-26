-- ============================================================================
-- Admin module — Phase 21 real backend: system_error_logs and
-- ai_request_logs tables (Sprint 3 — PB-11 through PB-13).
--
-- Phase 21 of ADMIN_MODULE_IMPLEMENTATION_PLAN.md. Write path: direct
-- RLS-scoped client inserts, per the pattern Phase 7 established for
-- everything that doesn't need `auth.admin.signOut()` or another
-- service-role-only operation (that's what the two suspend/reactivate Edge
-- Functions are for — neither of these tables needs one).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SYSTEM_ERROR_LOGS — the global error hook (`error_reporting.dart`,
--    Phase 17). No user_id column: an uncaught error isn't "about" a
--    specific user the way an audit-log entry is about an admin action, and
--    `main.dart`'s hook has no reliable way to attribute one anyway (it can
--    fire before sign-in resolves, e.g. during the splash/auth-check
--    screens). Insert is gated on `to authenticated` only — any signed-in
--    session, no ownership check, since there's no owner column to check
--    against. Known, accepted gap: an error that occurs while nobody is
--    signed in yet has no session to insert under and is silently dropped
--    from the log (matches the fire-and-forget/best-effort design already
--    used throughout this hook — a logging failure must never surface as a
--    bigger problem than the error it was trying to record).
-- ----------------------------------------------------------------------------
create table if not exists public.system_error_logs (
  log_id      uuid primary key default gen_random_uuid(),
  module      text not null,
  severity    text not null check (severity in ('info', 'warning', 'error', 'fatal')),
  message     text not null,
  stack_trace text,
  created_at  timestamptz not null default now()
);

comment on table public.system_error_logs is
  'Errors caught by the global hook in main.dart (Architecture Decision 9, docs/admin/PROGRESS.md Phase 17/21). No user_id: an uncaught error is not attributed to a specific user.';

create index if not exists system_error_logs_created_at_idx
  on public.system_error_logs (created_at desc);
create index if not exists system_error_logs_module_severity_idx
  on public.system_error_logs (module, severity, created_at desc);

alter table public.system_error_logs enable row level security;

drop policy if exists "system_error_logs_insert_authenticated" on public.system_error_logs;
create policy "system_error_logs_insert_authenticated"
  on public.system_error_logs for insert
  to authenticated
  with check (true);

drop policy if exists "system_error_logs_select_admin" on public.system_error_logs;
create policy "system_error_logs_select_admin"
  on public.system_error_logs for select
  using (public.is_admin_user());

-- ----------------------------------------------------------------------------
-- 2. AI_REQUEST_LOGS — the three AI-locator logging decorators
--    (`ai_request_logging.dart`, Phase 18). Unlike system_error_logs, this
--    DOES have a user_id — but it's `text`, not `uuid references
--    auth.users(id)`: the Dart-side resolver
--    (`Supabase.instance.client.auth.currentUser?.id`) falls back to the
--    literal string `'unknown'` when no session is resolved (best-effort,
--    mirrors system_error_logs' same gap), which isn't a valid auth.users
--    id and would violate a real foreign key. Insert requires
--    `auth.uid()::text = user_id` (mirrors admin_access_attempt_log's
--    "insert about yourself only" policy, 202608190001) — a session
--    inserting the 'unknown' placeholder, or someone else's real id, is
--    rejected; that entry is simply dropped from the real log rather than
--    persisted with an unverifiable owner, same fire-and-forget philosophy
--    as system_error_logs.
-- ----------------------------------------------------------------------------
create table if not exists public.ai_request_logs (
  log_id            uuid primary key default gen_random_uuid(),
  user_id           text not null,
  request_type      text not null check (request_type in ('dailyAdvice', 'foodDetection', 'tripSummary')),
  status            text not null check (status in ('succeeded', 'failed')),
  execution_time_ms integer not null,
  error_message     text,
  created_at        timestamptz not null default now()
);

comment on table public.ai_request_logs is
  'One row per call through a logged*Service wrapper (Architecture Decision 9, docs/admin/PROGRESS.md Phase 18/21). user_id is text, not a auth.users FK — see this migration''s own comment for why.';

create index if not exists ai_request_logs_created_at_idx
  on public.ai_request_logs (created_at desc);
create index if not exists ai_request_logs_status_idx
  on public.ai_request_logs (status, created_at desc);

alter table public.ai_request_logs enable row level security;

drop policy if exists "ai_request_logs_insert_own" on public.ai_request_logs;
create policy "ai_request_logs_insert_own"
  on public.ai_request_logs for insert
  with check (auth.uid()::text = user_id);

drop policy if exists "ai_request_logs_select_admin" on public.ai_request_logs;
create policy "ai_request_logs_select_admin"
  on public.ai_request_logs for select
  using (public.is_admin_user());
