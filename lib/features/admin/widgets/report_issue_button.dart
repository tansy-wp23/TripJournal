import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/admin_repository_locator.dart';
import '../../../data/current_user_id_provider.dart';
import '../../../data/trip_repository_locator.dart';
import '../../../validation/photo_validation.dart';

/// Opens a form for filing an [IssueReport] — PB-06 (Sprint 2, scope added
/// per Open Decision 4). Placed on a small, representative set of
/// non-admin screens (`HomeScreen`, `TripViewScreen`), per the plan's
/// "selected pages" wording, not every screen — each placement is a
/// cross-module edit, flagged in `docs/admin/PROGRESS.md`.
///
/// [page] identifies which screen placed the button — passed in by the
/// caller, not inferred, since this codebase has no route-introspection
/// convention to derive it automatically (`ADMIN_MODULE_IMPLEMENTATION_PLAN.md`
/// Sprint 2, Phase 10, task 1).
///
/// [userIdProvider] mirrors `HomeScreen`/`TripViewScreen`'s own
/// `CurrentUserIdProvider?` constructor parameter, for the same
/// test-injection reason — defaults to the shared `currentUserIdProvider`.
class ReportIssueButton extends StatelessWidget {
  const ReportIssueButton({super.key, required this.page, this.userIdProvider});

  final String page;
  final CurrentUserIdProvider? userIdProvider;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('report-issue-button'),
      tooltip: 'Report an issue',
      icon: const Icon(Icons.report_problem_outlined),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        // Dismissal only through paths this form controls (Cancel, Submit,
        // or the system back gesture, all funneled through the same
        // discard-confirmation as CreateEditEntryScreen's guard) — the
        // default scrim-tap-to-dismiss and drag-to-dismiss both call
        // Navigator.pop directly, which would silently drop a filled-out
        // report without ever consulting that guard.
        isDismissible: false,
        enableDrag: false,
        builder: (_) =>
            _ReportIssueForm(page: page, userIdProvider: userIdProvider),
      ),
    );
  }
}

class _ReportIssueForm extends StatefulWidget {
  const _ReportIssueForm({required this.page, this.userIdProvider});

  final String page;
  final CurrentUserIdProvider? userIdProvider;

  @override
  State<_ReportIssueForm> createState() => _ReportIssueFormState();
}

class _ReportIssueFormState extends State<_ReportIssueForm> {
  final _descriptionController = TextEditingController();
  XFile? _pickedPhoto;
  Uint8List? _pickedPhotoBytes;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Camera vs. gallery, same pattern as `ProfileEditScreen._pickAvatar` —
  /// an existing photo via `image_picker` (Sprint 2 Open Decision 5), not
  /// literal automatic screen-capture. A failure (denied permission, no
  /// camera, user backing out) is swallowed into a SnackBar, since the
  /// attachment is optional either way.
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              key: const Key('report-issue-photo-camera'),
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              key: const Key('report-issue-photo-gallery'),
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) return; // user backed out of the OS picker

      final bytes = await picked.readAsBytes();
      final sizeError = validatePhotoSize(bytes.length);
      if (sizeError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(sizeError)));
        return;
      }

      setState(() {
        _pickedPhoto = picked;
        _pickedPhotoBytes = bytes;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't access photos — you can still submit without one.",
          ),
        ),
      );
    }
  }

  void _removePhoto() => setState(() {
    _pickedPhoto = null;
    _pickedPhotoBytes = null;
  });

  /// Whether closing the sheet right now would lose something the user
  /// typed/attached — mirrors `CreateEditEntryScreen`'s `_dirty` flag, gating
  /// the discard prompt so a pristine, untouched form still closes silently.
  bool get _hasContent =>
      _descriptionController.text.trim().isNotEmpty || _pickedPhoto != null;

  Future<void> _handleBackAttempt(bool didPop, Object? result) async {
    if (didPop) return;
    final discard = await _confirmDiscard();
    if (!mounted) return;
    if (discard) Navigator.pop(context);
  }

  Future<void> _handleCancelTap() async {
    if (!_hasContent) {
      Navigator.pop(context);
      return;
    }
    final discard = await _confirmDiscard();
    if (!mounted) return;
    if (discard) Navigator.pop(context);
  }

  /// "Discard this report?" — only ever reached when [_hasContent] is true,
  /// mirroring `CreateEditEntryScreen._confirmDiscard`'s same "don't nag a
  /// clean form" rule.
  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this report?'),
        content: const Text('Your description and photo will be lost.'),
        actions: [
          TextButton(
            key: const Key('report-issue-keep-editing'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            key: const Key('report-issue-discard-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Please describe what went wrong.');
      return;
    }

    late final String userId;
    try {
      userId = (widget.userIdProvider ?? currentUserIdProvider).requireUserId();
    } on UnauthenticatedTripUserException catch (e) {
      setState(() => _error = e.toString());
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // Mirrors `CreateEditEntryScreen`'s photo handling: the picked
      // file's local device path is stored directly — there's no upload
      // step yet in mock mode (unlike `ProfileAvatarStorage`/
      // `TripCoverStorage`, which don't exist for issue-report photos).
      await issueReportRepository.submitReport(
        userId: userId,
        page: widget.page,
        description: description,
        screenshotUrl: _pickedPhoto?.path,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks — your report has been submitted.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit your report: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasContent,
      onPopInvokedWithResult: _handleBackAttempt,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report an issue',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Reporting from: ${widget.page}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('report-issue-description-field'),
              controller: _descriptionController,
              autofocus: true,
              maxLines: 4,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'What went wrong?',
                border: OutlineInputBorder(),
              ),
              // Only needed so _hasContent's derived PopScope.canPop stays
              // current as the user types — the field displays its own text
              // via _descriptionController regardless.
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (_pickedPhotoBytes != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _pickedPhotoBytes!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      key: const Key('report-issue-remove-photo'),
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                      onPressed: _submitting ? null : _removePhoto,
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                key: const Key('report-issue-attach-photo'),
                onPressed: _submitting ? null : _pickPhoto,
                icon: const Icon(Icons.attach_file),
                label: const Text('Attach a photo (optional)'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _handleCancelTap,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('report-issue-submit-button'),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
