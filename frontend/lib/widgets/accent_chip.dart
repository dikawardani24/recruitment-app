import 'package:flutter/material.dart';

/// A small chip tinted with an [accent] color. Contrast is adapted to the
/// active brightness: light mode keeps the existing light pastel look, dark
/// mode uses a subtle tint over the dark surface so text stays readable.
class AccentChip extends StatelessWidget {
  final String label;
  final MaterialColor accent;

  const AccentChip({super.key, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: dark ? accent.withValues(alpha: 0.18) : accent.shade50,
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        color: dark ? accent.shade200 : accent.shade700,
      ),
    );
  }
}
