import 'package:flutter/material.dart';

import '../theme/aurora_theme.dart';

class AuroraPanel extends StatelessWidget {
  const AuroraPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.semanticLabel,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final VoidCallback? onTap;

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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(gradient: aurora.heroGradient),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: padding,
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: aurora.onHero),
                  child: IconTheme.merge(
                    data: IconThemeData(color: aurora.onHero),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
