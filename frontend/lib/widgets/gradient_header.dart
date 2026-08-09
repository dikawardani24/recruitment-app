import 'package:flutter/material.dart';

const _avatarPalette = [
  Color(0xFF3F51B5),
  Color(0xFF00897B),
  Color(0xFFD81B60),
  Color(0xFFF57C00),
  Color(0xFF5E35B1),
];

Color avatarColor(int index) => _avatarPalette[index % _avatarPalette.length];

/// A stable palette color for a candidate, derived from their id so the same
/// candidate keeps the same color across screens and charts.
Color candidateColor(String id) {
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return avatarColor(h);
}

class GradientHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const GradientHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // The Material 3 dark scheme uses light pastel primary/tertiary tones, so
    // darken the gradient in dark mode to keep the white text readable.
    final gradientColors = isDark
        ? [
            Color.lerp(scheme.primary, Colors.black, 0.6)!,
            Color.lerp(scheme.tertiary, Colors.black, 0.6)!,
          ]
        : [scheme.primary, scheme.tertiary];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          trailing ??
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
        ],
      ),
    );
  }
}
