import 'package:flutter/material.dart';

/// The shared rounded-card border used by every card in the app. Define the
/// card look here once; everything else references it.
ShapeBorder cardShape(ThemeData theme, {double radius = 16}) =>
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
    );
