import 'package:flutter/material.dart';

import 'card_shape.dart';

/// Bold section heading used by [SectionCard] and standalone section headers.
/// All section titles share this style so a text change is made in one place.
class SectionTitle extends StatelessWidget {
  final String text;
  final TextAlign textAlign;

  const SectionTitle(this.text, {super.key, this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// The standard titled content card used by every screen:
/// `Card(elevation: 0, shape: cardShape) > Padding > Column` with an optional
/// bold [title] above the [child]. Section chrome and heading style live here
/// once, so restyling the app's cards is a single edit.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final CrossAxisAlignment crossAxisAlignment;
  final Clip clipBehavior;

  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: margin,
      shape: cardShape(Theme.of(context)),
      clipBehavior: clipBehavior,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            if (title != null) ...[
              SectionTitle(title!),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
