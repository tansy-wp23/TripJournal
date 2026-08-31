import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../gemini_reachability.dart';
import '../supabase_connectivity.dart';

/// PB-14 (System Health Dashboard). Phase 19 built the mock-era version of
/// this screen (three placeholder-heavy indicators); Phase 21 replaces two
/// of them with real checks now that Phase 7 gives this module a live
/// Supabase backend to actually ping. See [checkSupabaseConnectivity] and
/// [checkGeminiReachability] for what each check does and doesn't cover.
///
/// **Two indicators, not three** — Phase 19 originally separated "Database
/// Connectivity" from "Backend API" (Open Decision 7's own framing), but
/// this app has no backend distinct from Supabase itself to test
/// separately; see [checkSupabaseConnectivity]'s doc comment.
///
/// **Supabase connectivity checks automatically on open** (a cheap,
/// read-only query) — but **Gemini reachability is on-demand only**, via a
/// "Test Connection" button, never run automatically. This app has already
/// hit Gemini free-tier quota exhaustion twice in production use (see
/// `gemini_model.dart`'s doc comment) — spending a real API call every time
/// an admin opens this screen, just to show a status chip, would work
/// against that lesson rather than respect it.
class SystemHealthScreen extends StatefulWidget {
  const SystemHealthScreen({super.key});

  @override
  State<SystemHealthScreen> createState() => _SystemHealthScreenState();
}

enum _CheckState { idle, checking, ok, failed }

class _SystemHealthScreenState extends State<SystemHealthScreen> {
  _CheckState _supabaseState = _CheckState.checking;
  _CheckState _geminiTestState = _CheckState.idle;

  bool get _geminiConfigured {
    final apiKey = dotenv.isInitialized ? dotenv.env['GEMINI_API_KEY'] : null;
    return apiKey != null && apiKey.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSupabase());
  }

  Future<void> _checkSupabase() async {
    setState(() => _supabaseState = _CheckState.checking);
    final ok = await checkSupabaseConnectivity();
    if (!mounted) return;
    setState(() => _supabaseState = ok ? _CheckState.ok : _CheckState.failed);
  }

  Future<void> _testGemini() async {
    final apiKey = dotenv.env['GEMINI_API_KEY']!;
    setState(() => _geminiTestState = _CheckState.checking);
    final ok = await checkGeminiReachability(apiKey);
    if (!mounted) return;
    setState(() => _geminiTestState = ok ? _CheckState.ok : _CheckState.failed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Health')),
      body: SafeArea(
        child: ListView(
          key: const Key('admin-system-health-list'),
          padding: const EdgeInsets.all(16),
          children: [
            _HealthIndicatorCard(
              key: const Key('admin-system-health-gemini'),
              icon: Icons.smart_toy_outlined,
              label: 'Gemini AI',
              status: _geminiConfigured ? _CheckState.ok : _CheckState.failed,
              statusText: _geminiConfigured ? 'Configured' : 'Not configured',
              detail: _geminiConfigured
                  ? 'GEMINI_API_KEY is set — AI features call the real Gemini API.'
                  : 'GEMINI_API_KEY is not set — AI features fall back to '
                        'built-in offline mocks.',
              trailing: _geminiConfigured ? _buildGeminiTestButton() : null,
            ),
            _HealthIndicatorCard(
              key: const Key('admin-system-health-supabase'),
              icon: Icons.storage_outlined,
              label: 'Supabase Connectivity',
              status: _supabaseState,
              statusText: switch (_supabaseState) {
                _CheckState.checking => 'Checking…',
                _CheckState.ok => 'Connected',
                _CheckState.failed => 'Unreachable',
                _CheckState.idle => 'Not checked',
              },
              detail:
                  'A live read against the profiles table, checked automatically on open.',
              trailing: TextButton.icon(
                key: const Key('admin-system-health-supabase-retry'),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Re-check'),
                onPressed: _supabaseState == _CheckState.checking
                    ? null
                    : _checkSupabase,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiTestButton() {
    if (_geminiTestState == _CheckState.checking) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_geminiTestState == _CheckState.idle) {
      return TextButton(
        key: const Key('admin-system-health-gemini-test'),
        onPressed: _testGemini,
        child: const Text('Test Connection'),
      );
    }
    final ok = _geminiTestState == _CheckState.ok;
    return TextButton.icon(
      key: const Key('admin-system-health-gemini-test'),
      onPressed: _testGemini,
      icon: Icon(ok ? Icons.check_circle : Icons.error_outline, size: 18),
      label: Text(ok ? 'Reachable' : 'Unreachable'),
    );
  }
}

class _HealthIndicatorCard extends StatelessWidget {
  const _HealthIndicatorCard({
    super.key,
    required this.icon,
    required this.label,
    required this.status,
    required this.statusText,
    required this.detail,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final _CheckState status;
  final String statusText;
  final String detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color statusColor;
    final IconData statusIcon;
    switch (status) {
      case _CheckState.ok:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      case _CheckState.failed:
        statusColor = Colors.amber.shade800;
        statusIcon = Icons.warning_amber;
      case _CheckState.checking:
      case _CheckState.idle:
        statusColor = theme.colorScheme.outline;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(detail, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  avatar: Icon(statusIcon, size: 16, color: statusColor),
                  label: Text(statusText),
                  labelStyle: TextStyle(color: statusColor),
                  side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
                ),
              ],
            ),
            if (trailing != null)
              Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ),
      ),
    );
  }
}
