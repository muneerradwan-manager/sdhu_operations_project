import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../application/evaluations_cubit.dart';
import '../data/evaluations_repository.dart';
import '../domain/evaluation.dart';
import 'evaluation_sheet_screen.dart';
import 'widgets/evaluation_card.dart';
import 'widgets/evaluation_labels.dart';
import 'widgets/score_bar.dart';

/// The register, asked one of two ways.
///
/// [EvaluationsScope.mine] is عام ← التقييمات and is everybody's: it lists the
/// errands this person was given, and nothing else — being allowed to read every
/// evaluation does not make every evaluation yours to fill.
/// [EvaluationsScope.all] is الإدارة ← سجل التقييمات and asks for
/// `evaluations.view`; the server refuses the wider question to anyone who may
/// not ask it, so the screen does not have to be trusted to hide it.
///
/// And the two are drawn differently, because they are asked differently. A
/// person's own list is one card per errand — each is a separate thing he must
/// go and do. The register is one card per THING UNDER JUDGEMENT: two files put
/// up for appraisal before twenty people is two cards and not forty, because
/// the office opens this screen to ask how those two files are going, not to
/// count rows. Every evaluator sits inside the card of the subject they were
/// asked about, and their name is the way into their own sheet.
///
/// What was written ABOUT this person is in neither list. That is on their own
/// profile, because it is the one place a man looks for what is being said about
/// him — and because it is read through the one function that redacts.
///
/// And neither list OPENS one. There is no button here to hand out an errand,
/// in either scope: a register is a record of what was done, and a screen that
/// both records the work and issues it is two rooms with one door. Opening an
/// evaluation happens in إدارة التقييم, standing on the form it will be filled
/// on — which is also the order the act really has, since the form settles what
/// kind of thing may be named next.
class EvaluationsScreen extends StatelessWidget {
  const EvaluationsScreen({
    super.key,
    this.scope = EvaluationsScope.mine,
    this.templateId,
    this.title,
  });

  final EvaluationsScope scope;

  /// Opened from one form, showing only what was issued on it. This is the way
  /// out of the dead end deleting a form used to be: the database refuses while
  /// sheets exist, and until now there was nowhere to go and look at them.
  final String? templateId;

  /// Overrides the app-bar title — the form's name, when opened from a form.
  final String? title;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => EvaluationsCubit(
      EvaluationsRepository(),
      scope: scope,
      templateId: templateId,
    ),
    child: _View(scope: scope, title: title),
  );
}

class _View extends StatelessWidget {
  const _View({required this.scope, this.title});
  final EvaluationsScope scope;
  final String? title;

  Future<void> _delete(
    BuildContext context, {
    required String evaluationId,
    required String label,
  }) async {
    final l = context.l10n;
    final cubit = context.read<EvaluationsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(label),
        content: Text(l.evaluationDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final error = await cubit.delete(evaluationId);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error == null ? l.evaluationDeleted : friendlyErrorL(l, error),
          ),
        ),
      );
  }

  Future<void> _open(
    BuildContext context,
    String evaluationId,
    bool canReopen,
  ) async {
    final cubit = context.read<EvaluationsCubit>();
    await Navigator.of(context).push(
      fadeThroughRoute(
        (_) => EvaluationSheetScreen(
          evaluationId: evaluationId,
          canReopen: canReopen,
        ),
      ),
    );
    // Always, rather than on a returned flag: a sheet can be saved, submitted
    // or reopened in there, and each of the three changes the row behind it —
    // and, in the register, the arithmetic of the card it sat in.
    await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.watch<SessionCubit>().state;
    final mine = scope == EvaluationsScope.mine;
    // Still read, and only for the one thing this screen still does with it:
    // sending a finished sheet back is an act ON a record, so it belongs to the
    // screen that holds the records.
    final canReopen = session.can(PermissionCodes.evaluationsAssign);
    // Deleting a sheet. Drawn for whoever holds the code; the database also
    // lets whoever ISSUED one withdraw it while it is untouched, and that
    // narrower right is left to the server to answer — a card that offers the
    // action and is refused says more than one that silently omits it.
    final canDelete =
        session.can(PermissionCodes.evaluationsDelete) ||
        session.can(PermissionCodes.evaluationsAssign);

    return Scaffold(
      appBar: GlassAppBar(
        title: Text(
          title ?? (mine ? l.evaluationsMineTitle : l.evaluationsTitle),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<EvaluationsCubit, EvaluationsState>(
          builder: (context, state) {
            final cubit = context.read<EvaluationsCubit>();

            if (state.status == EvaluationsStatus.loading) {
              return ResponsivePage(
                builder: (context, size) => SkeletonList(
                  height: 168,
                  padding: context.scrollPadding(
                    horizontal: size.gutter,
                    bottom: AppSpacing.xl,
                  ),
                ),
              );
            }
            if (state.status == EvaluationsStatus.error) {
              return EmptyState(
                icon: AppIcons.evaluations,
                title: friendlyError(context, state.error),
                action: FilledButton(
                  onPressed: cubit.load,
                  child: Text(l.commonRetry),
                ),
              );
            }

            final subjects = state.visibleSubjects;
            final visible = state.visible;
            final isEmpty = state.isGrouped ? subjects.isEmpty : visible.isEmpty;

            return Column(
              children: [
                _FilterBar(state: state),
                Expanded(
                  child: isEmpty
                      ? EmptyState(
                          icon: AppIcons.evaluations,
                          title: state.isNarrowed
                              ? l.evaluationsNoMatches
                              : (mine
                                    ? l.evaluationsEmpty
                                    : l.evaluationsEmptyAll),
                          // No way in from here either. An empty register is
                          // answered in إدارة التقييم, on the form the first
                          // evaluation will be opened against.
                          message: !mine && !state.isNarrowed
                              ? l.evaluationsOpenFromForms
                              : null,
                        )
                      : ResponsivePage(
                          builder: (context, size) => AdaptiveGridView(
                            padding: EdgeInsets.fromLTRB(
                              size.gutter,
                              AppSpacing.sm,
                              size.gutter,
                              AppSpacing.xl +
                                  MediaQuery.viewPaddingOf(context).bottom,
                            ),
                            onRefresh: cubit.load,
                            spacing: AppSpacing.md,
                            // A subject card grows when it is opened, and
                            // stretching every other card to match the one
                            // somebody expanded is the wrong answer to that.
                            equalHeights: !state.isGrouped,
                            itemCount: state.isGrouped
                                ? subjects.length
                                : visible.length,
                            itemBuilder: (context, i) => FadeSlideIn(
                              delay: Duration(
                                milliseconds: 25 * (i < 8 ? i : 8),
                              ),
                              child: state.isGrouped
                                  ? _SubjectCard(
                                      key: ValueKey(subjects[i].key),
                                      subject: subjects[i],
                                      onOpen: (member) => _open(
                                        context,
                                        member.id,
                                        canReopen,
                                      ),
                                      onDelete: canDelete
                                          ? (member) => _delete(
                                              context,
                                              evaluationId: member.id,
                                              label:
                                                  member.evaluatorName ??
                                                  subjects[i].templateTitle,
                                            )
                                          : null,
                                    )
                                  : EvaluationCard(
                                      evaluation: visible[i],
                                      showEvaluator: !mine,
                                      onOpen: () => _open(
                                        context,
                                        visible[i].id,
                                        canReopen,
                                      ),
                                      onDelete: !mine && canDelete
                                          ? () => _delete(
                                              context,
                                              evaluationId: visible[i].id,
                                              label:
                                                  visible[i].targetLabel ??
                                                  visible[i].templateTitle,
                                            )
                                          : null,
                                    ),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One thing under judgement: what it is, how the judging is going, what it has
/// come to, and everyone who was asked.
///
/// The evaluators are folded away until asked for. Twenty names is the whole
/// screen, and the reason somebody scans this list is to find the file, not the
/// twentieth name under the third file. Opened, each name leads into that
/// person's own sheet — which is the only place a single verdict can honestly
/// be read.
class _SubjectCard extends StatefulWidget {
  const _SubjectCard({
    super.key,
    required this.subject,
    required this.onOpen,
    this.onDelete,
  });

  final EvaluationSubject subject;
  final void Function(EvaluationSubjectMember member) onOpen;

  /// Null where deleting is not this reader's to do. Kept reachable from here
  /// deliberately: a form refuses to be deleted while sheets stand on it, and
  /// this card is where those sheets are seen and removed.
  final void Function(EvaluationSubjectMember member)? onDelete;

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = widget.subject;

    final subject = (s.targetLabel ?? '').trim().isEmpty
        ? evaluationTargetLabel(l, s.target)
        : s.targetLabel!;
    final late = s.overdueCount > 0;
    final tone = late ? scheme.error : scheme.primary;
    final hairline = scheme.outlineVariant.withValues(alpha: 0.4);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The kind's glyph, seated in a tinted frame rather than floating
              // loose — the same treatment [InfoRow] gives its icons, so the
              // register speaks the app's language instead of its own.
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: tone.withValues(alpha: 0.18)),
                ),
                child: Icon(
                  evaluationTargetIcon(s.target),
                  size: 22,
                  color: tone,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // The kind and the form's name second, in the smaller
                    // type, as one quiet line: the same file appraised on two
                    // papers is two cards, and the paper is what tells them
                    // apart. As text and not a badge — it is identity, not
                    // status, and only status earns a colour.
                    Text(
                      '${evaluationTargetLabel(l, s.target)} · ${s.templateTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // The average is the one number the office opened this screen
              // for, so it is the card's one featured figure — a ring, not a
              // pill lost among pills.
              if (s.hasMarks) ...[
                const SizedBox(width: AppSpacing.md),
                _AverageRing(percent: s.averagePercent!),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // How far the judging has gotten — sheets finished out of sheets
          // asked for, and never a mark. A mark taken over half the verdicts
          // is not a smaller version of the answer, it is a different one.
          Row(
            children: [
              Expanded(
                child: Text(
                  l.evaluationSubjectProgressLabel,
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                l.evaluationProgress(s.submittedCount, s.totalCount),
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: late ? scheme.error : scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: s.progress,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              valueColor: AlwaysStoppedAnimation(
                late ? scheme.error : scheme.secondary,
              ),
            ),
          ),
          // The spread, once there is one. A single finished sheet has no
          // highest and lowest distinct from its average, and three copies of
          // one number is decoration pretending to be information.
          if (s.hasMarks && s.submittedCount > 1) ...[
            const SizedBox(height: AppSpacing.md),
            _SpreadStrip(
              best: s.bestPercent!,
              worst: s.worstPercent!,
              hairline: hairline,
            ),
          ],
          // Pills only for what needs acting on. Overdue outranks a due date
          // still ahead; a card with nothing exceptional carries no pill.
          if (late || (s.dueOn != null && s.openCount > 0) || !s.hasMarks) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (!s.hasMarks)
                  GlassBadge(
                    label: l.evaluationSubjectNoMarks,
                    icon: AppIcons.pending,
                    color: scheme.tertiary,
                    dense: true,
                  ),
                if (late)
                  GlassBadge(
                    label: l.evaluationsOverdueCount(s.overdueCount),
                    icon: AppIcons.warning,
                    color: scheme.error,
                    dense: true,
                  )
                else if (s.dueOn != null && s.openCount > 0)
                  GlassBadge(
                    label: l.evaluationDueOn(formatDate(s.dueOn)),
                    icon: AppIcons.seasons,
                    color: scheme.onSurfaceVariant,
                    dense: true,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: hairline),
          // The way into the names. A row rather than a chevron in the header,
          // because it says how many are behind it before it is pressed — and
          // shows the first faces, so a closed card already says who.
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  _AvatarStack(members: s.evaluators),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l.evaluationSubjectEvaluators(s.evaluators.length),
                      style: text.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Grows and shrinks rather than snapping — a card that jumps a
          // screenful open reads as broken, not opened.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      for (var i = 0; i < s.evaluators.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 48,
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        _MemberRow(
                          member: s.evaluators[i],
                          onOpen: () => widget.onOpen(s.evaluators[i]),
                          onDelete: widget.onDelete == null
                              ? null
                              : () => widget.onDelete!(s.evaluators[i]),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The average over the finished sheets, drawn as a ring with the number
/// inside — the one figure on the card allowed to be loud.
///
/// The colour is the mark's own three bands, from [ScoreBar.colorFor], so 62%
/// is the same amber here as it is everywhere else a mark is shown.
class _AverageRing extends StatelessWidget {
  const _AverageRing({required this.percent});

  /// Out of a hundred, as [EvaluationSubject.averagePercent] holds it.
  final double percent;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tone = ScoreBar.colorFor(scheme, percent / 100);

    // The ring carries its meaning in an angle and a colour; a reader who
    // gets neither is told the number and what it is.
    return Semantics(
      label: l.evaluationsAboutAverage(formatMark(percent)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: (percent / 100).clamp(0.0, 1.0),
                  strokeWidth: 4,
                  strokeCap: StrokeCap.round,
                  backgroundColor: scheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  valueColor: AlwaysStoppedAnimation(tone),
                ),
                Center(
                  child: Text(
                    l.evaluationPercent(formatMark(percent)),
                    style: text.labelSmall?.copyWith(
                      fontSize: 10.5,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: tone,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            l.evaluationStatAverage,
            style: text.labelSmall?.copyWith(
              fontSize: 9.5,
              height: 1,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The highest and lowest finished marks, side by side in a quiet well —
/// numbers over captions, ruled apart, instead of two more pills in the pile.
class _SpreadStrip extends StatelessWidget {
  const _SpreadStrip({
    required this.best,
    required this.worst,
    required this.hairline,
  });

  final double best;
  final double worst;
  final Color hairline;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(caption: l.evaluationStatBest, percent: best),
          ),
          SizedBox(height: 28, child: VerticalDivider(width: 1, color: hairline)),
          Expanded(
            child: _Stat(caption: l.evaluationStatWorst, percent: worst),
          ),
        ],
      ),
    );
  }
}

/// One number over its caption, coloured by the mark's own band.
class _Stat extends StatelessWidget {
  const _Stat({required this.caption, required this.percent});

  final String caption;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          l.evaluationPercent(formatMark(percent)),
          style: text.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: ScoreBar.colorFor(scheme, percent / 100),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The first few evaluators' faces, overlapped the way a team is drawn
/// everywhere — enough to say "people are behind this row" before it is
/// opened, without spending a line per name.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.members});

  final List<EvaluationSubjectMember> members;

  static const _size = 26.0;
  static const _overlap = 17.0;
  static const _shownMax = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = members.length > _shownMax ? _shownMax : members.length;
    if (shown == 0) {
      return Icon(AppIcons.employees, size: 18, color: scheme.onSurfaceVariant);
    }

    return SizedBox(
      height: _size,
      width: _size + _overlap * (shown - 1),
      child: Stack(
        children: [
          // Painted last-to-first so the first face sits on top of the pile,
          // each ringed in the surface colour to keep the edges legible.
          for (var i = shown - 1; i >= 0; i--)
            PositionedDirectional(
              start: i * _overlap,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface,
                ),
                child: ProfileAvatar(
                  photoUrl: members[i].evaluatorPhotoUrl,
                  name: members[i].evaluatorName,
                  radius: (_size - 3) / 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One evaluator inside a subject's card: who they are, where they got to, and
/// the way into their sheet.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.onOpen,
    this.onDelete,
  });

  final EvaluationSubjectMember member;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // The status line under the name: finished sheets say when, unfinished
    // ones say what they are, and late ones say so in the error colour.
    final status = member.isOverdue
        ? l.evaluationOverdue
        : member.isSubmitted
        ? (member.submittedAt == null
              ? l.evaluationStatusSubmitted
              : '${l.evaluationStatusSubmitted} · ${formatDate(member.submittedAt)}')
        : l.evaluationStatusDraft;

    // What this one person's sheet has come to: a finished mark wears its
    // band's colour in a chip, a finished questionnaire a plain tick, and an
    // unfinished sheet says how far in — and never a mark.
    final Widget trailing;
    if (member.isSubmitted && member.percent != null) {
      final tone = ScoreBar.colorFor(scheme, member.percent! / 100);
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: tone.withValues(alpha: 0.28)),
        ),
        child: Text(
          l.evaluationPercent(formatMark(member.percent!)),
          style: text.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: tone,
          ),
        ),
      );
    } else if (member.isSubmitted) {
      trailing = Icon(AppIcons.approve, size: 18, color: scheme.primary);
    } else {
      trailing = Text(
        l.evaluationProgress(member.answeredCount, member.questionCount),
        style: text.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: member.isOverdue ? scheme.error : scheme.onSurfaceVariant,
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            ProfileAvatar(
              photoUrl: member.evaluatorPhotoUrl,
              name: member.evaluatorName,
              radius: 18,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (member.evaluatorName ?? '').trim().isEmpty
                        ? l.evaluationEvaluator
                        : member.evaluatorName!,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: member.isOverdue
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            trailing,
            if (onDelete != null)
              PopupMenuButton<int>(
                icon: const Icon(AppIcons.more),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 0, child: Text(l.evaluationDelete)),
                ],
                onSelected: (_) => onDelete!(),
              )
            else
              const Padding(
                padding: EdgeInsetsDirectional.only(start: AppSpacing.sm),
                child: NavChevron(),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.state});
  final EvaluationsState state;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  late final _controller = TextEditingController(text: widget.state.query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<EvaluationsCubit>();
    final scheme = Theme.of(context).colorScheme;
    final s = widget.state;

    // Only the kinds actually present. Offering all seven over a list of two
    // sheets is a menu of dead ends.
    final kinds = s.kinds;

    return SearchFilterBar(
      hint: l.evaluationsSearchHint,
      controller: _controller,
      onChanged: cubit.search,
      filters: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // What is still owed, said once and above the filters — it is the
          // reason somebody opened this screen, and it must not be a number
          // they have to count off the cards.
          if (s.openCount > 0) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                GlassBadge(
                  label: l.evaluationsOpenCount(s.openCount),
                  icon: AppIcons.pending,
                  color: scheme.tertiary,
                  dense: true,
                ),
                if (s.overdueCount > 0)
                  GlassBadge(
                    label: l.evaluationsOverdueCount(s.overdueCount),
                    icon: AppIcons.warning,
                    color: scheme.error,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (kinds.length > 1 || s.isNarrowed)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: Text(l.evaluationsFilterAll),
                  selected: s.target == null && s.filterStatus == null,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => cubit.clearFilters(),
                ),
                ChoiceChip(
                  label: Text(l.evaluationStatusDraft),
                  selected: s.filterStatus == EvaluationStatus.draft,
                  visualDensity: VisualDensity.compact,
                  onSelected: (on) =>
                      cubit.setStatus(on ? EvaluationStatus.draft : null),
                ),
                ChoiceChip(
                  label: Text(l.evaluationStatusSubmitted),
                  selected: s.filterStatus == EvaluationStatus.submitted,
                  visualDensity: VisualDensity.compact,
                  onSelected: (on) =>
                      cubit.setStatus(on ? EvaluationStatus.submitted : null),
                ),
                for (final kind in EvaluationTarget.values)
                  if (kinds.contains(kind))
                    ChoiceChip(
                      label: Text(evaluationTargetLabel(l, kind)),
                      selected: s.target == kind,
                      visualDensity: VisualDensity.compact,
                      onSelected: (on) => cubit.setTarget(on ? kind : null),
                    ),
                if (s.isNarrowed)
                  TextButton.icon(
                    onPressed: () {
                      _controller.clear();
                      cubit.clearFilters();
                    },
                    icon: const Icon(AppIcons.reject, size: 16),
                    label: Text(l.moduleRosterClear),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
