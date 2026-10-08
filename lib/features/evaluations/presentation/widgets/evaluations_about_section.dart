import 'package:flutter/material.dart';

import '../../../../core/animations/animations.dart';
import '../../../../core/l10n/error_text.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/info_section.dart';
import '../../data/evaluations_repository.dart';
import '../../domain/evaluation.dart';
import '../evaluation_sheet_screen.dart';
import 'evaluation_labels.dart';
import 'score_bar.dart';

/// What was written about one subject, at the foot of its page.
///
/// Two readers, two questions, one section:
///
///   * **The person themself** ([profileId] null) gets the marks — the form's
///     name, the date and the score, and nothing else. Read through
///     `evaluations_about_me`, which takes no argument and does not select the
///     evaluator's column at all: they see every judgement and never who made
///     it.
///   * **Somebody looking at their page** gets the standing — how many, the
///     average, how many are still being written — plus the sheets themselves,
///     which name their evaluators. Only for a reader holding
///     `evaluations.view`; for anybody else the section is not drawn.
///
/// The difference is not cosmetic. The first list cannot be handed to the
/// second reader without handing over the evaluators with it.
class EvaluationsAboutSection extends StatefulWidget {
  const EvaluationsAboutSection({
    super.key,
    this.profileId,
    this.target = EvaluationTarget.employee,
    this.targetId,
    this.canReadRegister = false,
    this.canReopen = false,
  });

  /// Whose page this is, when it is a person's. Null means "mine", which is the
  /// only case that reads through the redacting door.
  final String? profileId;

  /// A page that is not a person's — a file, a hotel. [targetId] is the row.
  final EvaluationTarget target;
  final String? targetId;

  final bool canReadRegister;
  final bool canReopen;

  bool get isMine => profileId == null && targetId == null;

  String? get _subjectId => profileId ?? targetId;

  @override
  State<EvaluationsAboutSection> createState() =>
      _EvaluationsAboutSectionState();
}

class _EvaluationsAboutSectionState extends State<EvaluationsAboutSection> {
  final _repo = EvaluationsRepository();
  late Future<_About> _future = _load();

  Future<_About> _load() async {
    if (widget.isMine) {
      return _About(mine: await _repo.fetchAboutMe());
    }
    final id = widget._subjectId!;
    final standing = await _repo.fetchStanding(
      target: widget.target,
      targetId: id,
    );
    // The sheets themselves only for a reader who may read them. The standing
    // comes back either way — the server answers it for the subject too, which
    // is what "my own numbers" is read from on a page that is not mine.
    final list = widget.canReadRegister
        ? await _repo.fetchList(all: true, target: widget.target, targetId: id)
        : const <Evaluation>[];
    return _About(standing: standing, list: list);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Somebody else's page and no business with the register: draw nothing
    // rather than an empty box that says so.
    if (!widget.isMine && !widget.canReadRegister) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<_About>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final waiting = snapshot.connectionState == ConnectionState.waiting;

        // Nothing was ever written and nothing is loading — say nothing. An
        // empty "evaluations" heading on a page reads as a judgement in itself.
        if (!waiting &&
            !snapshot.hasError &&
            (data?.isEmpty ?? true) &&
            !widget.isMine) {
          return const SizedBox.shrink();
        }

        return InfoSection(
          title: widget.isMine
              ? l.evaluationsAboutMeTitle
              : l.evaluationsSectionAbout,
          icon: AppIcons.evaluations,
          maxColumns: 1,
          children: [
            if (waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  friendlyError(context, '${snapshot.error}'),
                  style: text.bodySmall,
                ),
              )
            else ...[
              if (data!.standing != null) _Standing(standing: data.standing!),
              if (data.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    l.evaluationsAboutMeEmpty,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              // Mine: the marks, without a name anywhere. And a line saying so
              // — a reader who is not told will look for the name and conclude
              // it is missing rather than withheld.
              if (widget.isMine && data.mine.isNotEmpty) ...[
                for (final e in data.mine)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _MineRow(evaluation: e),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.shield, size: 16, color: scheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l.evaluationsAboutAnonymousNote,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              for (final e in data.list)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: _ManagerRow(
                    evaluation: e,
                    canReopen: widget.canReopen,
                    onChanged: _reload,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// One finished appraisal as its own subject reads it. There is no way in — the
/// questions and the answers belong to the sheet, and the sheet names the man
/// who wrote them.
class _MineRow extends StatelessWidget {
  const _MineRow({required this.evaluation});
  final MyEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(evaluation.templateTitle, style: text.titleSmall),
              ),
              Text(
                l.evaluationSubmittedOn(formatDate(evaluation.submittedAt)),
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ScoreBar(
            score: evaluation.score ?? 0,
            total: evaluation.maxScore ?? 0,
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// One sheet as the office reads it, opening into the whole thing.
class _ManagerRow extends StatelessWidget {
  const _ManagerRow({
    required this.evaluation,
    required this.canReopen,
    required this.onChanged,
  });

  final Evaluation evaluation;
  final bool canReopen;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GlassCard(
      onTap: () async {
        await Navigator.of(context).push(
          fadeThroughRoute(
            (_) => EvaluationSheetScreen(
              evaluationId: evaluation.id,
              canReopen: canReopen,
            ),
          ),
        );
        onChanged();
      },
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(evaluation.templateTitle, style: text.titleSmall),
              ),
              const NavChevron(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (evaluation.isSubmitted)
            ScoreBar(
              score: evaluation.score ?? 0,
              total: evaluation.maxScore ?? 0,
              dense: true,
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              GlassBadge(
                label: evaluation.isSubmitted
                    ? l.evaluationStatusSubmitted
                    : l.evaluationStatusDraft,
                icon: evaluation.isSubmitted
                    ? AppIcons.approve
                    : AppIcons.pending,
                color: evaluation.isSubmitted ? scheme.primary : scheme.tertiary,
                dense: true,
              ),
              // A name is identity, not status — it wears the muted tone.
              if (evaluation.evaluatorName != null)
                GlassBadge(
                  label: evaluation.evaluatorName!,
                  icon: AppIcons.employees,
                  color: scheme.onSurfaceVariant,
                  dense: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The numbers a manager wants before opening anything: how many, how well, and
/// how much is still being written.
class _Standing extends StatelessWidget {
  const _Standing({required this.standing});
  final EvaluationStanding standing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          GlassBadge(
            label: l.evaluationsAboutCount(standing.submittedCount),
            icon: AppIcons.evaluations,
            dense: true,
          ),
          if (standing.averagePercent != null)
            GlassBadge(
              label: l.evaluationsAboutAverage(
                formatMark(standing.averagePercent!),
              ),
              icon: AppIcons.evaluationScore,
              color: ScoreBar.colorFor(
                scheme,
                (standing.averagePercent! / 100).clamp(0.0, 1.0),
              ),
              dense: true,
            ),
          if (standing.pendingCount > 0)
            GlassBadge(
              label: l.evaluationsAboutPending(standing.pendingCount),
              icon: AppIcons.pending,
              color: scheme.tertiary,
              dense: true,
            ),
        ],
      ),
    );
  }
}

class _About {
  const _About({this.standing, this.mine = const [], this.list = const []});

  final EvaluationStanding? standing;
  final List<MyEvaluation> mine;
  final List<Evaluation> list;

  bool get isEmpty =>
      mine.isEmpty && list.isEmpty && (standing?.isEmpty ?? true);
}
