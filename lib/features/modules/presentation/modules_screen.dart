import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../../../core/widgets/overflow_menu.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../../seasons/data/seasons_repository.dart';
import '../application/modules_cubit.dart';
import '../data/modules_repository.dart';
import '../domain/module_type.dart';
import '../domain/operational_module.dart';
import 'module_detail_screen.dart';
import 'module_editor_screen.dart';

/// One beat of the entry cascade.
const _step = Duration(milliseconds: 70);

/// One screen, two questions — see [ModulesView].
///
/// [ModulesView.mine] is the work: the files this person was put into. The
/// dashboard offers it under عام, to everybody, because everybody has work.
///
/// [ModulesView.manage] is the office: the season's files, drafts included,
/// with the button that opens a new one. It sits under إدارة behind
/// `modules.manage`.
///
/// A man may be both — holding the permission to run every file of the season
/// AND assigned to a tower in one of them — and reading one list for both means
/// sorting his own postings out of the season's paperwork every time he looks.
class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key, this.view = ModulesView.mine});

  final ModulesView view;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ModulesCubit(ModulesRepository(), SeasonsRepository(), view: view),
      child: _View(view: view),
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.view});

  final ModulesView view;

  Future<void> _create(BuildContext context, ModulesState state) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<ModulesCubit>();
    void say(String message) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

    // Roles are filled from the current season's participants, so a file
    // cannot be created before a season is running. The list already loaded it.
    final season = state.season;
    if (season == null) {
      say(l.moduleNoCurrentSeason);
      return;
    }

    // A file of a kind exists once in a season, so a kind already opened this
    // season is not on offer at all — rather than failing at the save.
    final available = state.typesAvailable();
    if (available.isEmpty) {
      say(state.types.isEmpty ? l.moduleNoTypes : l.moduleAllTypesUsed);
      return;
    }

    final type = available.length == 1
        ? available.single
        : await showModalBottomSheet<ModuleType>(
            context: context,
            // Over the rail as well as the page — see [showAppSheet].
            useRootNavigator: true,
            // The list of types is as long as the season has kinds of file —
            // ten of them now — and a sheet left unscrollable stops at half the
            // screen and overflows the rest.
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => _TypePickerSheet(types: available),
          );
    if (type == null || !context.mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      fadeThroughRoute(
        (_) => ModuleEditorScreen(moduleTypeId: type.id, seasonId: season.id),
      ),
    );
    if (saved == true) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.watch<SessionCubit>().state;
    // Which door this is. Everything that WRITES on this screen and on the
    // pages it opens waits on it — holding the permission does not put a create
    // button on the list of a man's own postings, and it does not put Edit,
    // Delete and Deactivate on a file he opened from that list either.
    final fromOffice = view == ModulesView.manage;
    final canCreate = fromOffice && session.can(PermissionCodes.modulesCreate);
    final canEdit = fromOffice && session.can(PermissionCodes.modulesEdit);
    final canDelete = fromOffice && session.can(PermissionCodes.modulesDelete);

    return Scaffold(
      extendBodyBehindAppBar: true,
      // The season is in the title because the list is now only ever one
      // season's: without it, switching the season silently changes what this
      // screen means.
      appBar: GlassAppBar(
        title: BlocBuilder<ModulesCubit, ModulesState>(
          buildWhen: (p, c) => p.season != c.season,
          builder: (context, state) => Text(
            [
              view == ModulesView.manage
                  ? l.modulesManageTitle
                  : l.modulesTitle,
              if (state.season != null)
                l.seasonHijriYear(state.season!.hijriYear),
            ].join(' — '),
          ),
        ),
      ),
      floatingActionButton: canCreate
          ? BlocBuilder<ModulesCubit, ModulesState>(
              buildWhen: (p, c) => p.types != c.types,
              builder: (context, state) => FloatingActionButton.extended(
                onPressed: state.types.isEmpty
                    ? null
                    : () => _create(context, state),
                icon: const Icon(AppIcons.add),
                label: Text(l.moduleNew),
              ),
            )
          : null,
      body: BlocBuilder<ModulesCubit, ModulesState>(
        builder: (context, state) {
          if (state.status == ModulesStatus.loading) {
            return const SkeletonList(height: 150);
          }
          if (state.status == ModulesStatus.error) {
            return EmptyState(
              icon: AppIcons.modules,
              title: friendlyError(context, state.error),
              action: FilledButton(
                onPressed: () => context.read<ModulesCubit>().load(),
                child: Text(l.commonRetry),
              ),
            );
          }
          if (state.modules.isEmpty) {
            return EmptyState(
              icon: AppIcons.modules,
              title: canCreate
                  ? l.modulesEmptyManager
                  : (view == ModulesView.mine
                        ? l.modulesEmptyMine
                        : l.modulesEmpty),
              message: canCreate && state.types.isEmpty
                  ? l.moduleNoTypes
                  : null,
            );
          }

          // The drafts wait for the files above them, but only up to where
          // staggered() itself stops adding delay — a season with thirty files
          // would otherwise leave the second heading off the screen for
          // seconds, which reads as the list being broken rather than arriving.
          final draftBeat = state.active.isEmpty
              ? Duration.zero
              : _step * (state.active.length.clamp(0, 8) + 2);

          // Always, and not past some count. التقارير shows its bar in both
          // its lists whatever is in them, and a screen that hides the search
          // box on عام and shows it in الإدارة teaches the reader that this
          // list cannot be searched — which is the one thing it must not say
          // when the very same list elsewhere can.
          final nothingLeft =
              state.active.isEmpty && state.drafts.isEmpty && state.isNarrowed;

          // The same 1200 as التقارير and الشكاوى, and for the same reason: the
          // search box sits at the start of the band, so a band that keeps
          // growing with the monitor carries it out to the edge of the glass
          // while the identical box on the next screen sits well inside. Three
          // list screens that search differently teach that they search
          // differently. At 1680 this costs the grid its fourth column, which
          // is the cheaper of the two prices.
          // Pinned above the list rather than riding in it, which is how the
          // other nine list screens carry their box. Inside the scroll it went
          // away at the third row of cards, and a reader two screens down who
          // wanted to search had to scroll back to the top to find out that
          // they could — on this screen alone.
          return Column(
            children: [
              _ModulesFilterBar(state: state),
              Expanded(
                child: ResponsivePage(
                  builder: (context, size) =>
                      // The bar above already cleared the app bar; without this
                      // the list would clear it a second time and open on a
                      // hand's width of nothing.
                      MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        child: SinglePaneLayout(
                          gutter: size.gutter,
                          onRefresh: () => context.read<ModulesCubit>().load(),
                          children: [
                            if (nothingLeft)
                              GlassCard(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(l.modulesNoMatches),
                              ),
                            if (state.active.isNotEmpty) ...[
                              FadeSlideIn(
                                child: SectionHeader(
                                  l.moduleActiveSection,
                                  icon: AppIcons.modules,
                                ),
                              ),
                              AdaptiveGrid(
                                children: staggered([
                                  for (final m in state.active)
                                    _ModuleCard(
                                      module: m,
                                      fromOffice: fromOffice,
                                      // Only in the office, and only for whoever runs it.
                                      onEdit: fromOffice && canEdit
                                          ? () => _editModule(context, m)
                                          : null,
                                      onDelete: fromOffice && canDelete
                                          ? () => _deleteModule(context, m)
                                          : null,
                                    ),
                                ], start: _step),
                              ),
                            ],
                            if (state.drafts.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.lg),
                              FadeSlideIn(
                                delay: draftBeat,
                                child: SectionHeader(
                                  l.moduleDraftSection,
                                  icon: AppIcons.edit,
                                ),
                              ),
                              AdaptiveGrid(
                                children: staggered([
                                  for (final m in state.drafts)
                                    _ModuleCard(
                                      module: m,
                                      fromOffice: fromOffice,
                                      // Only in the office, and only for whoever runs it.
                                      onEdit: fromOffice && canEdit
                                          ? () => _editModule(context, m)
                                          : null,
                                      onDelete: fromOffice && canDelete
                                          ? () => _deleteModule(context, m)
                                          : null,
                                    ),
                                ], start: draftBeat + _step),
                              ),
                            ],
                          ],
                        ),
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Straight into the file's editor, without opening the file first.
Future<void> _editModule(BuildContext context, OperationalModule m) async {
  final cubit = context.read<ModulesCubit>();
  final saved = await Navigator.of(context).push<bool>(
    fadeThroughRoute(
      (_) => ModuleEditorScreen(
        moduleTypeId: m.moduleTypeId,
        seasonId: m.seasonId,
        existing: m,
      ),
    ),
  );
  if (saved == true) await cubit.load();
}

/// Removing a file takes its tree and its roster with it, so the confirmation
/// names it rather than asking "are you sure".
Future<void> _deleteModule(BuildContext context, OperationalModule m) async {
  final l = context.l10n;
  final cubit = context.read<ModulesCubit>();
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l.moduleDelete),
      content: Text(l.moduleDeleteConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l.commonDelete),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await ModulesRepository().deleteModule(m.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.moduleDeleted)));
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$e')));
  }
  await cubit.load();
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.fromOffice,
    this.onEdit,
    this.onDelete,
  });

  final OperationalModule module;

  /// Which of this screen's two lists the card is in — see
  /// [ModuleDetailScreen.fromOffice]. Under عام a file opens read-only even for
  /// somebody holding `modules.manage`: there he is a member of it like anyone
  /// else, and that list has never been about running the season's paperwork.
  final bool fromOffice;

  /// The office's actions, reached without opening the file first — the same
  /// affordance إدارة التقارير gives its rows. Null under عام, where the card
  /// only opens.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // No margin of its own: the gap between one card and the next belongs to
    // whatever is arranging them. Carrying it here put it below the card only,
    // which is the one direction a grid does not need it — and made every card
    // in a row taller than it looks by the size of that gap.
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          fadeThroughRoute(
            (_) =>
                ModuleDetailScreen(moduleId: module.id, fromOffice: fromOffice),
          ),
        );
        if (changed == true && context.mounted) {
          await context.read<ModulesCubit>().load();
        }
      },
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(AppIcons.modules, size: 22, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The type is the name: a file is created once per season,
                // so there is nothing to tell two of them apart by.
                Text(
                  module.moduleTypeName?.of(context) ?? '—',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (module.startsOn != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${l.moduleStartDate}: ${formatDate(module.startsOn)}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Directly under the day it began, because the two dates are
                // one fact read together. Coloured only once it has passed —
                // a date still ahead is information, not a warning.
                if (module.endsOn != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${l.moduleEndDate}: ${formatDate(module.endsOn)}',
                    style: text.bodySmall?.copyWith(
                      color: module.hasEnded
                          ? Accent.redDeep.of(context)
                          : scheme.onSurfaceVariant,
                      fontWeight: module.hasEnded ? FontWeight.w600 : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    // Year and decision are identity, not status, so they wear
                    // the muted tone — colour stays with the draft badge below,
                    // which is the one thing on this row that asks for an eye.
                    if (module.seasonHijriYear != null)
                      GlassBadge(
                        label: l.seasonHijriYear(module.seasonHijriYear!),
                        icon: AppIcons.seasons,
                        color: scheme.onSurfaceVariant,
                        dense: true,
                      ),
                    // Beside the year, and worded: "1448 هـ" says what it is
                    // on its own, a bare number does not.
                    if ((module.decisionNumber ?? '').isNotEmpty)
                      GlassBadge(
                        label: l.moduleDecisionBadge(module.decisionNumber!),
                        icon: AppIcons.file,
                        color: scheme.onSurfaceVariant,
                        dense: true,
                      ),
                    // Two different silences, and they can both be true: a
                    // file may be waiting to be switched on AND carry the day
                    // it is due to finish.
                    if (!module.isActive)
                      GlassBadge(
                        label: l.moduleBadgeDraft,
                        icon: AppIcons.edit,
                        color: Accent.gold.of(context),
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null)
            OverflowMenu(
              actions: [
                if (onEdit case final edit?)
                  MenuAction(
                    icon: AppIcons.edit,
                    label: l.commonEdit,
                    onSelected: edit,
                  ),
                if (onDelete case final remove?)
                  MenuAction(
                    icon: AppIcons.delete,
                    label: l.moduleDelete,
                    isDestructive: true,
                    onSelected: remove,
                  ),
              ],
            )
          else
            const NavChevron(),
        ],
      ),
    );
  }
}

/// Creating a file starts by choosing its type — that choice decides what the
/// file is called, how it is structured, and which roles and tasks it carries.
/// Only types not already opened this season are offered.
class _TypePickerSheet extends StatelessWidget {
  const _TypePickerSheet({required this.types});

  final List<ModuleType> types;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      // Sizes to the content and scrolls only once it would pass the cap: three
      // types should not open a sheet built for ten.
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl + MediaQuery.viewPaddingOf(context).bottom,
          ),
          // A sheet takes the window's full width, and on a monitor that is a
          // metre of glass holding a list of ten short names. It is a question,
          // and a question should be the size of its answer.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.moduleChooseType,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final type in types)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: GlassCard(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            onTap: () => Navigator.of(context).pop(type),
                            child: Row(
                              children: [
                                Icon(
                                  AppIcons.moduleType,
                                  size: 20,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        type.name.of(context),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      if (type.description != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          type.description!.of(context),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const NavChevron(),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Search and a running/not-running switch, above a season's files.
///
/// The two sections below already separate running from the rest, so the chips
/// are not a second way of saying the same thing — they COLLAPSE the page to
/// one of them, which is what somebody looking for a draft actually wants.
class _ModulesFilterBar extends StatefulWidget {
  const _ModulesFilterBar({required this.state});
  final ModulesState state;

  @override
  State<_ModulesFilterBar> createState() => _ModulesFilterBarState();
}

class _ModulesFilterBarState extends State<_ModulesFilterBar> {
  late final _controller = TextEditingController(text: widget.state.query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<ModulesCubit>();
    final s = widget.state;

    return SearchFilterBar(
      hint: l.modulesSearchHint,
      controller: _controller,
      onChanged: cubit.search,
      // Only where both kinds exist. On عام a member sees running files and
      // nothing else, and a chip that filters to an empty half of a page is
      // furniture.
      filters: s.modules.any((m) => !m.isRunning)
          ? Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final f in ModuleFilter.values)
                  ChoiceChip(
                    label: Text(switch (f) {
                      ModuleFilter.all => l.reportsScopeAll,
                      ModuleFilter.running => l.moduleActiveSection,
                      ModuleFilter.notRunning => l.moduleDraftSection,
                    }),
                    selected: s.filter == f,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => cubit.setFilter(f),
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
            )
          : null,
    );
  }
}
