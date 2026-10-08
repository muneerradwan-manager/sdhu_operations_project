import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';

import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/responsive.dart';
import '../../modules/domain/assignable_employee.dart';
import '../../modules/presentation/employee_picker_screen.dart';
import '../application/assign_evaluation_cubit.dart';
import '../data/evaluations_repository.dart';
import '../domain/evaluation.dart';
import 'evaluation_targets_picker_screen.dart';
import 'widgets/evaluation_labels.dart';

/// What one batch of assignments came to: how many errands were opened, and the
/// first of them so the caller can offer a way in.
///
/// The id rather than a bare `true`, because both callers stand on a screen
/// that is not the register: whoever just issued errands has no way to see that
/// they exist, and "it was saved" with nowhere to look is the complaint this
/// answers. The count, because one and thirty-three are different news.
typedef AssignedEvaluations = ({String firstId, int count});

/// Pushes the page and answers with what it opened, or null if nothing was.
Future<AssignedEvaluations?> openAssignEvaluation(
  BuildContext context, {
  required String templateId,
}) {
  return Navigator.of(context).push<AssignedEvaluations>(
    fadeThroughRoute((_) => AssignEvaluationScreen(templateId: templateId)),
  );
}

/// Opening one: the paper, the subject, the person who fills it.
///
/// In that order, and the order is the design. The form decides what kind of
/// thing may be named next — a form written for hotels cannot be pointed at an
/// employee — so asking for the subject first would mean either offering all
/// seven kinds and then throwing the answer away, or guessing.
///
/// [templateId] settles the paper before the screen appears, which is how it is
/// always reached now: إدارة التقييم owns this act, and it is issued while
/// standing on the form it will be filled on. The register issues nothing.
///
/// Opened from a page that already knows its subject — an employee's, a file's
/// — [target] and [targetId] come in settled too, and that question is not
/// asked twice either.
class AssignEvaluationScreen extends StatelessWidget {
  const AssignEvaluationScreen({
    super.key,
    this.templateId,
    this.target,
    this.targetId,
    this.targetName,
  });

  final String? templateId;
  final EvaluationTarget? target;
  final String? targetId;
  final String? targetName;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AssignEvaluationCubit(
      EvaluationsRepository(),
      templateId: templateId,
      target: target,
      targetId: targetId,
      targetName: targetName,
    ),
    child: _View(
      formLocked: templateId != null,
      locked: target != null && targetId != null,
    ),
  );
}

class _View extends StatelessWidget {
  const _View({required this.formLocked, required this.locked});

  /// The form arrived with the screen — the ordinary case.
  final bool formLocked;

  /// The subject arrived with the screen and is not the reader's to change.
  final bool locked;

  Future<void> _submit(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<AssignEvaluationCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final ids = await cubit.submit();
    if (ids.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(friendlyErrorL(l, cubit.state.error))),
        );
      return;
    }
    // The snackbar is raised by whoever pushed this page, not here: it is shown
    // AFTER the pop, on the screen the reader lands on, and it carries a way in
    // to what was just created.
    navigator.pop((firstId: ids.first, count: ids.length));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: GlassAppBar(title: Text(l.evaluationAssignTitle)),
      body: SafeArea(
        child: BlocBuilder<AssignEvaluationCubit, AssignEvaluationState>(
          builder: (context, state) => ResponsivePage(
            width: PageWidth.form,
            builder: (context, size) => SinglePaneLayout(
              gutter: size.gutter,
              children: [
                _FormSection(state: state, locked: formLocked),
                if (state.form != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  if (state.needsTarget) ...[
                    _SubjectSection(state: state, locked: locked),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _EvaluatorSection(state: state),
                  const SizedBox(height: AppSpacing.lg),
                  _ErrandSection(state: state),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BlocBuilder<AssignEvaluationCubit, AssignEvaluationState>(
        builder: (context, state) => GlassSurface(
          radius: 0,
          strong: true,
          shadow: false,
          bordered: false,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // How many this will actually open, before it opens them.
                  // Three judges over eleven files is thirty-three sheets, and
                  // thirty-three is a number somebody should see while their
                  // thumb is still over the button.
                  Text(
                    l.evaluationAssignPlanned(state.plannedCount),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  if (state.needsTarget &&
                      state.plannedCount > 1 &&
                      state.evaluators.length > 1)
                    Text(
                      l.evaluationAssignCross(
                        state.pickedTargets.length,
                        state.evaluators.length,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: state.canSubmit ? () => _submit(context) : null,
                    icon: state.status == AssignEvaluationStatus.sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(AppIcons.send),
                    label: Text(l.evaluationAssignSubmit),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Which paper. Active forms only — a retired one may be finished and never
/// started, and the database says so, so offering one here would be an offer
/// followed by a refusal.
class _FormSection extends StatelessWidget {
  const _FormSection({required this.state, required this.locked});
  final AssignEvaluationState state;

  /// The form was settled before the screen opened, so it is stated rather than
  /// offered — a dropdown with one entry and no alternative is a control that
  /// only looks like a decision.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<AssignEvaluationCubit>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.evaluationAssignForm, style: text.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (state.status == AssignEvaluationStatus.loading &&
              state.forms.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (state.forms.isEmpty)
            Text(
              l.evaluationAssignNoForms,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            )
          else if (locked && state.form != null)
            Text(state.form!.title, style: text.bodyLarge)
          else
            DropdownButtonFormField<String>(
              initialValue: state.form?.id,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.evaluationAssignPickForm,
                prefixIcon: const Icon(AppIcons.evaluationForms),
              ),
              items: [
                for (final form in state.forms)
                  DropdownMenuItem(
                    value: form.id,
                    child: Text(form.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                cubit.pickForm(state.forms.firstWhere((f) => f.id == value));
              },
            ),
          if (state.form != null) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                GlassBadge(
                  label: evaluationTargetLabel(l, state.form!.target),
                  icon: evaluationTargetIcon(state.form!.target),
                  dense: true,
                ),
                GlassBadge(
                  label: l.evaluationFormQuestions(state.form!.questionCount),
                  dense: true,
                ),
                GlassBadge(
                  label: l.evaluationFormTotal(
                    formatMark(state.form!.totalPoints),
                  ),
                  icon: AppIcons.evaluationScore,
                  dense: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Which subjects — several of them.
///
/// A page rather than the dropdown this used to be, for the reason the
/// evaluator's picker is a page: an office names the eleven files it wants
/// appraised, and eleven is not a thing a dropdown collects.
class _SubjectSection extends StatelessWidget {
  const _SubjectSection({required this.state, required this.locked});
  final AssignEvaluationState state;

  /// The subject arrived with the screen and is not the reader's to change.
  final bool locked;

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<AssignEvaluationCubit>();
    final picked = await showEvaluationTargetsPicker(
      context,
      target: state.target!,
      selected: state.pickedTargets,
    );
    if (picked != null) cubit.pickTargets(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<AssignEvaluationCubit>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.evaluationAssignSubjects, style: text.titleMedium),
              ),
              if (!locked)
                TextButton.icon(
                  onPressed: () => _pick(context),
                  icon: const Icon(AppIcons.add, size: 18),
                  label: Text(l.evaluationAssignAddMore),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.pickedTargets.isEmpty)
            if (locked)
              Text(l.evaluationAssignPickSubjects, style: text.bodySmall)
            else
              OutlinedButton.icon(
                onPressed: () => _pick(context),
                icon: Icon(evaluationTargetIcon(state.target!), size: 18),
                label: Text(l.evaluationAssignPickSubjects),
              )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final option in state.pickedTargets)
                  InputChip(
                    avatar: Icon(evaluationTargetIcon(state.target!), size: 16),
                    label: Text(
                      option.name.isEmpty ? '\u2014' : option.name,
                    ),
                    visualDensity: VisualDensity.compact,
                    // Removing one from the row it stands in, rather than by
                    // reopening the picker to hunt for it and untick it.
                    onDeleted: locked
                        ? null
                        : () => cubit.pickTargets([
                            for (final t in state.pickedTargets)
                              if (t.id != option.id) t,
                          ]),
                  ),
              ],
            ),
          // A read that failed, said beside the control it belongs to. The
          // picker reports its own failures; this is the one that happened
          // before it was ever opened.
          if (state.targetsError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(AppIcons.warning, size: 18, color: scheme.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    friendlyError(context, state.targetsError),
                    style: text.bodySmall?.copyWith(color: scheme.error),
                  ),
                ),
                TextButton(
                  onPressed: cubit.retryTargets,
                  child: Text(l.commonRetry),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Who fills them — chosen on the same page the mission uses to put people into
/// operational files, and for the same reasons.
///
/// A dropdown was wrong here in three ways, and the third is the one that
/// matters. It had no search, over a list that is the whole mission. It showed
/// a name and a post and nothing else. And it hid the one fact an office
/// actually weighs when handing out an appraisal: what this person is ALREADY
/// carrying this season. Somebody running two towers and a kitchen is not the
/// man to give a fourth errand to, and that has to be visible while choosing
/// rather than discovered a week later.
///
/// So it reuses [showMultiEmployeePicker] outright rather than growing a
/// second, poorer copy of it. Which also means the pool is this season's
/// participants — the same people who may be put into a file — and not every
/// approved account that ever existed.
class _EvaluatorSection extends StatelessWidget {
  const _EvaluatorSection({required this.state});
  final AssignEvaluationState state;

  Future<void> _pick(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<AssignEvaluationCubit>();
    final seasonId = state.seasonId;
    if (seasonId == null) return;

    final picked = await showMultiEmployeePicker(
      context,
      title: l.evaluationAssignEvaluators,
      seasonId: seasonId,
      selected: state.evaluators,
    );
    if (picked != null) cubit.pickEvaluators(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.evaluationAssignEvaluators,
                  style: text.titleMedium,
                ),
              ),
              if (state.seasonId != null && state.evaluators.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _pick(context),
                  icon: const Icon(AppIcons.add, size: 18),
                  label: Text(l.evaluationAssignAddMore),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // The season could not be read, so the picker cannot be opened: it
          // searches within a season by nature. Said rather than left as a
          // button that does nothing.
          if (state.seasonId == null)
            Text(
              l.evaluationAssignNoSeason,
              style: text.bodySmall?.copyWith(color: scheme.error),
            )
          else if (state.evaluators.isEmpty)
            OutlinedButton.icon(
              onPressed: () => _pick(context),
              icon: const Icon(AppIcons.addUser, size: 18),
              label: Text(l.evaluationAssignPickEvaluators),
            )
          else
            for (final person in state.evaluators)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _PickedEvaluator(
                  person: person,
                  onRemove: () => context
                      .read<AssignEvaluationCubit>()
                      .removeEvaluator(person.profile.id),
                ),
              ),
          // Said before the errand is sent, not after: whether the person being
          // judged will learn who judged them is the fact that decides how
          // frankly the form gets filled.
          if (state.target == EvaluationTarget.employee) ...[
            const SizedBox(height: AppSpacing.md),
            GlassSurface(
              subtle: true,
              blur: false,
              shadow: false,
              bordered: false,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.shield, size: 18, color: scheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l.evaluationAssignAnonymousNote,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One chosen evaluator, drawn the way the picker drew them — the face, the
/// post, and what they are already carrying. Repeated here rather than reduced
/// to a name, because the reason the picker shows those files is the reason the
/// person who chose should still be able to see them while writing the note.
class _PickedEvaluator extends StatelessWidget {
  const _PickedEvaluator({required this.person, required this.onRemove});

  final AssignableEmployee person;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final profile = person.profile;
    final jobTitle = profile.jobTitleName?.of(context) ?? '';

    return GlassSurface(
      subtle: true,
      blur: false,
      shadow: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                photoUrl: profile.photoUrl,
                name: profile.fullName,
                radius: 22,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName.isEmpty ? '\u2014' : profile.fullName,
                      style: text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (jobTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        jobTitle,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: l.commonDelete,
                onPressed: onRemove,
                icon: Icon(AppIcons.reject, size: 18, color: scheme.error),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (person.files.isEmpty)
            Text(
              l.modulePickerFree,
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            Text(
              l.modulePickerAlreadyIn(person.files.length),
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final file in person.files)
                  GlassBadge(
                    label: file.name.of(context),
                    icon: AppIcons.modules,
                    dense: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// What to look at, and by when. Both optional, and the deadline is enforced by
/// nobody: a due date that locks the form loses the appraisal instead of the
/// deadline. It is shown on the card and nowhere else.
class _ErrandSection extends StatefulWidget {
  const _ErrandSection({required this.state});
  final AssignEvaluationState state;

  @override
  State<_ErrandSection> createState() => _ErrandSectionState();
}

class _ErrandSectionState extends State<_ErrandSection> {
  late final _controller = TextEditingController(text: widget.state.note);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final cubit = context.read<AssignEvaluationCubit>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.state.dueOn ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) cubit.setDueOn(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<AssignEvaluationCubit>();

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onChanged: cubit.setNote,
            decoration: InputDecoration(
              hintText: l.evaluationAssignNoteHint,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(AppIcons.seasons, size: 18),
                  label: Text(
                    widget.state.dueOn == null
                        ? l.evaluationAssignDue
                        : l.evaluationDueOn(formatDate(widget.state.dueOn)),
                  ),
                ),
              ),
              if (widget.state.dueOn != null) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: l.evaluationAssignDueClear,
                  onPressed: () => cubit.setDueOn(null),
                  icon: const Icon(AppIcons.reject, size: 18),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
