import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../application/evaluation_forms_cubit.dart';
import '../data/evaluations_repository.dart';
import '../domain/evaluation.dart';
import 'assign_evaluation_screen.dart';
import 'evaluation_editor_screen.dart';
import 'evaluation_sheet_screen.dart';
import 'evaluations_screen.dart';
import '../application/evaluations_cubit.dart';
import 'widgets/evaluation_labels.dart';

/// إدارة التقييم: the forms, and the act of issuing one.
///
/// Two things happen here and they are the two halves of the office's side:
/// writing the paper (`evaluations.templates`) and opening an evaluation on a
/// paper that is written (`evaluations.assign`). The register does neither — it
/// is a record of what was done, and a screen that both records the work and
/// issues it is two rooms with one door.
///
/// Issuing from HERE rather than from the register also puts the act in the
/// order it really has: the form settles what kind of thing may be named next,
/// so standing on the form first means the reader never picks a combination the
/// server would refuse.
class EvaluationFormsScreen extends StatelessWidget {
  const EvaluationFormsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => EvaluationFormsCubit(EvaluationsRepository()),
    child: const _View(),
  );
}

class _View extends StatelessWidget {
  const _View();

  Future<void> _edit(
    BuildContext context, [
    EvaluationFormSummary? form,
  ]) async {
    final cubit = context.read<EvaluationFormsCubit>();
    await Navigator.of(context).push<bool>(
      fadeThroughRoute(
        (_) => EvaluationEditorScreen(
          templateId: form?.id,
          isInUse: form?.isInUse ?? false,
        ),
      ),
    );
    // Unconditionally, and never on a flag the pushed screen returns.
    //
    // The editor guards its back gesture with `PopScope(canPop: !isDirty)`, and
    // a save is exactly what makes it clean — so after a SUCCESSFUL save the
    // framework performs the pop itself, `onPopInvokedWithResult` never runs,
    // and the flag arrives null. The one case the old `if (saved == true)` was
    // written for was the one case it could not catch: the list stayed as it
    // was after every save that worked.
    //
    // Chasing that with a more careful flag is the wrong repair. A screen that
    // can change what this list shows has been open; one read on the way back
    // costs a request, and being wrong costs somebody believing their work was
    // lost.
    await cubit.load();
  }

  /// Opening an evaluation on this form. The form is settled before the screen
  /// appears, so the first thing it asks about is the subject.
  Future<void> _assign(BuildContext context, EvaluationFormSummary form) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<EvaluationFormsCubit>();

    // A form that is switched off takes no new evaluations — the database says
    // so, in `evaluations_resolve_target`. Said here first, because an offer
    // followed by a refusal is worse than no offer.
    if (!form.isActive) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.evaluationFormMustBeActive)));
      return;
    }

    final opened = await openAssignEvaluation(context, templateId: form.id);
    // The count of what is open on this form moved — and unconditionally, for
    // the reason spelled out in _edit above.
    await cubit.load();
    if (opened == null || !context.mounted) return;

    // Where it went. Issuing happens here and the register is somewhere else
    // entirely, so without this a person sends an errand and is left on the
    // same list of forms with nothing to show for it — which reads exactly like
    // nothing happened.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.evaluationAssignedMany(opened.count)),
          action: SnackBarAction(
            label: l.evaluationAssignedShow,
            onPressed: () => Navigator.of(context).push(
              fadeThroughRoute(
                (_) => EvaluationSheetScreen(
                  evaluationId: opened.firstId,
                  canReopen: true,
                ),
              ),
            ),
          ),
        ),
      );
  }

  /// The evaluations issued on this form, and the way out of the dead end.
  ///
  /// Deleting a form is refused by the database while a single sheet stands on
  /// it — `on delete restrict`, and rightly, because the marks written on it are
  /// history. But the refusal used to end the conversation: إدارة التقييم showed
  /// forms and nothing else, so a person was told "there are evaluations on it"
  /// with nowhere to go and see them, let alone remove them.
  Future<void> _openEvaluations(
    BuildContext context,
    EvaluationFormSummary form,
  ) async {
    final cubit = context.read<EvaluationFormsCubit>();
    await Navigator.of(context).push(
      fadeThroughRoute(
        (_) => EvaluationsScreen(
          scope: EvaluationsScope.all,
          templateId: form.id,
          title: form.title,
        ),
      ),
    );
    // Sheets may have been deleted in there, which is what unblocks deleting
    // the form — so the count on this card has to be re-read.
    await cubit.load();
  }

  Future<void> _toggle(
    BuildContext context,
    EvaluationFormSummary form,
    bool active,
  ) async {
    final l = context.l10n;
    final cubit = context.read<EvaluationFormsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final error = await cubit.setActive(form, active);
    if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyErrorL(l, error))));
    }
  }

  Future<void> _delete(BuildContext context, EvaluationFormSummary form) async {
    final l = context.l10n;
    final cubit = context.read<EvaluationFormsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    // Said before the dialog rather than after the refusal: the database will
    // refuse it — `on delete restrict` — and being told why in advance is the
    // difference between a rule and a failure.
    if (form.isInUse) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l.evaluationFormInUseDelete),
            // Not merely "you cannot": here is where they are.
            action: SnackBarAction(
              label: l.evaluationFormShowEvaluations,
              onPressed: () => _openEvaluations(context, form),
            ),
          ),
        );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(form.title),
        content: Text(l.evaluationFormDeleteConfirm),
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

    final error = await cubit.delete(form.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error == null ? l.evaluationFormDeleted : friendlyErrorL(l, error),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.watch<SessionCubit>().state;
    // Both are read here rather than trusted to the route: the door takes
    // either code, so a reader who is only allowed to issue evaluations is
    // standing on this screen with no business editing anything on it.
    final canEdit = session.can(PermissionCodes.evaluationsTemplates);
    final canAssign = session.can(PermissionCodes.evaluationsAssign);

    // Reading the register is its own trust. It no longer decides whether the
    // whole-register door is drawn here — there is none — but it still decides
    // whether a form card may offer to show the sheets standing on IT.
    final canSeeRegister = session.can(PermissionCodes.evaluationsView);

    return Scaffold(
      // No way to the whole register from up here any more.
      //
      // It sat in this app bar on the reasoning that the register only means
      // anything beside the papers it was written from — which is true of ONE
      // form's sheets, and that door is still on every card below. It is not
      // true of the register itself: سجل التقييمات is every sheet on every
      // form, read to see how the season's appraisals are going, and that is
      // oversight work. It belongs on the shelf with the dashboard and the
      // log, which is where it now is — الإدارة ← الإشراف والسجلات.
      appBar: GlassAppBar(title: Text(l.evaluationFormsTitle)),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context),
              icon: const Icon(AppIcons.add),
              label: Text(l.evaluationFormsNew),
            )
          : null,
      body: SafeArea(
        child: BlocBuilder<EvaluationFormsCubit, EvaluationFormsState>(
          builder: (context, state) {
            final cubit = context.read<EvaluationFormsCubit>();

            if (state.status == EvaluationFormsStatus.loading) {
              return ResponsivePage(
                builder: (context, size) => SkeletonList(
                  height: 148,
                  padding: context.scrollPadding(
                    horizontal: size.gutter,
                    bottom: AppSpacing.xl,
                  ),
                ),
              );
            }
            if (state.status == EvaluationFormsStatus.error) {
              return EmptyState(
                icon: AppIcons.evaluationForms,
                title: friendlyError(context, state.error),
                action: FilledButton(
                  onPressed: cubit.load,
                  child: Text(l.commonRetry),
                ),
              );
            }

            final visible = state.visible;
            return Column(
              children: [
                _SearchBar(state: state),
                Expanded(
                  child: visible.isEmpty
                      ? EmptyState(
                          icon: AppIcons.evaluationForms,
                          title: state.isNarrowed
                              ? l.evaluationsNoMatches
                              : l.evaluationFormsEmpty,
                        )
                      : ResponsivePage(
                          builder: (context, size) => AdaptiveGridView(
                            padding: EdgeInsets.fromLTRB(
                              size.gutter,
                              AppSpacing.sm,
                              size.gutter,
                              AppSpacing.xxl * 2 +
                                  MediaQuery.viewPaddingOf(context).bottom,
                            ),
                            onRefresh: cubit.load,
                            spacing: AppSpacing.md,
                            itemCount: visible.length,
                            itemBuilder: (context, i) => FadeSlideIn(
                              delay: Duration(
                                milliseconds: 25 * (i < 8 ? i : 8),
                              ),
                              child: _FormCard(
                                form: visible[i],
                                canEdit: canEdit,
                                canAssign: canAssign,
                                canSeeRegister: canSeeRegister,
                                onShowEvaluations: () =>
                                    _openEvaluations(context, visible[i]),
                                onAssign: () => _assign(context, visible[i]),
                                onOpen: () => _edit(context, visible[i]),
                                onToggle: (v) =>
                                    _toggle(context, visible[i], v),
                                onDelete: () => _delete(context, visible[i]),
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

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.form,
    required this.canEdit,
    required this.canAssign,
    required this.canSeeRegister,
    required this.onShowEvaluations,
    required this.onAssign,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  final EvaluationFormSummary form;

  /// Whoever may write the paper. Without it the card is read-only: the switch,
  /// the menu and the tap-to-edit all go.
  final bool canEdit;

  /// Whoever may issue an evaluation on it.
  final bool canAssign;

  /// Whoever may read the sheets that came of it. Separate from [canAssign]:
  /// issuing an evaluation and reading everyone's answers are two trusts, and
  /// the register is behind the second.
  final bool canSeeRegister;

  final VoidCallback onShowEvaluations;
  final VoidCallback onAssign;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // A form that is switched off is drawn in the muted tone throughout — the
    // whole card says "on the shelf", not just one badge in the pile.
    final tone = form.isActive ? scheme.primary : scheme.onSurfaceVariant;

    return GlassCard(
      // Tapping the card edits it, which is only a thing for whoever may. For a
      // reader who is here to issue evaluations the card is not a door, and the
      // button below is.
      onTap: canEdit ? onOpen : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: tone.withValues(alpha: 0.18)),
                ),
                child: Icon(
                  evaluationTargetIcon(form.target),
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
                      form.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: form.isActive ? null : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // The form's anatomy in one quiet line — what it is about,
                    // how many stages, how many questions. Facts about the
                    // paper are identity, not status, and only status earns a
                    // coloured pill.
                    Text(
                      '${evaluationTargetLabel(l, form.target)}'
                      ' · ${l.evaluationFormStages(form.stageCount)}'
                      ' · ${l.evaluationFormQuestions(form.questionCount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // The switch on the card rather than only inside the editor: it is
              // the difference between a form that may be handed out and one
              // that may not, and it is reached from the list far more often
              // than from the questions.
              if (canEdit) ...[
                Switch(value: form.isActive, onChanged: onToggle),
                // Editing and deleting only.
                //
                // "Show the evaluations" used to sit here too, and it was the
                // third way to the same screen on one card — beside the count
                // badge above and the button below, both of which are visible
                // without opening anything. A menu is where a thing goes when
                // there is nowhere better; two better places already exist.
                PopupMenuButton<int>(
                  icon: const Icon(AppIcons.more),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 0, child: Text(l.commonEdit)),
                    PopupMenuItem(
                      value: 1,
                      child: Text(l.evaluationFormDelete),
                    ),
                  ],
                  onSelected: (v) => switch (v) {
                    0 => onOpen(),
                    _ => onDelete(),
                  },
                ),
              ],
            ],
          ),
          if ((form.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              form.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              GlassBadge(
                label: form.isActive
                    ? l.evaluationFormActive
                    : l.evaluationFormInactive,
                icon: form.isActive ? AppIcons.approve : AppIcons.suspend,
                color: form.isActive ? scheme.primary : scheme.onSurfaceVariant,
                dense: true,
              ),
              GlassBadge(
                label: l.evaluationFormTotal(formatMark(form.totalPoints)),
                icon: AppIcons.evaluationScore,
                color: scheme.secondary,
                dense: true,
              ),
              // Tappable, because it is the answer to the question it raises:
              // "there are four evaluations on this" is only useful if it can
              // show you the four.
              if (form.isInUse)
                InkWell(
                  onTap: onShowEvaluations,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: GlassBadge(
                    label: l.evaluationFormInUse(form.evaluationCount),
                    icon: AppIcons.evaluations,
                    color: scheme.tertiary,
                    dense: true,
                  ),
                ),
            ],
          ),
          // Issuing one, and it is the only place in the app that does. Drawn
          // even when the form is switched off — disabled with the reason said
          // out loud, rather than absent, because a missing button is a
          // question nobody can answer.
          if (canAssign || canSeeRegister) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (canAssign)
                  FilledButton.tonalIcon(
                    onPressed: form.isActive ? onAssign : null,
                    icon: const Icon(AppIcons.add, size: 18),
                    label: Text(l.evaluationsNew),
                  ),
                // Beside "new", and drawn whether or not this form has any
                // sheets yet. The count badge above already opens them, but it
                // only exists once there ARE some — so the moment after
                // writing a form, when a person most wants to look, was the one
                // moment nothing was offered.
                if (canSeeRegister)
                  TextButton.icon(
                    onPressed: onShowEvaluations,
                    icon: const Icon(AppIcons.evaluations, size: 18),
                    label: Text(l.evaluationFormShowEvaluations),
                  ),
              ],
            ),
            if (!form.isActive)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l.evaluationFormMustBeActive,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.state});
  final EvaluationFormsState state;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final _controller = TextEditingController(text: widget.state.query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<EvaluationFormsCubit>();
    final s = widget.state;
    final kinds = <EvaluationTarget>{for (final f in s.forms) f.target};

    return SearchFilterBar(
      hint: l.evaluationFormsSearchHint,
      controller: _controller,
      onChanged: cubit.search,
      filters: kinds.length > 1
          ? Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: Text(l.evaluationsFilterAll),
                  selected: s.target == null,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => cubit.setTarget(null),
                ),
                for (final kind in EvaluationTarget.values)
                  if (kinds.contains(kind))
                    ChoiceChip(
                      label: Text(evaluationTargetLabel(l, kind)),
                      selected: s.target == kind,
                      visualDensity: VisualDensity.compact,
                      onSelected: (on) => cubit.setTarget(on ? kind : null),
                    ),
              ],
            )
          : null,
    );
  }
}
