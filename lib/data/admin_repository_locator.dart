import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_access_attempt_log_repository.dart';
import 'admin_account_actions_repository.dart';
import 'admin_audit_log_repository.dart';
import 'admin_dashboard_repository.dart';
import 'admin_user_directory_repository.dart';
import 'ai_request_log_repository.dart';
import 'auth_repository.dart';
import 'issue_report_repository.dart';
import 'supabase_admin_access_attempt_log_repository.dart';
import 'supabase_admin_account_actions_repository.dart';
import 'supabase_admin_audit_log_repository.dart';
import 'supabase_admin_dashboard_repository.dart';
import 'supabase_admin_user_directory_repository.dart';
import 'supabase_ai_request_log_repository.dart';
import 'supabase_issue_report_repository.dart';
import 'supabase_system_error_log_repository.dart';
import 'system_error_log_repository.dart';
import 'user_management_repository_locator.dart' as user_management;

/// The one place the app resolves its admin repositories from — mirrors
/// `user_management_repository_locator.dart`.
///
/// Phase 7/14/21 (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md`): all repositories
/// are wired to their real Supabase implementations. The mock
/// implementations remain in the codebase for tests (`AdminTestHarness`,
/// `test/support/admin_test_harness.dart`) and offline/dev-mode use, but
/// are no longer wired by default.
///
/// Lazy getters (not top-level finals) so importing this file in a test
/// never touches `Supabase.instance` — that throws unless
/// `Supabase.initialize` has run, which widget tests don't do — mirrors
/// `user_management_repository_locator.dart`'s own rationale.
SupabaseClient get _supabase => Supabase.instance.client;

/// Reuses the traveler-facing `authRepository` rather than a separate
/// instance — Architecture Decision 2 (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md`):
/// no parallel admin-identity table, administrators sign in through the
/// same `AuthRepository`/`ProfileRepository` infrastructure. The mock
/// locator used a *separate* `MockAuthRepository` instance only because a
/// mock can simulate exactly one signed-in persona per instance; the real
/// Supabase Auth backend is one shared service for both flows, so this
/// collapses back to a single instance (see `docs/admin/PROGRESS.md`
/// Phase 2 and Phase 7).
AuthRepository get adminAuthRepository => user_management.authRepository;

AdminUserDirectoryRepository get adminUserDirectoryRepository =>
    SupabaseAdminUserDirectoryRepository(_supabase);

AdminDashboardRepository get adminDashboardRepository =>
    SupabaseAdminDashboardRepository(_supabase);

AdminAuditLogRepository get adminAuditLogRepository =>
    SupabaseAdminAuditLogRepository(_supabase);

AdminAccountActionsRepository get adminAccountActionsRepository =>
    SupabaseAdminAccountActionsRepository(_supabase);

/// Records rejected admin sign-in attempts (`docs/admin/PROGRESS.md`,
/// post-Phase-3 addition) — a separate table from [adminAuditLogRepository],
/// see [AdminAccessAttemptLog]'s doc comment for why.
AdminAccessAttemptLogRepository get adminAccessAttemptLogRepository =>
    SupabaseAdminAccessAttemptLogRepository(_supabase);

/// PB-06 (submit) through PB-09 (update status) — Sprint 2.
IssueReportRepository get issueReportRepository =>
    SupabaseIssueReportRepository(_supabase);

/// PB-11 (Monitor System Error Logs) — Sprint 3. Real backend since Phase
/// 21 — a lazy getter now, same as every other repository in this file
/// (the mock-only, top-level-final wiring from Phases 16–20 is gone; the
/// mock implementation itself is untouched, still used by
/// `AdminTestHarness` and offline/dev-mode use).
SystemErrorLogRepository get systemErrorLogRepository =>
    SupabaseSystemErrorLogRepository(_supabase);

/// PB-12 (Monitor AI Processing Requests) + PB-13 (Monitor Failed AI
/// Requests) — Sprint 3. Real backend since Phase 21, same reasoning as
/// [systemErrorLogRepository] above.
AiRequestLogRepository get aiRequestLogRepository =>
    SupabaseAiRequestLogRepository(_supabase);
