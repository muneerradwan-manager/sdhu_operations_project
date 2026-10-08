import 'package:flutter/material.dart';

/// The Administration's brand palette — the single source of colour for the
/// whole app.
///
/// Nothing outside this file may introduce a new hue. The nine brand colours
/// below are fixed; the only additions allowed are the neutrals (black, white,
/// hint) and the surface/ink tones further down, which are those same brand
/// colours mixed with black or white — no new hue is introduced by a mix.
class AppColors {
  const AppColors._();

  // ── Brand: green ────────────────────────────────────────────────────────
  static const Color darkGreen = Color(0xFF00594F);
  static const Color mediumGreen = Color(0xFF016D5D);
  static const Color lightGreen = Color(0xFF289E92);

  // ── Brand: red ──────────────────────────────────────────────────────────
  static const Color darkRed = Color(0xFF420023);
  static const Color mediumRed = Color(0xFF672146);
  static const Color lightRed = Color(0xFF7A2631);

  // ── Brand: gold ─────────────────────────────────────────────────────────
  static const Color darkGold = Color(0xFFAD9E6E);
  static const Color mediumGold = Color(0xFFD9C89E);
  static const Color lightGold = Color(0xFFE4DDD3);

  // ── Neutrals ────────────────────────────────────────────────────────────
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  /// Placeholder and secondary-label text on dark surfaces.
  static const Color hint = Color(0xFF8A8A8A);

  /// Hint on light surfaces, where [hint] drops under a 4.5:1 contrast ratio.
  static const Color hintStrong = Color(0xFF5E5E5E);

  // ── Surfaces (brand × black) ────────────────────────────────────────────
  /// Top of the dark backdrop: [darkGreen] at 14% over [black].
  static const Color nightTop = Color(0xFF000C0B);

  /// Middle of the dark backdrop: [mediumGreen] at 20% over [black].
  static const Color nightMid = Color(0xFF001613);

  /// Bottom of the dark backdrop: [darkGold] at 6% over [black], so the field
  /// warms slightly as it falls away.
  static const Color nightEnd = Color(0xFF0A0907);

  // ── Surfaces (brand × white) ────────────────────────────────────────────
  // The light backdrop is a DESK, not a page. Every pane in this app is white
  // at some alpha, so a white field leaves nothing for a pane to be white
  // against: at the old 15/35/55 the whole of light mode was one sheet, panes
  // and background alike, separated by six parts in a thousand. That reads as
  // flat on a phone, where the screen edge frames each card anyway, and as
  // nothing at all on a monitor, where three panes float in the middle of it.
  //
  // Deepened to 45/65/85, these three are the surface the paper sits ON.

  /// Top of the light backdrop: [lightGold] at 45% over [white].
  static const Color paperTop = Color(0xFFF3F0EB);

  /// Middle of the light backdrop: [lightGold] at 65% over [white].
  static const Color paperMid = Color(0xFFEDE9E2);

  /// Bottom of the light backdrop: [lightGold] at 85% over [white], so the
  /// field warms slightly as it falls away.
  static const Color paperEnd = Color(0xFFE8E2DA);

  // ── Ink ─────────────────────────────────────────────────────────────────
  /// Body text on light surfaces: [darkGreen] at 25% over [black].
  static const Color ink = Color(0xFF001614);

  /// Body text on dark surfaces: [lightGold] at 35% over [white].
  static const Color inkInverse = Color(0xFFF6F3F0);
}
