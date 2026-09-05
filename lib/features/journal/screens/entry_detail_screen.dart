import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../models/journal_entry.dart';
import '../../../widgets/app_action_menu.dart';
import '../../../widgets/app_content_toolbar.dart';
import '../controller/journal_controller.dart';
import '../pdf/journal_pdf_export.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/format_utils.dart' show formatDate, formatThousands;
import '../widgets/meal_display.dart';
import '../widgets/meal_rating_stars.dart';
import '../widgets/mood_display.dart';
import '../widgets/photo_thumbnail.dart';
import 'create_edit_entry_screen.dart';
import 'photo_viewer_screen.dart';

class EntryDetailScreen extends ConsumerStatefulWidget {
  const EntryDetailScreen({super.key, required this.entryId});

  final String entryId;

  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen> {
  bool _generatingAdvice = false;
  String? _adviceError;
  bool _editingAdvice = false;
  TextEditingController? _adviceController;

  @override
  void dispose() {
    _adviceController?.dispose();
    super.dispose();
  }

  JournalEntry? _findEntry(List<JournalEntry> entries) {
    for (final entry in entries) {
      if (entry.id == widget.entryId) return entry;
    }
    return null;
  }

  Future<void> _exportPdf(BuildContext context, JournalEntry entry) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await buildEntryPdf(entry);
      if (context.mounted) Navigator.pop(context); // close the loading dialog
      await Printing.sharePdf(
        bytes: bytes,
        filename: pdfFileNameFor(entry.displayTitle),
      );
    } catch (_) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not export this entry as a PDF.'),
          ),
        );
      }
    }
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    JournalEntry entry,
  ) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      entryTitle: entry.displayTitle,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(journalControllerProvider.notifier).remove(entry.id);
    if (context.mounted) Navigator.pop(context);
  }

  /// Generates (or regenerates) AI advice for [entry] on demand and persists
  /// it. Never fires automatically - this is the only path that touches
  /// `healthLog.aiAdvice`, so a plain edit/save elsewhere in the app can
  /// never silently regenerate or clear it.
  Future<void> _generateAdvice(JournalEntry entry) async {
    setState(() {
      _generatingAdvice = true;
      _adviceError = null;
    });

    final controller = ref.read(journalControllerProvider.notifier);
    final advice = await controller.generateAndAttachAdvice(entry);
    if (!mounted) return;
    setState(() {
      _generatingAdvice = false;
      if (advice == null) _adviceError = 'Could not generate advice.';
    });
  }

  void _startEditingAdvice(String advice) {
    _adviceController?.dispose();
    setState(() {
      _adviceController = TextEditingController(text: advice);
      _editingAdvice = true;
      _adviceError = null;
    });
  }

  void _cancelEditingAdvice() {
    _adviceController?.dispose();
    setState(() {
      _adviceController = null;
      _editingAdvice = false;
    });
  }

  Future<void> _saveEditedAdvice(JournalEntry entry) async {
    final healthLog = entry.healthLog;
    if (healthLog == null) return;
    final text = _adviceController?.text.trim() ?? '';
    if (text.isEmpty) {
      setState(() => _adviceError = 'AI advice cannot be empty.');
      return;
    }

    final controller = ref.read(journalControllerProvider.notifier);
    final error = await controller.edit(
      entry.copyWith(healthLog: healthLog.copyWith(aiAdvice: text)),
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _adviceError = error);
      return;
    }

    _adviceController?.dispose();
    setState(() {
      _adviceController = null;
      _editingAdvice = false;
      _adviceError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(journalControllerProvider);
    final entry = _findEntry(controller.entries);

    if (entry == null) {
      return const Scaffold(body: Center(child: Text('Entry not found.')));
    }

    final healthLog = entry.healthLog;

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.displayTitle),
        actions: [
          AppActionMenu<_EntryDetailAction>(
            key: const Key('entry-detail-more-menu'),
            tooltip: 'More entry actions',
            onSelected: (action) {
              switch (action) {
                case _EntryDetailAction.exportPdf:
                  _exportPdf(context, entry);
                case _EntryDetailAction.delete:
                  _deleteEntry(context, ref, entry);
              }
            },
            items: const [
              AppActionMenuItem(
                key: Key('export-entry-pdf-button'),
                value: _EntryDetailAction.exportPdf,
                label: 'Export entry as PDF',
                icon: Icons.picture_as_pdf_outlined,
              ),
              AppActionMenuItem(
                key: Key('delete-entry-button'),
                value: _EntryDetailAction.delete,
                label: 'Move to Trash',
                icon: Icons.delete_outline,
                destructive: true,
                startsSection: true,
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppContentToolbar(
            children: [
              Chip(
                avatar: Icon(moodIcon(entry.mood), size: 18),
                label: Text(moodLabel(entry.mood)),
              ),
              Text(formatDate(entry.createdAt)),
              OutlinedButton.icon(
                key: const Key('edit-entry-button'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit entry'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEditEntryScreen(existingEntry: entry),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(entry.body, style: Theme.of(context).textTheme.bodyLarge),
          if (entry.location?.locationTag case final tag?) ...[
            const SizedBox(height: 12),
            Text(
              tag,
              key: const Key('entry-location-tag'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          if (entry.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < entry.photoPaths.length; i++)
                  PhotoThumbnail(
                    key: Key('photo-thumbnail-$i'),
                    photoPath: entry.photoPaths[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhotoViewerScreen(
                          photoPaths: entry.photoPaths,
                          initialIndex: i,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (healthLog == null)
            const Text('No health log for this entry.')
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Log',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatThousands(healthLog.steps)} steps · '
                      'Eaten: ${formatThousands(healthLog.caloriesEaten)} kcal · '
                      'Burned: ${healthLog.caloriesBurned != null ? '${formatThousands(healthLog.caloriesBurned!)} kcal' : '— (no health data)'}',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Meals',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final meal in healthLog.meals)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: meal.photoPath == null
                            ? null
                            : PhotoThumbnail(
                                key: Key('meal-photo-${meal.id}'),
                                photoPath: meal.photoPath!,
                                size: 40,
                              ),
                        title: Text(meal.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${mealTypeLabel(meal.mealType)} · ${portionSizeLabel(meal.portion)} · '
                              '~${meal.calories} kcal',
                            ),
                            if (meal.restaurantName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  meal.restaurantName!,
                                  key: Key(
                                    'meal-restaurant-display-${meal.id}',
                                  ),
                                ),
                              ),
                            if (meal.foodReview != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  meal.foodReview!,
                                  key: Key('meal-review-display-${meal.id}'),
                                ),
                              ),
                            if (meal.rating != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: MealRatingStars(
                                  key: Key('meal-rating-display-${meal.id}'),
                                  rating: meal.rating,
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    _AiAdviceCard(
                      advice: healthLog.aiAdvice,
                      isGenerating: _generatingAdvice,
                      error: _adviceError,
                      isEditing: _editingAdvice,
                      adviceController: _adviceController,
                      onGenerate: () => _generateAdvice(entry),
                      onEdit: () =>
                          _startEditingAdvice(healthLog.aiAdvice ?? ''),
                      onSaveEdit: () => _saveEditedAdvice(entry),
                      onCancelEdit: _cancelEditingAdvice,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _EntryDetailAction { exportPdf, delete }

/// Mirrors `_TripSummaryCard` (trip_view_screen.dart) - same generate/
/// regenerate/edit shape, applied to one entry's AI advice instead of the
/// whole trip's AI summary. Advice never regenerates on its own; only these
/// two buttons ever call the AI service or write `healthLog.aiAdvice`.
class _AiAdviceCard extends StatelessWidget {
  const _AiAdviceCard({
    required this.advice,
    required this.isGenerating,
    required this.error,
    required this.isEditing,
    required this.adviceController,
    required this.onGenerate,
    required this.onEdit,
    required this.onSaveEdit,
    required this.onCancelEdit,
  });

  final String? advice;
  final bool isGenerating;
  final String? error;
  final bool isEditing;
  final TextEditingController? adviceController;
  final VoidCallback onGenerate;
  final VoidCallback onEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      key: const Key('ai-advice-card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Row(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text('AI advice', style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        if (isGenerating)
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Generating advice...'),
            ],
          )
        else ...[
          if (advice != null && !isEditing)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(advice!, key: const Key('entry-ai-advice-text')),
                ),
                IconButton(
                  key: const Key('edit-advice-button'),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit advice',
                  onPressed: onEdit,
                ),
              ],
            ),
          if (advice == null && !isEditing)
            const Text(
              'No AI advice yet.',
              key: Key('entry-ai-advice-text'),
            ),
          if (isEditing)
            TextField(
              key: const Key('advice-editor-field'),
              controller: adviceController,
              decoration: const InputDecoration(
                labelText: 'AI advice',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              minLines: 3,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(error!, style: TextStyle(color: colorScheme.error)),
            ),
          const SizedBox(height: 4),
          if (isEditing)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('cancel-edit-advice-button'),
                  onPressed: onCancelEdit,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('save-advice-button'),
                  onPressed: onSaveEdit,
                  child: const Text('Save'),
                ),
              ],
            )
          else
            TextButton.icon(
              key: const Key('generate-advice-button'),
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(advice == null ? 'Generate advice' : 'Regenerate advice'),
            ),
        ],
      ],
    );
  }
}
