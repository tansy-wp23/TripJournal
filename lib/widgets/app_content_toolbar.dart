import 'package:flutter/material.dart';

class AppContentToolbar extends StatelessWidget {
  const AppContentToolbar({
    super.key,
    required this.children,
    this.resultLabel,
    this.activeFilterLabel,
    this.padding = const EdgeInsets.all(12),
  });

  final List<Widget> children;
  final String? resultLabel;
  final String? activeFilterLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasContext = resultLabel != null || activeFilterLabel != null;

    return Card(
      margin: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasContext) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (resultLabel case final label?)
                      Text(label, style: theme.textTheme.labelLarge),
                    if (activeFilterLabel case final label?)
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: children,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
