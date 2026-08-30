import 'package:flutter/material.dart';

import '../theme/aurora_theme.dart';

class AuroraPanel extends StatelessWidget {
  const AuroraPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aurora = AuroraTheme.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          gradient: aurora.heroGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: aurora.onHero),
          child: IconTheme.merge(
            data: IconThemeData(color: aurora.onHero),
            child: child,
          ),
        ),
      ),
    );
  }
}
