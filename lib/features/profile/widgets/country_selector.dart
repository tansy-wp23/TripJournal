import 'package:flutter/material.dart';

import '../../../data/countries.dart';

/// Tap-to-open, searchable country picker. A plain scrolling dropdown over
/// ~195 entries is painful to use — this opens a modal sheet with a search
/// field instead, filtering [kCountries] as the user types.
class CountrySelector extends StatelessWidget {
  const CountrySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _CountrySearchSheet(initial: value),
    );
    // A picked value of '' is the sheet's explicit "Clear selection" result,
    // distinct from a null dismiss (user backed out without choosing).
    if (picked == null) return;
    onChanged(picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('country-selector-field'),
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Country',
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(
                  key: const Key('country-clear-button'),
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear country',
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(
          value ?? 'Not set',
          style: value == null
              ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
              : null,
        ),
      ),
    );
  }
}

class _CountrySearchSheet extends StatefulWidget {
  const _CountrySearchSheet({required this.initial});

  final String? initial;

  @override
  State<_CountrySearchSheet> createState() => _CountrySearchSheetState();
}

class _CountrySearchSheetState extends State<_CountrySearchSheet> {
  final _searchController = TextEditingController();
  List<String> _filtered = kCountries;

  void _onQueryChanged(String query) {
    final trimmed = query.trim().toLowerCase();
    setState(() {
      _filtered = trimmed.isEmpty
          ? kCountries
          : kCountries.where((c) => c.toLowerCase().contains(trimmed)).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('country-search-field'),
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search countries',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _onQueryChanged,
                    ),
                  ),
                  if (widget.initial != null)
                    TextButton(
                      key: const Key('country-clear-selection-button'),
                      onPressed: () => Navigator.pop(context, ''),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text('No matching countries.'))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final country = _filtered[index];
                        return ListTile(
                          key: Key('country-option-$country'),
                          title: Text(country),
                          selected: country == widget.initial,
                          onTap: () => Navigator.pop(context, country),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
