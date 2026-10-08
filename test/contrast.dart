import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG relative luminance and the ratio between two of them.
///
/// Shared because two suites now measure colour rather than assert it: the
/// accents against the backdrop they are written on, and the glass tokens
/// against the surface they are supposed to bound.
double luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = luminance(a), lb = luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}
