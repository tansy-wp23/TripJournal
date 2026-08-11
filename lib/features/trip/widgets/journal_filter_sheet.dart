import 'package:flutter/material.dart';

import '../../../models/mood.dart';
import '../../journal/journal_filter.dart';
import '../../journal/widgets/format_utils.dart';
import '../../journal/widgets/mood_display.dart';

class JournalFilterSheet extends StatefulWidget {
  const JournalFilterSheet({super.key, required this.initialFilter});

  final JournalFilter initialFilter;

  @override
  State<JournalFilterSheet> createState() => _JournalFilterSheetState();
}

class _JournalFilterSheetState extends State<JournalFilterSheet> {
  late JournalFilter _draft = widget.initialFilter;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _draft.startDate != null && _draft.endDate != null
          ? DateTimeRange(start: _draft.startDate!, end: _draft.endDate!)
          : null,
    );
    if (range != null) {
      setState(() => _draft = _draft.copyWith(startDate: range.start, endDate: range.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDates = _draft.startDate != null && _draft.endDate != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter entries', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('Mood'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('mood-filter-all'),
                  label: const Text('All moods'),
                  selected: _draft.mood == null,
                  onSelected: (_) => setState(() => _draft = _draft.copyWith(clearMood: true)),
                ),
                for (final mood in Mood.values)
                  ChoiceChip(
                    key: Key('mood-filter-${mood.name}'),
                    avatar: Icon(moodIcon(mood), size: 18),
                    label: Text(moodLabel(mood)),
                    selected: _draft.mood == mood,
                    onSelected: (_) => setState(() => _draft = _draft.copyWith(mood: mood)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const Key('date-range-filter'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.date_range_outlined),
              title: Text(hasDates
                  ? '${formatDate(_draft.startDate!)} - ${formatDate(_draft.endDate!)}'
                  : 'Any dates'),
              trailing: hasDates
                  ? IconButton(
                      key: const Key('date-range-filter-clear'),
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _draft = _draft.copyWith(clearDateRange: true)),
                    )
                  : null,
              onTap: _pickDateRange,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  key: const Key('clear-journal-filter-sheet'),
                  onPressed: () => setState(() => _draft = JournalFilter(query: _draft.query)),
                  child: const Text('Clear filters'),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('apply-journal-filters'),
                  onPressed: () => Navigator.pop(context, _draft),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
