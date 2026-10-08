import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../auth/application/session_cubit.dart';
import '../../domain/season_roadmap.dart';
import 'home_pieces.dart';

/// What stands where the tiles were.
///
/// Not a second copy of the rail — that was the first attempt and it was wrong.
/// Moving the doors into a column and then listing the same doors on the page
/// beside it leaves a reader looking at one menu twice, and answers a question
/// the rail had already answered.
///
/// So the page takes the other axis entirely. The rail says WHERE things are;
/// this says WHEN they happen. One season is drawn from the week before it
/// opens to the week after it closes, phase by phase and step by step, each
/// step saying what is done at it and what it is waiting on. See
/// [seasonRoadmap] for the content and for the two rules it is built by.
///
/// It is drawn as a spine rather than as a grid of cards, and that is the whole
/// design. A grid says "here are twenty-four things, in no particular order",
/// which is exactly what this page exists NOT to say. A line running down the
/// page with numbered stops on it says the one thing a roadmap has to say
/// before anything else: that these come in an order, and that the order is the
/// point.
class SeasonRoadmapView extends StatelessWidget {
  const SeasonRoadmapView({super.key, required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = seasonRoadmap(session, l);
    final phases = roadmapPhases(steps);

    // Numbered across the WHOLE map rather than restarted per phase: a step is
    // referred to out loud as "the fourteenth", and a reader who has scrolled
    // past three phases wants to know how far down the season he is, not how
    // far into a band.
    var number = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Intro(open: steps.where((s) => s.open).length, total: steps.length),
        const SizedBox(height: AppSpacing.xl),
        for (final (index, entry) in phases.indexed) ...[
          _PhaseHeader(phase: entry.phase),
          const SizedBox(height: AppSpacing.md),
          for (final step in entry.steps)
            _Step(
              step: step,
              number: ++number,
              // The spine is continuous inside a phase and broken between
              // them: the line stops at the last step of a band so the next
              // phase's heading is not skewered by it.
              first: step == entry.steps.first,
              last: step == entry.steps.last,
            ),
          if (index < phases.length - 1) const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
  }
}

/// What the page is, and how much of it belongs to the reader.
class _Intro extends StatelessWidget {
  const _Intro({required this.open, required this.total});

  /// How many steps this reader may take, of how many there are.
  ///
  /// Printed because it is the fact that keeps the locked steps from reading as
  /// a wall: a man who sees six of twenty-four is being told that this is a map
  /// of the whole season and that six of it is his, rather than that eighteen
  /// things are being kept from him.
  final int open;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.md),
      tint: scheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconMedallion(
                icon: AppIcons.roadmap,
                color: scheme.primary,
                size: 44,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(l.roadmapIntroTitle, style: text.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l.roadmapIntroBody,
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.65,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassBadge(
            label: l.roadmapStepsOpen(open, total),
            color: scheme.primary,
            icon: AppIcons.shield,
          ),
        ],
      ),
    );
  }
}

/// The band that opens a phase: its number, its name, when in the year it
/// happens, and what it is for.
class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({required this.phase});

  final RoadmapPhase phase;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colour = phase.accent.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The phase's number, drawn big enough to be the thing the eye
            // lands on when scrolling past. It is what tells a reader who has
            // jumped into the middle of the page where he is.
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colour.withValues(alpha: 0.34),
                    colour.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(color: colour.withValues(alpha: 0.42)),
              ),
              child: Text(
                '${phase.step}',
                style: text.titleLarge?.copyWith(
                  color: colour,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.roadmapPhaseLabel(phase.step),
                    style: text.labelSmall?.copyWith(
                      color: colour,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(phase.title(l), style: text.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    phase.when(l),
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Indented to the spine, so the paragraph reads as belonging to the
        // band rather than to the page.
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 44 + AppSpacing.md),
          child: Text(
            phase.body(l),
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: AppSpacing.xs),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colour.withValues(alpha: 0.45),
                colour.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The width of the spine column — the numbered stop plus the air around it.
const _spine = 44.0;

/// One stop on the map: the numbered node, the line through it, and the card.
class _Step extends StatelessWidget {
  const _Step({
    required this.step,
    required this.number,
    required this.first,
    required this.last,
  });

  final RoadmapStep step;
  final int number;

  /// Whether the line above this node is drawn, and the one below it. The
  /// spine runs through a phase and stops at both its ends.
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colour = step.phase.accent.of(context);

    return IntrinsicHeight(
      // The spine has to be exactly as tall as the card beside it, and the card
      // is as tall as its own words. This is the same measurement
      // [AdaptiveGrid] makes for a row of panes, and for the same reason.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Spine(
            number: number,
            colour: colour,
            open: step.open,
            first: first,
            last: last,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _StepCard(step: step, colour: colour),
            ),
          ),
        ],
      ),
    );
  }
}

/// The line and the numbered node on it.
class _Spine extends StatelessWidget {
  const _Spine({
    required this.number,
    required this.colour,
    required this.open,
    required this.first,
    required this.last,
  });

  final int number;
  final Color colour;
  final bool open;
  final bool first;
  final bool last;

  /// Where the node's centre sits, measured from the top of the row.
  ///
  /// It has to line up with the first line of text in the card beside it, or
  /// the map reads as a column of numbers that happen to be near some cards.
  /// The card's padding is [AppSpacing.lg] and its title sits on a line about
  /// 22 high, so the middle of that line is 16 + 11.
  static const _nodeCentre = 27.0;
  static const _nodeSize = 30.0;

  @override
  Widget build(BuildContext context) {
    // A step that is not this reader's keeps its place on the line and loses
    // its colour: the season still passes through it, and he still does not.
    final line = colour.withValues(alpha: open ? 0.32 : 0.16);

    return SizedBox(
      width: _spine,
      child: Stack(
        children: [
          // Above the node.
          if (!first)
            PositionedDirectional(
              start: _spine / 2 - 1,
              top: 0,
              height: _nodeCentre - _nodeSize / 2,
              width: 2,
              child: ColoredBox(color: line),
            ),
          // Below it, all the way to the next row.
          if (!last)
            PositionedDirectional(
              start: _spine / 2 - 1,
              top: _nodeCentre + _nodeSize / 2,
              bottom: 0,
              width: 2,
              child: ColoredBox(color: line),
            ),
          PositionedDirectional(
            start: (_spine - _nodeSize) / 2,
            top: _nodeCentre - _nodeSize / 2,
            child: _Node(number: number, colour: colour, open: open),
          ),
        ],
      ),
    );
  }
}

/// The numbered stop itself.
class _Node extends StatelessWidget {
  const _Node({required this.number, required this.colour, required this.open});

  final int number;
  final Color colour;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: _Spine._nodeSize,
      height: _Spine._nodeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Filled where the step is the reader's, hollow where it is not — the
        // difference reads down the whole page at arm's length, before a single
        // word of it.
        color: open
            ? colour.withValues(alpha: 0.22)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.25),
        border: Border.all(
          color: open
              ? colour.withValues(alpha: 0.55)
              : scheme.outlineVariant.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: open
            ? [
                BoxShadow(
                  color: colour.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: open ? colour : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// What is done at this step.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.colour});

  final RoadmapStep step;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      // Tinted only where the step is the reader's. A locked card washed in the
      // phase's colour would look exactly as inviting as the one above it, and
      // then refuse the press.
      tint: step.open ? colour : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: step.open ? () => context.push(step.route) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                step.icon,
                size: 20,
                color: step.open
                    ? colour
                    : scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  step.title,
                  style: text.titleSmall?.copyWith(
                    color: step.open ? null : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (step.open)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.roadmapOpen,
                      style: text.labelMedium?.copyWith(
                        color: colour,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    NavChevron(color: colour),
                  ],
                )
              else
                // Says which it is, in words, rather than leaving the reader to
                // work out why nothing happened when he pressed.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.locked,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      l.roadmapLocked,
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            step.body,
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          // Worth a badge because it is genuinely surprising in an operations
          // app: most of what this software does is gated, and "anybody may say
          // that a coach has broken down" is a decision somebody should be able
          // to see was made rather than have to discover.
          if (step.everyone) ...[
            const SizedBox(height: AppSpacing.md),
            GlassBadge(
              label: l.roadmapEveryone,
              color: colour,
              icon: AppIcons.approve,
              dense: true,
            ),
          ],
          if (step.note case final note?) ...[
            const SizedBox(height: AppSpacing.md),
            _Note(note: note, colour: colour, muted: !step.open),
          ],
        ],
      ),
    );
  }
}

/// The one thing about a step that nothing on the screen behind it would have
/// told you.
///
/// Set in a well rather than as a third paragraph, because it is a different
/// KIND of sentence from the two above it: those describe the step, and this is
/// the thing somebody learned the hard way.
class _Note extends StatelessWidget {
  const _Note({required this.note, required this.colour, required this.muted});

  final String note;
  final Color colour;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = muted ? scheme.onSurfaceVariant : colour;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        // A rule on the reading edge only, and a DIRECTIONAL border to draw it:
        // `Border` names left and right, which would put this rule on the wrong
        // side of the well in one of the app's two languages.
        border: BorderDirectional(
          start: BorderSide(color: tone.withValues(alpha: 0.45), width: 2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.tip, size: 15, color: tone),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              note,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
