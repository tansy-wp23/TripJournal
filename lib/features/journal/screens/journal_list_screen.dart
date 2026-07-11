import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/journal_controller.dart';
import '../mock_trip.dart';
import '../widgets/format_utils.dart';
import '../widgets/mood_display.dart';
import 'create_edit_entry_screen.dart';
import 'entry_detail_screen.dart';

class JournalListScreen extends ConsumerStatefulWidget {
  const JournalListScreen({super.key});

  @override
  ConsumerState<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends ConsumerState<JournalListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(journalControllerProvider.notifier).loadEntries(kMockTripId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(journalControllerProvider);
    final entries = [...controller.entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: Builder(
        builder: (context) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.error != null) {
            return Center(child: Text('Error: ${controller.error}'));
          }
          if (entries.isEmpty) {
            return const Center(child: Text('No journal entries yet. Tap + to add one.'));
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final healthLog = entry.healthLog;
              final healthSummary = healthLog == null
                  ? 'No health log'
                  : '${formatThousands(healthLog.steps)} steps · '
                      '${formatThousands(healthLog.caloriesEaten)} kcal';
              return ListTile(
                leading: Icon(moodIcon(entry.mood)),
                title: Text(entry.displayTitle),
                subtitle: Text('${formatDate(entry.createdAt)}\n$healthSummary'),
                isThreeLine: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: entry.id)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateEditEntryScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
