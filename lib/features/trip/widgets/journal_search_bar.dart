import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/mood.dart';
import '../../journal/journal_filter.dart';
import '../../journal/widgets/format_utils.dart';
import '../../journal/widgets/mood_display.dart';

/// Search bar + mood/date filter chips over a trip's journal timeline
/// (IMPLEMENTATION_PLAN_EXTRA_FEATURES.md #2). Debounces text input so the
/// list doesn't rebuild on every keystroke; mood/date changes apply
/// immediately since they're discrete taps, not continuous typing.
class JournalSearchBar extends StatefulWidget {
  const JournalSearchBar({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final JournalFilter filter;
  final ValueChanged<JournalFilter> onChanged;

  @override
  State<JournalSearchBar> createState() => _JournalSearchBarState();
}

class _JournalSearchBarState extends State<JournalSearchBar> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.filter.query,
  );
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged(widget.filter.copyWith(query: value));
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial =
        widget.filter.startDate != null && widget.filter.endDate != null
        ? DateTimeRange(
            start: widget.filter.startDate!,
            end: widget.filter.endDate!,
          )
        : null;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initial,
    );
    if (range == null) return;
    widget.onChanged(
      widget.filter.copyWith(startDate: range.start, endDate: range.end),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;
    final hasDateRange = filter.startDate != null && filter.endDate != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('journal-search-field'),
            controller: _textController,
            decoration: InputDecoration(
              hintText: 'Search entries...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _textController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _textController.clear();
                        _debounce?.cancel();
                        widget.onChanged(filter.copyWith(query: ''));
                      },
                    ),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: _onQueryChanged,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  key: const Key('mood-filter-all'),
                  label: const Text('All moods'),
                  selected: filter.mood == null,
                  onSelected: (_) =>
                      widget.onChanged(filter.copyWith(clearMood: true)),
                ),
                const SizedBox(width: 8),
                for (final mood in Mood.values) ...[
                  ChoiceChip(
                    key: Key('mood-filter-${mood.name}'),
                    avatar: Icon(moodIcon(mood), size: 18),
                    label: Text(moodLabel(mood)),
                    selected: filter.mood == mood,
                    onSelected: (_) =>
                        widget.onChanged(filter.copyWith(mood: mood)),
                  ),
                  const SizedBox(width: 8),
                ],
                ActionChip(
                  key: const Key('date-range-filter'),
                  avatar: Icon(
                    hasDateRange ? Icons.date_range : Icons.date_range_outlined,
                    size: 18,
                  ),
                  label: Text(
                    hasDateRange
                        ? '${formatDate(filter.startDate!)} - ${formatDate(filter.endDate!)}'
                        : 'Any dates',
                  ),
                  onPressed: _pickDateRange,
                ),
                if (hasDateRange) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    key: const Key('date-range-filter-clear'),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        widget.onChanged(filter.copyWith(clearDateRange: true)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
