import 'package:flutter/material.dart';

/// Red swipe-reveal background shown behind a dismissible tile while it is
/// swiped, signalling a destructive swipe.
class DeleteBackground extends StatelessWidget {
  final Color color;

  const DeleteBackground({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}
