import 'package:flutter/material.dart';

import '../theme/glass_tokens.dart';

/// Whether the group this indicator belongs to takes one answer or several.
///
/// It decides the SHAPE, and the shape is the promise: a circle takes one — pick
/// another and this one lets go — and a square takes as many as you tick. People
/// read that before they read any label, so it has to be true.
enum SelectionShape { one, many }

/// The state of one option in a group: chosen, or not.
///
/// Drawn rather than picked from an icon font. The two states used to be two
/// glyphs — a tick in a circle against `Iconsax.record`, which is a record
/// button, a filled disc — and at three of the four call sites the unselected
/// one was painted in the PRIMARY colour. So a row nobody had chosen showed a
/// solid green dot, which is what a chosen row is supposed to look like. An
/// empty control has to be visibly empty; that is the whole of its job.
class SelectionIndicator extends StatelessWidget {
  const SelectionIndicator({
    super.key,
    required this.selected,
    this.shape = SelectionShape.one,
    this.size = 22,
  });

  final bool selected;
  final SelectionShape shape;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final circle = shape == SelectionShape.one;

    // Chosen-ness is drawn here as a fill and a tick, and read by nobody: an
    // AnimatedContainer carries no meaning at all to a screen reader, so every
    // picker in the app announced its rows identically whether they were
    // selected or not.
    //
    // `checked` rather than a label, because it is a STATE of the row and not a
    // thing beside it — the platform then says it in its own words and in the
    // reader's own language, which a label written here could not do.
    return Semantics(
      checked: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(size * 0.28),
          // Empty means empty: a hollow ring over a hint of the surface, never a
          // fill and never the accent colour. Filled and coloured is what the
          // chosen one gets, and it must be the only thing that looks like that.
          color: selected
              ? scheme.primary
              : scheme.surface.withValues(alpha: 0.35),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.onSurfaceVariant.withValues(alpha: 0.55),
            width: selected ? 0 : 1.6,
          ),
        ),
        child: Center(
          child: AnimatedScale(
            scale: selected ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            child: circle
                // A radio fills its centre; a checkbox takes a tick. Both in the
                // colour that sits on primary, so the mark reads at any size.
                ? Container(
                    width: size * 0.42,
                    height: size * 0.42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.onPrimary,
                    ),
                  )
                : Icon(
                    Icons.check_rounded,
                    size: size * 0.68,
                    color: scheme.onPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}

/// One option in a group: the indicator, a label, and the whole row as the
/// target — a control this small is not a tap target, the row is.
///
/// The label leans on weight and colour when chosen, so the state survives being
/// read at a glance and does not rest on a mark the size of a fingernail.
class SelectionRow extends StatelessWidget {
  const SelectionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.shape = SelectionShape.one,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final SelectionShape shape;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            SelectionIndicator(selected: selected, shape: shape),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.bodyLarge?.copyWith(
                      color: selected ? scheme.primary : null,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
