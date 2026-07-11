import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/journal_entry.dart';
import '../controller/journal_controller.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/format_utils.dart' show formatDate, formatThousands;
import '../widgets/meal_display.dart';
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
          IconButton(
            key: const Key('edit-entry-button'),
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreateEditEntryScreen(existingEntry: entry)),
            ),
          ),
          IconButton(
            key: const Key('delete-entry-button'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDeleteConfirmationDialog(context, entryTitle: entry.displayTitle);
              if (!confirmed || !context.mounted) return;
              await ref.read(journalControllerProvider.notifier).remove(entry.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(moodIcon(entry.mood)),
              const SizedBox(width: 8),
              Text(moodLabel(entry.mood)),
              const Spacer(),
              Text(formatDate(entry.createdAt)),
            ],
          ),
          const SizedBox(height: 16),
          Text(entry.body, style: Theme.of(context).textTheme.bodyLarge),
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
                        builder: (_) => PhotoViewerScreen(photoPaths: entry.photoPaths, initialIndex: i),
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
                    Text('Health Log', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '${formatThousands(healthLog.steps)} steps · '
                      'Eaten: ${formatThousands(healthLog.caloriesEaten)} kcal · '
                      'Burned: ${healthLog.caloriesBurned != null ? '${formatThousands(healthLog.caloriesBurned!)} kcal' : '— (no health data)'}',
                    ),
                    const SizedBox(height: 12),
                    Text('Meals', style: Theme.of(context).textTheme.titleSmall),
                    for (final meal in healthLog.meals)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(meal.name),
                        subtitle: Text(
                          '${mealTypeLabel(meal.mealType)} · ${portionSizeLabel(meal.portion)} · '
                          '~${meal.calories} kcal',
                        ),
                      ),
                    const Divider(),
                    Text('AI advice', style: Theme.of(context).textTheme.titleSmall),
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
