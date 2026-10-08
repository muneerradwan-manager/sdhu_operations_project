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
import '../../../core/widgets/overflow_menu.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../application/module_editor_cubit.dart';
import '../data/modules_repository.dart';
import '../domain/module_type.dart';
import '../domain/operational_module.dart';
import 'employee_picker_screen.dart';
import 'widgets/cadence_label.dart';
import 'widgets/module_field_input.dart';
import 'widgets/node_editor_sheet.dart';

/// Where every step of the editor stops widening.
///
/// This screen is a form the whole way through — dates and dropdowns on the
/// first step, then a card per sector, per tower, per team, each of which is a
/// name and a couple of buttons. None of that reads better at seventeen hundred
/// pixels than at eleven, and a date field the width of a monitor is harder to
/// use than one a third of that. The gain here is the gutters and the cap
/// moving with the window, not the content stretching to meet it.
/// Builds one operational file, in the order it is really built. How many steps
/// it takes is the TYPE's answer, not a constant — see [EditorStep]:
///
///   * the file itself — when the work starts, and its attachments — always;
///   * the outermost division, when the type has one: قطاعات, or مراكز;
///   * what sits inside that, when a level does: the hotels of a sector, the
///     camps of a center;
///   * the teams held once for the whole file, when the type has any.
///
/// So قطاعات وأبراج takes three, الطوافة والنقل takes two, and تشكيل فرق المشاعر
/// takes three of a different shape — sectors, then its two file-wide teams,
/// and no towers step at all.
///
/// Each step is saved as it is finished, because a file is assembled over days:
/// the sectors are known long before the last hotel is confirmed. Pops `true`
/// when anything was written.
class ModuleEditorScreen extends StatelessWidget {
  const ModuleEditorScreen({
    super.key,
    required this.moduleTypeId,
    required this.seasonId,
    this.existing,
    this.initialStep = 0,
  });

  final String moduleTypeId;
  final String seasonId;
  final OperationalModule? existing;

  /// Editing an existing file usually means adding towers, not revisiting the
  /// start date — so the caller says where to land.
  final int initialStep;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ModuleEditorCubit(
        ModulesRepository(),
        moduleTypeId: moduleTypeId,
        seasonId: seasonId,
        existing: existing,
      )..goTo(existing == null ? 0 : initialStep),
      child: const _View(),
    );
  }
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  /// Whether anything reached the database, so the screen behind us reloads.
  bool _dirty = false;

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _complaint(SaveResult result) {
    final l = context.l10n;
    return switch (result.outcome) {
      SaveOutcome.ok => l.moduleSaved,
      SaveOutcome.missingDate => '${l.moduleStartDate} — ${l.commonRequired}',
      SaveOutcome.missingField ||
      SaveOutcome.missingEntry ||
      SaveOutcome.missingRole =>
        '${result.name?.of(context) ?? ''} — ${l.commonRequired}',
      SaveOutcome.failed => result.message ?? '',
    };
  }

  Future<void> _next() async {
    final cubit = context.read<ModuleEditorCubit>();
    final state = cubit.state;

    if (state.step == 0) {
      final result = await cubit.saveInfo();
      if (!mounted) return;
      if (result.ok) {
        _dirty = true;
      } else {
        _say(_complaint(result));
      }
      return;
    }
    if (state.step < state.lastStep) {
      cubit.goTo(state.step + 1);
      return;
    }
    Navigator.of(context).pop(_dirty);
  }

  /// Whether this editor may also staff the file. Editing the structure and
  /// putting people on it are two permissions; the server refuses the second
  /// without its code, so the sheet is not opened on a promise it cannot keep.
  bool get _canStaff =>
      context.read<SessionCubit>().state.can(PermissionCodes.modulesMembers);

  /// Puts people on one of the teams of a file that has no tree.
  Future<void> _pickTeam(ModuleRole role) async {
    if (!_canStaff) {
      _say(context.l10n.permissionDenied);
      return;
    }
    final cubit = context.read<ModuleEditorCubit>();

    final result = await showEmployeePicker(
      context,
      title: role.name.of(context),
      seasonId: cubit.seasonId,
      multiple: role.allowsMultiple,
      selected: cubit.state.memberProfileIdsOf(role.id),
    );
    if (result == null || !mounted) return;

    final error = await cubit.setRoleMembers(role.id, result);
    if (!mounted) return;
    if (error != null) {
      _say(error);
      return;
    }
    _dirty = true;
  }

  /// Takes the sectors of another file of this season into this one.
  ///
  /// The same قطاع appears in more than one file — the towers of a sector and
  /// the teams that go out to the المشاعر from it are the same division of the
  /// same people — and entering it twice is how the two files start disagreeing
  /// about who runs it. What arrives is a copy: from here on the two files know
  /// nothing about each other.
  Future<void> _importSectors() async {
    final l = context.l10n;
    final cubit = context.read<ModuleEditorCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final sources = await cubit.sectorSources();
    if (!mounted) return;
    if (sources.isEmpty) {
      _say(l.moduleSectorsImportNoSources);
      return;
    }

    final from = await showModalBottomSheet<String>(
      context: context,
      // Over the rail as well as the page — see [showAppSheet].
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                l.moduleSectorsImportPick,
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final source in sources)
              ListTile(
                leading: const Icon(AppIcons.modules),
                title: Text(source.moduleTypeName?.of(sheetContext) ?? '—'),
                onTap: () => Navigator.of(sheetContext).pop(source.id),
              ),
          ],
        ),
      ),
    );
    if (from == null || !mounted) return;

    final copied = await cubit.importSectorsFrom(from);
    if (copied != null && copied > 0) _dirty = true;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            copied == null
                ? l.moduleSectorsImportFailed
                : l.moduleSectorsImported(copied),
          ),
        ),
      );
  }

  /// Adds or edits a sector (no [parent]) or a hotel inside one.
  Future<void> _editNode(
    ModuleLevel level, {
    ModuleNode? node,
    ModuleNode? parent,
  }) async {
    final cubit = context.read<ModuleEditorCubit>();
    final state = cubit.state;

    final draft = await showNodeEditorSheet(
      context,
      level: level,
      seasonId: cubit.seasonId,
      employees: state.employees,
      referenceSet: state.referenceSetById(level.referenceSetId),
      secondarySet: state.referenceSetById(level.secondaryReferenceSetId),
      hotelsSet: state.hotelsSet,
      referenceSets: state.referenceSets,
      takenEntries: state.takenEntries(level.id, except: node?.id),
      takenSecondaryEntries: state.takenSecondaryEntries(
        level.id,
        except: node?.id,
      ),
      suggestedLabel: node != null || !level.isNamedByHand
          ? null
          : context.l10n.moduleNodeSuggestedName(
              level.name.of(context),
              (parent == null
                      ? state.parentNodes.length
                      : state.childrenOf(parent.id).length) +
                  1,
            ),
      existing: node == null
          ? null
          : NodeDraft(
              id: node.id,
              referenceItemId: node.referenceItemId,
              secondaryReferenceItemId: node.secondaryReferenceItemId,
              label: node.label,
              data: node.data,
              roleMembers: {
                for (final role in level.roles)
                  role.id: node.profileIdsOf(role.id),
              },
              housing: {
                for (final role in level.roles) role.id: node.housingOf(role.id),
              },
            ),
    );
    if (draft == null || !mounted) return;

    final result = await cubit.saveNode(
      level: level,
      draft: draft,
      parentId: parent?.id,
    );
    if (!mounted) return;
    if (result.ok) {
      _dirty = true;
    } else {
      _say(_complaint(result));
    }
  }

  Future<void> _deleteNode(
    ModuleLevel level,
    ModuleNode node,
    String name,
  ) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.moduleNodeDelete(level.name.of(context))),
        content: Text(l.moduleNodeDeleteConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await context.read<ModuleEditorCubit>().deleteNode(node.id);
    if (!mounted) return;
    if (error != null) {
      _say(error);
      return;
    }
    _dirty = true;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.watch<ModuleEditorCubit>();
    final state = cubit.state;
    final saving = state.status == EditorStatus.saving;

    // Named by the type rather than counted: a file with no tree has nothing to
    // divide into sectors, one that stops at the sector has no towers step, and
    // one whose roles are held on the file itself ends with its teams.
    // The two tree steps are named by the LEVEL, not by the word "sector": the
    // same two steps divide a file into قطاعات وأبراج, and another into مراكز
    // ومخيمات. A hard-coded label would be wrong on every file but the first.
    final steps = [
      for (final kind in state.stepKinds)
        switch (kind) {
          EditorStep.info => l.moduleStepInfo,
          EditorStep.sectors =>
            state.parentLevel?.name.of(context) ?? l.moduleStepSectors,
          EditorStep.towers =>
            state.childLevel?.name.of(context) ?? l.moduleStepTowers,
          EditorStep.teams => l.moduleStepMembers,
        },
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_dirty);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          // The file has no name of its own — its type names it.
          title: Text(state.type?.name.of(context) ?? l.moduleNew),
          bottom: state.type == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(34),
                  child: _StepBar(
                    steps: steps,
                    current: state.step,
                    // Steps beyond the first need a row to hang off.
                    onTap: state.isCreated ? cubit.goTo : null,
                  ),
                ),
        ),
        body: switch (state.status) {
          EditorStatus.loading => const AppLoader(),
          EditorStatus.error => EmptyState(
            icon: AppIcons.modules,
            title: friendlyError(context, state.error),
          ),
          _ => switch (state.currentStep) {
            EditorStep.info => ModuleInfoStep(state: state),
            EditorStep.sectors => _NodesStep(
              state: state,
              onAdd: (level) => _editNode(level),
              onEdit: (level, node) => _editNode(level, node: node),
              onDelete: _deleteNode,
              onImport: _importSectors,
            ),
            EditorStep.towers => _TowersStep(
              state: state,
              onAdd: (level, parent) => _editNode(level, parent: parent),
              onEdit: (level, node) => _editNode(level, node: node),
              onDelete: _deleteNode,
            ),
            EditorStep.teams => _TeamsStep(
              state: state,
              onPickTeam: _pickTeam,
            ),
          },
        },
        bottomNavigationBar: state.type == null
            ? null
            : GlassSurface(
                radius: 0,
                strong: true,
                shadow: false,
                bordered: false,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        if (state.step > 0) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: saving
                                  ? null
                                  : () => cubit.goTo(state.step - 1),
                              child: Text(l.commonBack),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: saving ? null : _next,
                            icon: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : Icon(
                                    state.step >= state.lastStep
                                        ? AppIcons.approve
                                        : AppIcons.activate,
                                  ),
                            label: Text(
                              state.step >= state.lastStep
                                  ? l.commonDone
                                  : l.commonNext,
                            ),
                          ),
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

/// Which of the three steps we are on. Tappable once the file exists, so an
/// admin coming back to add a hotel jumps straight to the last step.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.steps, required this.current, this.onTap});

  final List<String> steps;
  final int current;
  final void Function(int step)? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                onTap: onTap == null ? null : () => onTap!(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${i + 1}. ${steps[i]}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: i == current
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontWeight: i == current ? FontWeight.w700 : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: i <= current
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Step 1 — when the work starts, and whatever else the type asks of the file
/// as a whole. There is no name to enter: the type is the name.
///
/// Seven controls, and until 0113 they stood in one undivided column inside a
/// single card: two date boxes, a number, a dropdown and a PDF picker, with
/// nothing saying which of them belonged together and nothing to aim at but the
/// scrollbar. What makes a form of that length findable is not fewer fields —
/// every one of these is asked for — but landmarks, so it is laid out as the
/// three questions it actually is:
///
///   * **مدة العمل** — the days the file runs between, and a note beside each;
///   * **القرار والتقارير** — the paperwork that authorises it and what it asks
///     of the people in it;
///   * the type's own fields, which is where a file stops looking like every
///     other file. Absent entirely for a type that asks for nothing further.
///
/// The first two are identical on every type, which is the point: whoever opens
/// the الطوافة file and whoever opens مخيمات منى are answering the same
/// questions in the same order and in the same places.
///
/// The two notes are folded away behind one line until somebody wants them.
/// They are prose, they are optional, and most files are opened without either
/// — two empty multi-line boxes are two thirds of the height of this step spent
/// on the thing least often written.
class ModuleInfoStep extends StatefulWidget {
  const ModuleInfoStep({super.key, required this.state});

  final ModuleEditorState state;

  @override
  State<ModuleInfoStep> createState() => ModuleInfoStepState();
}

class ModuleInfoStepState extends State<ModuleInfoStep> {
  /// Null until somebody presses the line. Until then the notes are open
  /// exactly when there is something in them — coming back to a file that has
  /// a note and being shown a form that does not mention it is how a note gets
  /// overwritten by somebody who never knew it was there.
  bool? _notesOpen;

  Future<void> _pickStart() async {
    final cubit = context.read<ModuleEditorCubit>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.state.startsOn ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) cubit.setStartsOn(picked);
  }

  Future<void> _pickEnd() async {
    final cubit = context.read<ModuleEditorCubit>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.state.endsOn ?? widget.state.startsOn ?? now,
      // Never before the day the work began: the database refuses that pair,
      // and so the picker does not offer it.
      firstDate: widget.state.startsOn ?? DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) cubit.setEndsOn(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final type = state.type!;
    final cubit = context.read<ModuleEditorCubit>();

    final written =
        (state.startNote ?? '').isNotEmpty || (state.endNote ?? '').isNotEmpty;
    final notesOpen = _notesOpen ?? written;

    return ResponsivePage(
      width: PageWidth.editor,
      builder: (context, size) => SinglePaneLayout(
        gutter: size.gutter,
        children: staggered([
          // The two dates, each above its own note, which is what puts the
          // start and the end in a column apiece where there is room for two
          // and keeps each note under the date it is about where there is not.
          InfoSection(
            title: l.moduleSectionWhen,
            icon: AppIcons.seasons,
            separated: false,
            minFieldWidth: _paneFieldWidth,
            children: [
              _FieldGroup(
                children: [
                  _DateField(
                    key: const ValueKey('starts_on'),
                    label: '${l.moduleStartDate} *',
                    icon: AppIcons.seasons,
                    value: state.startsOn,
                    placeholder: l.profileSelectDate,
                    onTap: _pickStart,
                  ),
                  // What there is to say about that date, in this file's own
                  // words. It stands where the type's start CONDITION used to
                  // be printed: that sentence is about every file of the kind,
                  // the same one every season, and a form is no place to read
                  // it.
                  if (notesOpen)
                    _NoteField(
                      id: 'start_note',
                      label: l.moduleStartNote,
                      helper: l.moduleStartNoteHint,
                      value: state.startNote,
                      onChanged: cubit.setStartNote,
                    ),
                ],
              ),
              _FieldGroup(
                children: [
                  // Optional, and the file runs on without it. A date here is
                  // not the type's end CONDITION — that says what event closes
                  // such files; this says when this one is done.
                  _DateField(
                    key: const ValueKey('ends_on'),
                    label: l.moduleEndDate,
                    helper: l.moduleEndDateHint,
                    icon: AppIcons.pending,
                    value: state.endsOn,
                    placeholder: l.moduleEndDateClear,
                    onTap: _pickEnd,
                    clearTooltip: l.moduleEndDateClear,
                    onClear: () => cubit.setEndsOn(null),
                  ),
                  // The counterpart of the start note, and emptier still: what
                  // there is to say about an end is usually not writable until
                  // it has happened, which is a second visit to this step.
                  if (notesOpen)
                    _NoteField(
                      id: 'end_note',
                      label: l.moduleEndNote,
                      helper: l.moduleEndNoteHint,
                      value: state.endNote,
                      onChanged: cubit.setEndNote,
                    ),
                ],
              ),
            ],
          ),
          // One line instead of two empty boxes. It never hides anything
          // written: closing it leaves both notes on the file, and a file that
          // has one opens with them showing.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _notesOpen = !notesOpen),
              icon: Icon(notesOpen ? AppIcons.approve : AppIcons.add, size: 18),
              label: Text(notesOpen ? l.moduleNotesHide : l.moduleNotesShow),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          InfoSection(
            title: l.moduleSectionPaperwork,
            icon: AppIcons.file,
            separated: false,
            minFieldWidth: _paneFieldWidth,
            children: [
              _FieldGroup(
                children: [
                  TextFormField(
                    key: const ValueKey('decision_number'),
                    initialValue: state.decisionNumber ?? '',
                    decoration: InputDecoration(
                      labelText: l.moduleDecisionNumber,
                      helperText: l.moduleDecisionNumberHint,
                      prefixIcon: const Icon(AppIcons.file),
                    ),
                    onChanged: cubit.setDecisionNumber,
                  ),
                ],
              ),
              _FieldGroup(
                children: [
                  // Per file, not per type: the same kind of file may want a
                  // daily report one season and nothing the next.
                  DropdownButtonFormField<ReportCadence>(
                    initialValue: state.reportCadence,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.moduleReportCadence,
                      prefixIcon: const Icon(AppIcons.tasks),
                      helperText: l.moduleReportCadenceHint,
                    ),
                    items: [
                      for (final cadence in ReportCadence.values)
                        DropdownMenuItem(
                          value: cadence,
                          child: Text(cadenceLabel(context, cadence)),
                        ),
                    ],
                    onChanged: (v) =>
                        cubit.setReportCadence(v ?? ReportCadence.none),
                  ),
                ],
              ),
            ],
          ),

          // Where a file stops resembling every other file — today the الملف
          // الرسمي and nothing else, but a type may declare any field, and a
          // type that declares none gets no pane rather than an empty one.
          if (type.fields.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            InfoSection(
              title: l.moduleSectionTypeFields,
              icon: AppIcons.document,
              separated: false,
              minFieldWidth: _paneFieldWidth,
              children: [
                for (final field in type.fields)
                  _FieldGroup(
                    children: [
                      ModuleFieldInput(
                        field: field,
                        value: state.values[field.key],
                        referenceSet: state.referenceSetById(
                          field.referenceSetId,
                        ),
                        onChanged: (v) => cubit.setValue(field.key, v),
                        onFilePicked: (file, name) =>
                            cubit.attachFile(field.key, file, name),
                      ),
                    ],
                  ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              l.moduleOnePerSeason,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ]),
      ),
    );
  }
}

/// How wide a field must be before a pane on this step puts two across.
///
/// Higher than [InfoSection]'s own default, because these are controls rather
/// than read-only values: a date box with a label, a helper line and a clear
/// button crammed into 280 is worse than the same box on a line of its own.
const _paneFieldWidth = 340.0;

/// One cell of a pane: a control, and whatever belongs directly under it.
///
/// [InfoSection] lays its children out in columns and puts nothing between
/// them — right for a list of values, where the hairline is the separator, and
/// not for a form, where two boxes would touch. The breathing room is here so
/// that it is the same whether the pane came out one column wide or two.
class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A date on the file: a labelled box that opens a calendar rather than a
/// keyboard. [onClear] draws the button that takes the date off again — the
/// start date has none, because a file cannot be saved without one.
class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.helper,
    this.onClear,
    this.clearTooltip,
  });

  final String label;
  final String? helper;
  final IconData icon;
  final DateTime? value;

  /// What stands in the box before a date is picked, in the muted italic that
  /// says it is not a value.
  final String placeholder;

  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = value == null;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          prefixIcon: Icon(icon),
          suffixIcon: empty || onClear == null
              ? null
              : IconButton(
                  tooltip: clearTooltip,
                  icon: const Icon(AppIcons.delete, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          empty ? placeholder : formatDate(value),
          style: empty
              ? TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                )
              : null,
        ),
      ),
    );
  }
}

/// ملاحظة بداية العمل or ملاحظة نهاية العمل: free prose about one of the two
/// dates, in this file's own words.
///
/// Keyed, because a pane reflows its children into a different number of
/// columns as the window changes, and an unkeyed field carries whatever text
/// the field that used to stand in its place was holding.
class _NoteField extends StatelessWidget {
  const _NoteField({
    required this.id,
    required this.label,
    required this.helper,
    required this.value,
    required this.onChanged,
  });

  final String id;
  final String label;
  final String helper;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey(id),
      initialValue: value ?? '',
      minLines: 2,
      maxLines: 4,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        alignLabelWithHint: true,
      ),
      onChanged: onChanged,
    );
  }
}

/// Step 2 — the sectors. Each is named here and given its supervisor and his
/// deputies; the hotels come in the step after.
class _NodesStep extends StatelessWidget {
  const _NodesStep({
    required this.state,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onImport,
  });

  final ModuleEditorState state;
  final void Function(ModuleLevel level) onAdd;
  final void Function(ModuleLevel level, ModuleNode node) onEdit;
  final void Function(ModuleLevel level, ModuleNode node, String name) onDelete;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final level = state.parentLevel;
    if (level == null) {
      return EmptyState(icon: AppIcons.modules, title: l.moduleNoLevels);
    }
    final sectors = state.parentNodes;

    return ResponsivePage(
      width: PageWidth.editor,
      builder: (context, size) => SinglePaneLayout(
        gutter: size.gutter,
        children: staggered([
          // Named by the level and counted beside it, so the same header serves
          // "القطاع 3" and "المركز 3" without a string per file.
          SectionHeader(
            level.name.of(context),
            icon: AppIcons.roles,
            trailing: Text(
              '${sectors.length}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          if (sectors.isEmpty)
            GlassCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(l.moduleNoNodes),
            ),
          for (final sector in sectors) ...[
            _NodeCard(
              state: state,
              level: level,
              node: sector,
              onEdit: () => onEdit(level, sector),
              onDelete: (name) => onDelete(level, sector, name),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: () => onAdd(level),
            icon: const Icon(AppIcons.add),
            label: Text(l.moduleNodeAdd(level.name.of(context))),
          ),
          // Offered only where it means something: another file of this season
          // divided by the SAME level. The same قطاعات stand in two files and
          // typing them twice is how those files start disagreeing about who
          // runs one — but a مركز at عرفات is not a قطاع in Makkah, and there
          // the offer would be nonsense.
          if (state.sectorSourceTypeIds.isNotEmpty)
            TextButton.icon(
              onPressed: state.isCreated ? onImport : null,
              icon: const Icon(AppIcons.download, size: 18),
              label: Text(l.moduleSectorsImport),
            ),
        ]),
      ),
    );
  }
}

/// Step 3 — the hotels of every sector, each with its tower supervisor, his
/// deputies and the mission members serving there.
class _TowersStep extends StatelessWidget {
  const _TowersStep({
    required this.state,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final ModuleEditorState state;
  final void Function(ModuleLevel level, ModuleNode parent) onAdd;
  final void Function(ModuleLevel level, ModuleNode node) onEdit;
  final void Function(ModuleLevel level, ModuleNode node, String name) onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sectorLevel = state.parentLevel;
    final towerLevel = state.childLevel;
    if (sectorLevel == null || towerLevel == null) {
      return EmptyState(icon: AppIcons.modules, title: l.moduleNoLevels);
    }
    final sectors = state.parentNodes;
    if (sectors.isEmpty) {
      return EmptyState(
        icon: AppIcons.roles,
        title: l.moduleNoNodes,
        message: l.moduleSectorsFirst,
      );
    }

    return ResponsivePage(
      width: PageWidth.editor,
      builder: (context, size) => SinglePaneLayout(
        gutter: size.gutter,
        children: staggered([
          for (final sector in sectors) ...[
            SectionHeader(
              sector.label ?? sectorLevel.name.of(context),
              icon: AppIcons.roles,
            ),
            for (final tower in state.childrenOf(sector.id)) ...[
              _NodeCard(
                state: state,
                level: towerLevel,
                node: tower,
                onEdit: () => onEdit(towerLevel, tower),
                onDelete: (name) => onDelete(towerLevel, tower, name),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            OutlinedButton.icon(
              onPressed: () => onAdd(towerLevel, sector),
              icon: const Icon(AppIcons.add),
              label: Text(l.moduleNodeAdd(towerLevel.name.of(context))),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ]),
      ),
    );
  }
}

/// The second and last step of a file with no tree — its teams, each filled
/// from the season's participants. Who owes what is not decided here: since
/// 0105 duties are the file's descriptive lists, and each person's tracked
/// work lives on their own list outside the files.
class _TeamsStep extends StatelessWidget {
  const _TeamsStep({required this.state, required this.onPickTeam});

  final ModuleEditorState state;
  final void Function(ModuleRole role) onPickTeam;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final type = state.type;
    // Gathered into the teams the type declares (0115): مدير فريق الكوسترات,
    // his معاون and the أعضاء are one team with three posts to fill, and three
    // separate cards said they were three separate teams. A post that names no
    // team is a group of one and its card is what it always was.
    final groups = type?.roleGroups ?? const <ModuleRoleGroup>[];
    if (type == null || groups.isEmpty) {
      return EmptyState(icon: AppIcons.roles, title: l.moduleNoRoles);
    }

    return ResponsivePage(
      width: PageWidth.editor,
      builder: (context, size) => SinglePaneLayout(
        gutter: size.gutter,
        children: staggered([
          SectionHeader(
            l.moduleMembersCount(state.members.length),
            icon: AppIcons.participants,
          ),
          for (final group in groups) ...[
            _TeamCard(state: state, group: group, onPick: onPickTeam),
            const SizedBox(height: AppSpacing.md),
          ],
        ]),
      ),
    );
  }
}

/// One team: its posts, and who is standing in each.
///
/// The card is the TEAM. Inside it each post keeps its own list and its own
/// button — staffing is done per post, because that is what the server stores
/// and what "معاون المدير" means — but they sit inside one frame, under one
/// name, instead of three cards that read as three teams.
///
/// A group of one post is the same widget with the post's own name at the top
/// and no sub-heading, which is exactly the card this used to be.
class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.state,
    required this.group,
    required this.onPick,
  });

  final ModuleEditorState state;
  final ModuleRoleGroup group;
  final void Function(ModuleRole role) onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = group.roles.fold<int>(
      0,
      (n, role) => n + state.membersOf(role.id).length,
    );

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.roles, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  group.name.of(context),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              // The whole team's headcount, so a folded-looking card still says
              // how many people are on it.
              Text(
                '$total',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          for (final role in group.roles)
            _TeamPost(
              role: role,
              members: state.membersOf(role.id),
              // Named only where there is more than one post under the
              // heading. In a group of one the heading already said it.
              showName: group.namesItsPosts,
              onPick: () => onPick(role),
            ),
        ],
      ),
    );
  }
}

/// One post inside a team card: what it is called, who holds it, and the button
/// that changes that.
class _TeamPost extends StatelessWidget {
  const _TeamPost({
    required this.role,
    required this.members,
    required this.showName,
    required this.onPick,
  });

  final ModuleRole role;
  final List<ModuleMember> members;
  final bool showName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showName)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    role.name.of(context),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (members.isNotEmpty)
                  Text(
                    '${members.length}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l.moduleNoTeamMembers,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          for (final member in members)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _TeamMemberRow(member: member),
            ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(AppIcons.participants),
          // The post's own name on the button once there is more than one of
          // them: three identical "اختيار الأعضاء" buttons in one card is three
          // ways to open the wrong picker.
          label: Text(
            showName ? l.moduleTeamPickFor(role.name.of(context)) : l.moduleTeamPick,
          ),
        ),
      ],
    );
  }
}

/// One person on a team.
class _TeamMemberRow extends StatelessWidget {
  const _TeamMemberRow({required this.member});

  final ModuleMember member;

  @override
  Widget build(BuildContext context) {
    final profile = member.profile;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          ProfileAvatar(
            photoUrl: profile?.photoUrl,
            name: profile?.fullName ?? '',
            radius: 18,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              (profile?.fullName.isEmpty ?? true) ? '—' : profile!.fullName,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A sector or a tower as it appears in the editor: what it is, who holds each
/// of its roles, and the two things you can do to it.
class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.state,
    required this.level,
    required this.node,
    required this.onEdit,
    required this.onDelete,
  });

  final ModuleEditorState state;
  final ModuleLevel level;
  final ModuleNode node;
  final VoidCallback onEdit;
  final void Function(String name) onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = state.referenceItem(
      level.referenceSetId,
      node.referenceItemId,
    );
    final name = entry?.name.of(context) ?? node.label ?? '—';
    // What it is tied to — the تكتل of a برج — shown beside the name, because a
    // tree half-entered is the thing this step exists to make visible.
    final tied = state.referenceItem(
      level.secondaryReferenceSetId,
      node.secondaryReferenceItemId,
    );

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                level.isNamedByHand
                    ? AppIcons.moduleType
                    : AppIcons.organization,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tied != null) ...[
                GlassBadge(
                  label: tied.name.of(context),
                  icon: AppIcons.participants,
                  dense: true,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              OverflowMenu(
                actions: [
                  MenuAction(
                    icon: AppIcons.edit,
                    label: context.l10n.commonEdit,
                    onSelected: onEdit,
                  ),
                  MenuAction(
                    icon: AppIcons.delete,
                    label: context.l10n.commonDelete,
                    isDestructive: true,
                    onSelected: () => onDelete(name),
                  ),
                ],
              ),
            ],
          ),
          for (final role in level.roles)
            if (node.profileIdsOf(role.id).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 116,
                      child: Text(
                        role.name.of(context),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final id in node.profileIdsOf(role.id))
                            if (state.profileById(id) case final p?)
                              Chip(
                                avatar: ProfileAvatar(
                                  photoUrl: p.photoUrl,
                                  name: p.fullName,
                                  radius: 10,
                                ),
                                label: Text(p.fullName),
                                visualDensity: VisualDensity.compact,
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
