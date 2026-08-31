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

class EntryDetailScreen extends ConsumerWidget {
  const EntryDetailScreen({super.key, required this.entryId});

  final String entryId;

  JournalEntry? _findEntry(List<JournalEntry> entries) {
    for (final entry in entries) {
      if (entry.id == entryId) return entry;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    const Divider(),
                    Text(
                      'AI advice',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(healthLog.aiAdvice ?? 'No AI advice yet.'),
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
