import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../../modules/data/modules_repository.dart';
import '../../modules/domain/module_type.dart';
import '../../modules/presentation/widgets/module_field_input.dart';
import '../../seasons/data/seasons_repository.dart';
import '../application/report_editor_cubit.dart';
import '../data/reports_repository.dart';
import '../domain/report.dart';
import 'widgets/report_blocks_editor.dart';

/// Entering a report, and correcting one.
///
/// Three things in order: what the report IS, what it says about itself, and
/// its table. The table's columns come from the type — including the ones drawn
/// from master data, so a count per تكتل is entered against the clusters this
/// season has rather than typed into a box.
class ReportEditorScreen extends StatelessWidget {
  const ReportEditorScreen({super.key, this.existing});

  final Report? existing;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ReportEditorCubit(
      ReportsRepository(),
      ModulesRepository(),
      SeasonsRepository(),
      existing: existing,
    ),
    child: _View(isNew: existing == null),
  );
}

class _View extends StatelessWidget {
  const _View({required this.isNew});
  final bool isNew;

  Future<void> _save(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<ReportEditorCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final id = await cubit.save();
    if (id == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(cubit.state.error ?? l.commonRequired)),
        );
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.reportSaved)));
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return BlocBuilder<ReportEditorCubit, ReportEditorState>(
      builder: (context, state) {
        final cubit = context.read<ReportEditorCubit>();

        return Scaffold(
          appBar: GlassAppBar(title: Text(isNew ? l.reportNew : l.reportEdit)),
          bottomNavigationBar: GlassSurface(
            radius: 0,
            strong: true,
            shadow: false,
            bordered: false,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FilledButton(
                  onPressed:
                      state.canSave && state.status != EditorStatus.saving
                      ? () => _save(context)
                      : null,
                  child: state.status == EditorStatus.saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : Text(l.commonSave),
                ),
              ),
            ),
          ),
          body: switch (state.status) {
            EditorStatus.loading => ResponsivePage(
              builder: (context, size) => SkeletonList(
                width: PageWidth.reading,
                maxColumns: 1,
                minTileWidth: CardWidth.full,
                height: 180,
                count: 3,
                padding: context.scrollPadding(
                  horizontal: size.gutter,
                  bottom: AppSpacing.xl,
                ),
              ),
            ),
            EditorStatus.error => EmptyState(
              icon: AppIcons.reports,
              title: friendlyError(context, state.error),
            ),
            _ => ResponsivePage(
              builder: (context, size) => SinglePaneLayout(
                gutter: size.gutter,
                children: [
                  // One card for what the document IS — its kind, title,
                  // number, scope, whether it is published, and the signed
                  // paper it came from. They were two cards, and the second
                  // held one field: "ما هذا القرار" over a single PDF picker,
                  // which reads as a section somebody forgot to finish.
                  _Identity(state: state, cubit: cubit, isNew: isNew),
                  // Every document is WRITTEN since 0103 — the typed shapes
                  // were three tables, and the table block does what they did.
                  if (state.type != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    ReportBlocksEditor(state: state, cubit: cubit),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          },
        );
      },
    );
  }
}

/// What the report is: its kind, its name, and whether it belongs to a season.
class _Identity extends StatefulWidget {
  const _Identity({
    required this.state,
    required this.cubit,
    required this.isNew,
  });

  final ReportEditorState state;
  final ReportEditorCubit cubit;
  final bool isNew;

  @override
  State<_Identity> createState() => _IdentityState();
}

class _IdentityState extends State<_Identity> {
  late final _title = TextEditingController(text: widget.state.title);
  late final _subtitle = TextEditingController(text: widget.state.subtitle);
  late final _number = TextEditingController(text: widget.state.number);

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = widget.state;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.reportIdentity, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          // Which act this is. Above the title deliberately: it changes how the
          // whole document is read, and a man writing one knows before he
          // writes the first word whether he is deciding something or telling
          // the mission something.
          //
          // Editable after publishing, unlike the type: a document filed under
          // the wrong one of these is a wrong LABEL, not wrong data, and
          // correcting it costs nothing. Changing the type would empty the
          // table.
          SegmentedButton<DecisionKind>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: DecisionKind.decision,
                icon: const Icon(AppIcons.file, size: 18),
                label: Text(l.reportKindDecision),
              ),
              ButtonSegment(
                value: DecisionKind.circular,
                icon: const Icon(AppIcons.send, size: 18),
                label: Text(l.reportKindCircular),
              ),
            ],
            selected: {s.kind},
            onSelectionChanged: (v) => widget.cubit.setKind(v.first),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _title,
            onChanged: widget.cubit.setTitle,
            decoration: InputDecoration(labelText: '${l.reportTitle} *'),
          ),
          const SizedBox(height: AppSpacing.md),
          // Names the DOCUMENT, beside its title. Not the `subheading` block,
          // which divides a body halfway down — they were one field until 0102
          // only because the type table happened to hold both, and a man
          // writing a قرار could put its subject in either.
          TextField(
            controller: _subtitle,
            onChanged: widget.cubit.setSubtitle,
            decoration: InputDecoration(
              labelText: l.reportSubtitle,
              helperText: l.commonOptional,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _number,
            onChanged: widget.cubit.setNumber,
            decoration: InputDecoration(
              labelText: l.reportNumber,
              helperText: l.commonOptional,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String?>(
            initialValue: s.seasonId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.reportScope,
              helperText: l.reportScopeHint,
            ),
            items: [
              // General first, and it is what a new report starts on.
              DropdownMenuItem(value: null, child: Text(l.reportsScopeGeneral)),
              for (final season in s.seasons)
                DropdownMenuItem(
                  value: season.id,
                  child: Text(l.seasonHijriYear(season.hijriYear)),
                ),
            ],
            onChanged: widget.cubit.setSeason,
          ),
          // The save button obeys canSave; this is the sentence that says why
          // it went dark. Under the season chooser because moving the report
          // to another season — or to the general shelf — is the way out.
          if (s.onceConflict) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.reportOncePerSeason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          // The signed paper this document came from, on the same card as the
          // rest of what it IS. Whatever else the type declares comes with it —
          // written against the schema rather than against the word "PDF", so
          // a type that declares a link or a code renders here too.
          for (final f in s.type?.fields ?? const <ModuleField>[]) ...[
            const SizedBox(height: AppSpacing.md),
            ModuleFieldInput(
              field: f,
              value: s.data[f.key],
              referenceSet: s.setById(f.referenceSetId),
              onChanged: (v) => widget.cubit.setField(f.key, v),
            ),
          ],
          // Publishing carries its own permission: an editor without it keeps
          // the switch in sight — the report's state is a fact of the page —
          // but cannot throw it.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(AppIcons.activate),
            title: Text(l.reportPublished),
            subtitle: Text(l.reportPublishedHint),
            value: s.isPublished,
            onChanged:
                context.watch<SessionCubit>().state.can(
                  PermissionCodes.reportsPublish,
                )
                ? widget.cubit.setPublished
                : null,
          ),
        ],
      ),
    );
  }
}
