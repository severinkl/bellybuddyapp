import 'package:flutter/material.dart';

/// Deterministic light-pastel color derived from a title's hash. Saturation
/// and lightness are fixed so all returned colors sit in the same visual
/// register — only the hue varies. Used as an image fallback in recipe cards.
Color pastelForTitle(String title) {
  final hash = title.hashCode.abs();
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.45, 0.86).toColor();
}
