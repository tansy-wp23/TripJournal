import 'dart:async';

import 'package:flutter/material.dart';

import '../../journal/journal_filter.dart';

/// Debounced text search over a trip's journal timeline. Mood and date
/// criteria live in the separate filter sheet.
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
  void didUpdateWidget(covariant JournalSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keeps the visible text in sync when the filter is cleared/changed from
    // outside this widget (e.g. the "Clear filters" button on the empty
    // state) -- typing itself never hits this branch, since the value here
    // already matches what the field already shows.
    if (widget.filter.query != _textController.text) {
      _textController.text = widget.filter.query;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged(widget.filter.copyWith(query: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        key: const Key('journal-search-field'),
        controller: _textController,
        decoration: InputDecoration(
          labelText: 'Search entries',
          hintText: 'Title or journal text',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _textController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    setState(_textController.clear);
                    _debounce?.cancel();
                    widget.onChanged(filter.copyWith(query: ''));
                  },
                ),
        ),
        onChanged: _onQueryChanged,
      ),
    );
  }
}
