import 'package:flutter/material.dart';

import '../../../../core/theme/glass_tokens.dart';
import 'evaluation_labels.dart';

/// A mark, drawn as a bar and written as a fraction.
///
/// Both, always. The bar is read in a glance and the fraction is what somebody
/// writes down; a bar alone is a feeling about a number and a number alone is
/// four digits nobody compares.
///
/// The colour is the mark's own, on three bands — and the bands are stated here
/// once rather than chosen per screen, so that 62% is the same colour on a
/// person's page as it is at the foot of a hotel's.
class ScoreBar extends StatelessWidget {
  const ScoreBar({
    super.key,
    required this.score,
    required this.total,
    this.label,
    this.dense = false,
  });

  final double score;
  final double total;

  /// Written above the bar. Null on the dense form, which is the one that goes
  /// inside a card that already says what it is.
  final String? label;

  final bool dense;

  /// Null when the form is worth nothing at all — a questionnaire of written
  /// questions is a legitimate form and has no percentage.
  double? get _fraction => total > 0 ? (score / total).clamp(0.0, 1.0) : null;

  /// Green above four fifths, amber above half, red below it. A running total
  /// on a half-filled sheet is red for most of the time it is being filled,
  /// which is why the fill screen shows the fraction and not this colour.
  static Color colorFor(ColorScheme scheme, double fraction) =>
      switch (fraction) {
        >= 0.8 => scheme.primary,
        >= 0.5 => scheme.tertiary,
        _ => scheme.error,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fraction = _fraction;
    final tone = fraction == null
        ? scheme.onSurfaceVariant
        : colorFor(scheme, fraction);

    // The bar carries its meaning in a LENGTH and a COLOUR, and a reader who
    // gets neither is handed a decorated box. Announced as the two numbers it
    // was drawn from — and the colour is deliberately not described: "amber"
    // is a rendering of "above half", and the threshold is the fact.
    return Semantics(
      label: total > 0
          ? '${score.toStringAsFixed(1)} / ${total.toStringAsFixed(1)}'
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (label != null)
                Expanded(
                  child: Text(
                    label!,
                    style: (dense ? text.labelSmall : text.labelMedium)
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                const Spacer(),
              Text(
                formatScore(score, total),
                style: (dense ? text.labelMedium : text.titleSmall)?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (fraction != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${(fraction * 100).round()}%',
                  style: (dense ? text.labelSmall : text.labelMedium)?.copyWith(
                    color: tone,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              // A form worth nothing draws an empty track rather than a full bar:
              // "no marks to give" must not look like "every mark given".
              value: fraction ?? 0,
              minHeight: dense ? 5 : 8,
              backgroundColor: scheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              valueColor: AlwaysStoppedAnimation(tone),
            ),
          ),
        ],
      ),
    );
  }
}
