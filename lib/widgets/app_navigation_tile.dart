import 'package:flutter/material.dart';

class AppNavigationTile extends StatelessWidget {
  const AppNavigationTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: ListTile(
          minTileHeight: 72,
          onTap: onTap,
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.onPrimaryContainer, size: 24),
          ),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing:
              trailing ??
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}
