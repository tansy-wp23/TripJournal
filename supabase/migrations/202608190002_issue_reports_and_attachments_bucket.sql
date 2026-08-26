-- ============================================================================
-- Admin module — Phase 14 real backend: issue_reports table and its
-- storage bucket for attachments.
--
-- Phase 14 of ADMIN_MODULE_IMPLEMENTATION_PLAN.md (Sprint 2).
-- ============================================================================

create table if not exists public.issue_reports (
  report_id            uuid primary key default gen_random_uuid(),
  submitted_by_user_id uuid not null references auth.users(id) on delete cascade,
  page                 text not null,
  description          text not null,
  screenshot_url       text,
  status               text not null default 'open'
                          check (status in ('open', 'inProgress', 'resolved')),
  admin_remarks        text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

comment on table public.issue_reports is
  'User-submitted bug/problem reports (PB-06 through PB-09). submitted_by_user_id is whoever filed it; status/admin_remarks are admin-owned fields, written only via IssueReportRepository.updateStatus.';

-- Reuses handle_updated_at() from the User Management module's
-- 202608140001_user_management.sql (already applied to public.profiles).
drop trigger if exists issue_reports_set_updated_at on public.issue_reports;
create trigger issue_reports_set_updated_at
  before update on public.issue_reports
  for each row execute function public.handle_updated_at();

create index if not exists issue_reports_status_idx
  on public.issue_reports (status, created_at desc);
create index if not exists issue_reports_submitted_by_idx
  on public.issue_reports (submitted_by_user_id, created_at desc);

alter table public.issue_reports enable row level security;

-- Any signed-in user can submit a report about their own experience
-- (Architecture Decision 7) and read back their own reports.
drop policy if exists "issue_reports_insert_own" on public.issue_reports;
create policy "issue_reports_insert_own"
  on public.issue_reports for insert
  with check (auth.uid() = submitted_by_user_id);

drop policy if exists "issue_reports_select_own" on public.issue_reports;
create policy "issue_reports_select_own"
  on public.issue_reports for select
  using (auth.uid() = submitted_by_user_id);

-- Admins can read and update (status/remarks) every report. No admin
-- DELETE policy — reports aren't deletable through this module's scope.
drop policy if exists "issue_reports_select_admin" on public.issue_reports;
create policy "issue_reports_select_admin"
  on public.issue_reports for select
  using (public.is_admin_user());

drop policy if exists "issue_reports_update_admin" on public.issue_reports;
create policy "issue_reports_update_admin"
  on public.issue_reports for update
  using (public.is_admin_user())
  with check (public.is_admin_user());


-- ============================================================================
-- Storage bucket for attachments (Sprint 2 Open Decision 5 — image_picker
-- gallery attachment, not automatic screen-capture). Mirrors
-- profile-avatars' 202608150001_profile_avatars_bucket.sql setup, except
-- admins additionally need read access to review any user's attachment
-- (unlike profile-avatars, which nobody but the owner needs to read).
-- ============================================================================
insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
) values (
  'issue-report-attachments',
  'issue-report-attachments',
  true,
  33554432,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "issue_report_attachments_insert_own" on storage.objects;
create policy "issue_report_attachments_insert_own" on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'issue-report-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "issue_report_attachments_select_own_or_admin" on storage.objects;
create policy "issue_report_attachments_select_own_or_admin" on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'issue-report-attachments'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_admin_user()
    )
  );

drop policy if exists "issue_report_attachments_delete_own" on storage.objects;
create policy "issue_report_attachments_delete_own" on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'issue-report-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
