import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A brand colour made legible on the surface it is drawn on.
///
/// The nine colours in [AppColors] are a print palette, and they do not divide
/// evenly across a screen that has both a night and a paper mode. Measured
/// against the two backdrops this app actually uses:
///
/// ```
///                 on night   on paper
///   darkGreen        2.26      6.42
///   mediumGreen      2.98      4.88
///   lightGreen       5.69      2.55
///   darkRed          1.12     13.00
///   mediumRed        1.67      8.67
///   lightRed         1.91      7.59
///   darkGold         7.02      2.07
///   mediumGold      11.30      1.29
///   lightGold       13.86      1.05
/// ```
///
/// Every RED is unusable on the dark backdrop and every GOLD is unusable on the
/// light one. Only the greens half-work on both — which is why the app drifted
/// into using green for nearly everything, and why the two screens that were
/// not green had a card nobody could read.
///
/// The paper column is measured at [AppColors.paperEnd], the darkest point the
/// light field reaches, rather than at its middle: an accent has to hold at the
/// bottom of a page as well as across it. The three that cleared the old,
/// paler field by a tenth of a point — green, gold, goldSoft — are each a step
/// deeper here for it.
///
/// So an accent is a PAIR: the brand colour on the backdrop it already suits,
/// and the same hue mixed toward white or black for the one it does not. Each
/// pair below clears 4.5:1 on its own backdrop, and the mix is the least that
/// gets there. No new hue is introduced — which is the one rule [AppColors]
/// sets, and the same licence its own surface and ink tones are built on.
class Accent {
  const Accent._(this.onLight, this.onDark, {required this.brand});

  /// For a surface of paper.
  final Color onLight;

  /// For a surface of night.
  final Color onDark;

  /// The brand colour this pair is made of, for anything that wants the print
  /// value rather than the legible one.
  final Color brand;

  Color of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? onDark : onLight;

  // ── The mission's own work and people: green ────────────────────────────
  /// [AppColors.lightGreen], darkened 28% on paper.
  static const green = Accent._(
    Color(0xFF1C7068),
    AppColors.lightGreen,
    brand: AppColors.lightGreen,
  );

  /// [AppColors.mediumGreen], lightened 20% on night.
  static const greenDeep = Accent._(
    AppColors.mediumGreen,
    Color(0xFF348A7D),
    brand: AppColors.mediumGreen,
  );

  /// [AppColors.darkGreen], lightened 29% on night.
  static const greenDark = Accent._(
    AppColors.darkGreen,
    Color(0xFF4A8982),
    brand: AppColors.darkGreen,
  );

  // ── The calendar and the reference material: gold ───────────────────────
  /// [AppColors.darkGold], darkened 37% on paper.
  static const gold = Accent._(
    Color(0xFF6D6445),
    AppColors.darkGold,
    brand: AppColors.darkGold,
  );

  /// [AppColors.mediumGold], darkened 50% on paper — the palest brand colour
  /// there is, and the one that needs the most help on a white page.
  static const goldSoft = Accent._(
    Color(0xFF6C644F),
    AppColors.mediumGold,
    brand: AppColors.mediumGold,
  );

  // ── The decisions made about people: red ────────────────────────────────
  /// [AppColors.lightRed], lightened 33% on night.
  static const red = Accent._(
    AppColors.lightRed,
    Color(0xFFA66E75),
    brand: AppColors.lightRed,
  );

  /// [AppColors.mediumRed], lightened 36% on night.
  static const redDeep = Accent._(
    AppColors.mediumRed,
    Color(0xFF9E7189),
    brand: AppColors.mediumRed,
  );

  /// The last brand colour to be given a pair: [AppColors.darkRed], which at
  /// 1.12 on night and 15.13 on paper is the most lopsided of the nine and was
  /// left alone until something needed it.
  ///
  /// Both steps are the ones the chart palette was measured at — see
  /// [ChartPalette], where this same hue had to clear the six checks against
  /// both backdrops. Reusing them here means the dashboard's tile and the
  /// dashboard's own marks are the same colour, which is the sort of thing
  /// somebody notices without being able to say why.
  static const plum = Accent._(
    Color(0xFF8C2A55),
    Color(0xFFB85C86),
    brand: AppColors.darkRed,
  );
}
