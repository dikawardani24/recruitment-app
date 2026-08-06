import 'package:flutter/material.dart';

/// Score color: >=80% green, >=70% orange, below red.
Color scoreColor(double score) {
  if (score >= 0.80) return Colors.green;
  if (score >= 0.70) return Colors.orange;
  return Colors.red;
}
