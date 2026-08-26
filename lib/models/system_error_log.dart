/// A record of an unhandled error caught anywhere in the app.
///
/// Owned by the Admin module (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md`, Sprint
/// 3, Phase 15). Entries are written from a single global hook in
/// `main.dart` (`runZonedGuarded` + `FlutterError.onError`) per Architecture
/// Decision 9 — not scattered `try/catch` blocks throughout the app. This is
/// a distinct table from [AdminAuditLog]: an audit log records deliberate
/// admin actions, this records unplanned failures.
class SystemErrorLog {
  final String logId;
  final String module;
  final ErrorSeverity severity;
  final String message;
  final String? stackTrace;
  final DateTime createdAt;

  const SystemErrorLog({
    required this.logId,
    required this.module,
    required this.severity,
    required this.message,
    this.stackTrace,
    required this.createdAt,
  });

  factory SystemErrorLog.fromJson(Map<String, dynamic> json) {
    return SystemErrorLog(
      logId: json['logId'] as String,
      module: json['module'] as String,
      severity: ErrorSeverity.values.firstWhere(
        (s) => s.name == json['severity'],
      ),
      message: json['message'] as String,
      stackTrace: json['stackTrace'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'logId': logId,
      'module': module,
      'severity': severity.name,
      'message': message,
      'stackTrace': stackTrace,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// How serious a [SystemErrorLog] entry is — matches common
/// logging-framework convention (Open Decision 8,
/// `ADMIN_MODULE_IMPLEMENTATION_PLAN.md` Sprint 3), giving PB-11's "filter
/// by severity" something meaningful to filter on.
enum ErrorSeverity { info, warning, error, fatal }
