import 'package:flutter/material.dart';

/// A calm, repeatable container for long-form editing screens.
///
/// The heading and optional action adapt independently from the form body so
/// narrow phones never have to squeeze controls beside a long title.
class AppFormSection extends StatelessWidget {
  const AppFormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.helperText,
    this.action,
  });

  final String title;
  final IconData icon;
  final String? helperText;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              if (helperText case final helper?) ...[
                const SizedBox(height: 3),
                Text(
                  helper,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 360;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (action == null)
                  heading
                else if (narrow) ...[
                  heading,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: action!),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: heading),
                      const SizedBox(width: 12),
                      action!,
                    ],
                  ),
                const SizedBox(height: 20),
                child,
              ],
            );
          },
        ),
      ),
    );
  }
}
