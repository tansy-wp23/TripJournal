import 'package:flutter/material.dart';

final class AppActionMenuItem<T> {
  const AppActionMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.key,
    this.destructive = false,
    this.startsSection = false,
  });

  final T value;
  final String label;
  final IconData icon;
  final Key? key;
  final bool destructive;
  final bool startsSection;
}

class AppActionMenu<T> extends StatelessWidget {
  const AppActionMenu({
    super.key,
    required this.tooltip,
    required this.items,
    required this.onSelected,
    this.icon = Icons.more_vert_rounded,
  });

  final String tooltip;
  final List<AppActionMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopupMenuButton<T>(
      tooltip: tooltip,
      icon: Icon(icon),
      padding: const EdgeInsets.all(12),
      onSelected: onSelected,
      itemBuilder: (context) {
        final entries = <PopupMenuEntry<T>>[];
        for (final item in items) {
          if (item.startsSection && entries.isNotEmpty) {
            entries.add(const PopupMenuDivider());
          }
          final foreground = item.destructive ? colors.error : null;
          entries.add(
            PopupMenuItem<T>(
              key: item.key,
              value: item.value,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 48,
                leading: Icon(item.icon, color: foreground, size: 24),
                title: Text(
                  item.label,
                  style: foreground == null
                      ? null
                      : TextStyle(color: foreground),
                ),
              ),
            ),
          );
        }
        return entries;
      },
    );
  }
}
