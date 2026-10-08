import 'package:flutter/material.dart';

/// The colours a chart may use, and the rules for which.
///
/// [AppColors] is a PRINT palette: nine values in three hue families, three of
/// them greens a shade apart. That is a fine thing to brand a screen with and a
/// bad thing to encode data with — measured, its own green and its own gold sit
/// ΔE 10 apart in normal vision and 5.4 apart under protanopia, which is to say
/// two adjacent slices of a chart nobody could tell apart. (The threshold is
/// 15 and 8.)
///
/// So the chart colours are the same three HUES, re-stepped until they pass —
/// the same licence [Accent] takes when it mixes a brand colour toward white to
/// make it legible on a dark backdrop. No new hue is introduced. Each set was
/// run through the six checks against the surface it is drawn on:
///
/// A chart is always drawn inside a pane, never straight onto the backdrop, so
/// the light column is measured against the PANE — which is white — and not
/// against the field the pane stands on. That is the one place these differ
/// from [Accent], whose colours do land on the bare backdrop.
///
/// ```
///   light, on pane #FDFCFB      dark, on night #001613
///   ─────────────────────────   ────────────────────────
///   teal  #00897B               teal  #009485
///   gold  #A8801A               gold  #B08B37
///   plum  #8C2A55               plum  #B85C86
///
///   lightness band      PASS    lightness band      PASS
///   chroma floor        PASS    chroma floor        PASS
///   CVD separation      PASS    CVD separation      PASS
///     worst ΔE 11.5 protan        worst ΔE 10.4 protan
///   normal-vision floor PASS    normal-vision floor PASS
///     worst ΔE 17.6                worst ΔE 17.3
///   contrast vs surface PASS    contrast vs surface PASS
/// ```
///
/// Three slots, and three is the ceiling — [series] is never cycled and never
/// extended by generating a fourth hue. Anything with more categories than that
/// is not a job for colour: it is a ranked bar chart in [sequential], where the
/// axis label carries the identity and the bar's LENGTH carries the number.
/// That is why nothing here needs eight colours.
class ChartPalette {
  const ChartPalette._();

  /// Identity, in fixed order. Slot 0 is always the first category named, in
  /// every chart on the page, so a colour means the same thing twice.
  static const series = <ChartColor>[
    ChartColor(Color(0xFF00897B), Color(0xFF009485)),
    ChartColor(Color(0xFFA8801A), Color(0xFFB08B37)),
    ChartColor(Color(0xFF8C2A55), Color(0xFFB85C86)),
  ];

  /// Magnitude. One hue, and the bar's length does the encoding — used wherever
  /// there are more categories than [series] has slots.
  static const sequential = ChartColor(Color(0xFF00897B), Color(0xFF009485));

  /// The track a bar is drawn against: the empty part of the measure.
  static Color track(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);

  /// The colour a gap between two fills is painted in — see the 2px separator
  /// every stacked bar carries, which is what stops two segments of similar
  /// value reading as one.
  static Color gap(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
}

/// One chart colour, as a pair: the step that passes on paper and the step that
/// passes on night. Same shape as [Accent], and for the same reason — a single
/// value cannot clear both backdrops.
class ChartColor {
  const ChartColor(this.onLight, this.onDark);

  final Color onLight;
  final Color onDark;

  Color of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? onDark : onLight;
}
