/// A user-submitted report of a problem with the app — PB-06 (submit,
/// added to this module's scope 2026-08-12, `ADMIN_MODULE_IMPLEMENTATION_PLAN.md`
/// Sprint 2 Open Decision 4) through PB-09 (admin resolves it).
///
/// Owned by the Admin module even though it's created from non-admin
/// screens (`ReportIssueButton` gets placed on Journal/Trip module
/// screens) — the model/repository live here because the whole point of
/// the feature is admin review; see Sprint 2's Architecture Decision 7.
class IssueReport {
  final String reportId;
  final String submittedByUserId;

  /// The screen/module the report was filed from (e.g. `'TripViewScreen'`)
  /// — passed in by the caller placing `ReportIssueButton`, not inferred
  /// automatically; this codebase has no route-introspection convention to
  /// derive it from.
  final String page;
  final String description;

  /// A photo attached by the user, per Sprint 2 Open Decision 5 — an
  /// existing gallery/camera photo via `image_picker`, not a literal
  /// automatic screen-capture (deferred to the real-backend phase).
  final String? screenshotUrl;
  final IssueReportStatus status;

  /// Set by an admin via `IssueReportRepository.updateStatus` — optional,
  /// per Sprint 2 Open Decision 6.
  final String? adminRemarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IssueReport({
    required this.reportId,
    required this.submittedByUserId,
    required this.page,
    required this.description,
    this.screenshotUrl,
    this.status = IssueReportStatus.open,
    this.adminRemarks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IssueReport.fromJson(Map<String, dynamic> json) {
    return IssueReport(
      reportId: json['reportId'] as String,
      submittedByUserId: json['submittedByUserId'] as String,
      page: json['page'] as String,
      description: json['description'] as String,
      screenshotUrl: json['screenshotUrl'] as String?,
      status: IssueReportStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => IssueReportStatus.open,
      ),
      adminRemarks: json['adminRemarks'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reportId': reportId,
      'submittedByUserId': submittedByUserId,
      'page': page,
      'description': description,
      'screenshotUrl': screenshotUrl,
      'status': status.name,
      'adminRemarks': adminRemarks,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  IssueReport copyWith({
    String? reportId,
    String? submittedByUserId,
    String? page,
    String? description,
    String? screenshotUrl,
    bool clearScreenshotUrl = false,
    IssueReportStatus? status,
    String? adminRemarks,
    bool clearAdminRemarks = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IssueReport(
      reportId: reportId ?? this.reportId,
      submittedByUserId: submittedByUserId ?? this.submittedByUserId,
      page: page ?? this.page,
      description: description ?? this.description,
      screenshotUrl:
          clearScreenshotUrl ? null : (screenshotUrl ?? this.screenshotUrl),
      status: status ?? this.status,
      adminRemarks:
          clearAdminRemarks ? null : (adminRemarks ?? this.adminRemarks),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// PB-09's three states, per the backlog wording exactly.
enum IssueReportStatus { open, inProgress, resolved }
