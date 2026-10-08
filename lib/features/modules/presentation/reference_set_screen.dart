import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

import '../../../core/animations/animations.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/arabic_search.dart';
import '../../../core/widgets/blocking_progress.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/overflow_menu.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../../checkin/data/check_in_repository.dart';
import '../../checkin/presentation/place_code_screen.dart';
import '../application/reference_data_cubit.dart';
import '../domain/module_type.dart';
import '../domain/reference_item.dart';
import 'reference_item_detail_screen.dart';
import 'widgets/reference_item_actions.dart';
import 'widgets/reference_item_form.dart';

/// Every entry in one master-data list — hotels, or clusters, or cities. The
/// summary line under each name is built from that list's own schema, so this
/// screen never needs to know what a hotel is.
class ReferenceSetScreen extends StatefulWidget {
  const ReferenceSetScreen({super.key, required this.setId});

  final String setId;

  @override
  State<ReferenceSetScreen> createState() => _ReferenceSetScreenState();
}

/// One tab: what it is called, and which entries fall under it.
class _Division {
  const _Division({required this.label, required this.items});

  final String label;
  final List<ReferenceItem> items;
}

class _ReferenceSetScreenState extends State<ReferenceSetScreen> {
  String _query = '';

  bool _matches(BuildContext context, ReferenceItem item) {
    if (_query.trim().isEmpty) return true;
    return arabicMatchesAll([
      item.name.of(context),
      ...item.data.values.map((v) => '$v'),
    ], _query);
  }

  /// The tabs this list is read through, or a single unnamed one when it has no
  /// natural division.
  ///
  /// The groups are decided from EVERY entry and only then narrowed by the
  /// search, so that typing does not make tabs appear and vanish under the
  /// finger. A tab whose entries are all filtered out stays, and says so.
  ///
  /// الكل comes first, and «بلا تصنيف» last and only when it has something in
  /// it. Between them those two mean no entry can be invisible — which is the
  /// one state a management screen may never be in, since an entry nobody can
  /// see is an entry nobody can correct.
  List<_Division> _divide(
    BuildContext context,
    ReferenceDataState state,
    ReferenceSet set,
    List<ReferenceItem> all,
  ) {
    final shown = all.where((i) => _matches(context, i)).toList();
    final field = set.copyWith(items: all).dividingField();
    final target = state.setById(field?.referenceSetId ?? '');
    if (field == null || target == null) {
      return [_Division(label: '', items: shown)];
    }

    final l = context.l10n;
    final divisions = <_Division>[
      _Division(label: l.referenceDivisionAll, items: shown),
    ];

    // In the target list's own order, not in the order the entries happen to
    // mention them: مكة before المدينة because the master list says so.
    for (final group in target.items) {
      if (!all.any((i) => i.data[field.key] == group.id)) continue;
      divisions.add(
        _Division(
          label: group.name.of(context),
          items: shown.where((i) => i.data[field.key] == group.id).toList(),
        ),
      );
    }

    final unclassified = shown
        .where(
          (i) => !target.items.any((g) => g.id == i.data[field.key]),
        )
        .toList();
    final anyUnclassified = all.any(
      (i) => !target.items.any((g) => g.id == i.data[field.key]),
    );
    if (anyUnclassified) {
      divisions.add(
        _Division(label: l.referenceDivisionNone, items: unclassified),
      );
    }

    return divisions;
  }

  /// Every code of this list, one to a page.
  ///
  /// The secrets are fetched here rather than carried in the list's own state:
  /// `ReferenceDataCubit` holds every set with every entry and is loaded on a
  /// screen most people open to read a phone number. Pulling every secret in
  /// the season into it, for everybody holding the permission, so that a menu
  /// item can exist is how a printable secret becomes a downloadable one.
  ///
  /// A place whose code cannot be read is skipped rather than failing the
  /// batch — and the count reported at the end says how many were skipped, so
  /// nobody walks away believing he has forty stickers when he has thirty-one.
  Future<void> _printCodes(
    BuildContext context,
    ReferenceSet set,
    List<ReferenceItem> items,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<ReferenceDataCubit>().state;
    final repo = CheckInRepository();

    final pages =
        <({String payload, String placeName, String? subtitle})>[];
    final failure = await runBlocking(context, () async {
      for (final item in items) {
        final found = await repo.fetchCode(item.id);
        if (found == null) continue;
        pages.add((
          payload: found.code.encode(),
          placeName: found.placeName,
          subtitle: _subtitleFor(state, set, item),
        ));
      }
      return null;
    }, message: l.checkInQrPrintingAll);

    if (failure != null || pages.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.referenceEmpty)));
      return;
    }

    await Printing.layoutPdf(
      onLayout: (format) => placeCodeBook(format: format, places: pages),
      name: 'place-codes',
    );
  }

  /// The list, and whatever divides it — a hotel's city, a camp's مشعر. Read
  /// from the schema so nothing here has to know what either is.
  String _subtitleFor(
    ReferenceDataState state,
    ReferenceSet set,
    ReferenceItem item,
  ) {
    final parts = <String>[set.name.ar];
    final dividing = set.dividingField();
    final value = dividing == null ? null : item.data[dividing.key];
    if (dividing != null && value != null) {
      final target = state
          .setById(dividing.referenceSetId ?? '')
          ?.items
          .where((i) => i.id == value)
          .firstOrNull;
      if (target != null) parts.add(target.name.ar);
    }
    return parts.join(' — ');
  }

  /// Copies another season's entries into this one. They arrive as copies and
  /// stay unrelated: deleting one here leaves the season it came from alone.
  Future<void> _import(BuildContext context, ReferenceSet set) async {
    final l = context.l10n;
    final cubit = context.read<ReferenceDataCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final seasons = await cubit.otherSeasons();
    if (!context.mounted) return;

    if (seasons.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.referenceImportNoSeasons)));
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
                l.referenceImportPick,
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
            ),
            for (final season in seasons)
              ListTile(
                leading: const Icon(AppIcons.seasons),
                title: Text(l.seasonHijriYear(season.hijriYear)),
                onTap: () => Navigator.of(sheetContext).pop(season.id),
              ),
          ],
        ),
      ),
    );
    if (from == null) return;

    final copied = await cubit.importFromSeason(
      setId: set.id,
      fromSeasonId: from,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            copied == null
                ? l.referenceImportFailed
                : l.referenceImported(copied),
          ),
        ),
      );
  }

  /// Empties the list of everything currently listed — which, when a search is
  /// narrowing it, is what the reader is looking at rather than the whole set.
  /// Deleting 200 hotels because one was searched for would be the worse
  /// surprise of the two.
  Future<void> _deleteAll(
    BuildContext context,
    ReferenceSet set,
    List<ReferenceItem> items,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<ReferenceDataCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.referenceDeleteAll),
        content: Text(
          l.referenceDeleteAllConfirm(items.length, set.name.of(dialogContext)),
        ),
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
    if (confirmed != true || !context.mounted) return;

    // One round trip per entry, so the screen is sealed for the duration: the
    // list underneath is being emptied and a tap into it lands on rows that are
    // already gone.
    final result = await runBlocking(
      context,
      () => cubit.deleteItems(items.map((i) => i.id)),
      message: l.referenceDeletingAll,
    );

    final message = switch (result) {
      BulkDeleteResult(deleted: 0, message: final failure?) => friendlyErrorL(
        l,
        failure,
      ),
      BulkDeleteResult(kept: 0) => l.referenceDeleteAllDone(result.deleted),
      BulkDeleteResult(deleted: 0) => l.referenceDeleteAllNone,
      _ => l.referenceDeleteAllPartial(result.deleted, result.kept),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.watch<SessionCubit>().state;
    final canEdit = session.can(PermissionCodes.referenceEdit);
    final canDelete = session.can(PermissionCodes.referenceDelete);
    final canImport = session.can(PermissionCodes.referenceImport);

    return BlocBuilder<ReferenceDataCubit, ReferenceDataState>(
      builder: (context, state) {
        final set = state.setById(widget.setId);
        if (set == null) {
          return Scaffold(
            appBar: GlassAppBar(title: Text(l.referenceDataTitle)),
            body: const SkeletonList(height: 84),
          );
        }

        // This season's entries, for a set that is scoped to one. The hotels of
        // 1447 are not the hotels of 1448.
        final all = state.visibleItems(set.id).toList();
        final divisions = _divide(context, state, set, all);
        final divided = divisions.length > 1;

        // Rebuilt whenever the tabs themselves change — a مشعر used for the
        // first time, a season imported — because a TabController outlives its
        // length otherwise and asks for a tab that is no longer there.
        return DefaultTabController(
          key: ValueKey(divisions.map((d) => d.label).join('|')),
          length: divisions.length,
          child: Builder(
            builder: (context) => Scaffold(
              extendBodyBehindAppBar: true,
              appBar: GlassAppBar(
                title: Text(set.name.of(context)),
                actions: [
                  // Importing a season and emptying the list are not two glyphs
                  // to tell apart on a title bar when one of them destroys the
                  // list. Behind one overflow icon they are words, and the
                  // dangerous one sits under a divider.
                  OverflowMenu(
                    actions: [
                      // Only a season-scoped list has anything to import: the
                      // cities do not start over each year.
                      if (canImport &&
                          set.isSeasonScoped &&
                          state.season != null)
                        MenuAction(
                          icon: AppIcons.download,
                          label: l.referenceImport,
                          onSelected: () => _import(context, set),
                        ),
                      // Sit down once with a printer and come away with the
                      // season's whole stock of stickers. This replaces the
                      // per-file code list 0098 removed, and is strictly more
                      // useful than it was: a list is every hotel the season
                      // contracted, not one file's towers — including the ones
                      // in المدينة that stand in no file at all.
                      //
                      // Doing it one place at a time is an afternoon's work,
                      // and an afternoon's work is the kind that gets
                      // half-finished — which leaves gates with no code and a
                      // register with holes in exactly the places nobody got
                      // round to.
                      if (set.isPlace &&
                          all.isNotEmpty &&
                          session.can(PermissionCodes.checkinCodes))
                        MenuAction(
                          icon: AppIcons.qrCode,
                          label: l.checkInQrPrintAll,
                          onSelected: () => _printCodes(context, set, all),
                        ),
                      if (canDelete && all.isNotEmpty)
                        MenuAction(
                          icon: AppIcons.delete,
                          label: l.referenceDeleteAll,
                          isDestructive: true,
                          // The tab in front of the reader, not the whole set.
                          // Same rule the search already followed: what "all"
                          // means is what is on the screen, and emptying مكة
                          // must not take المدينة with it. Read at the tap
                          // rather than at build, so the menu needs no listener.
                          onSelected: () => _deleteAll(
                            context,
                            set,
                            divisions[DefaultTabController.of(
                              context,
                            ).index.clamp(0, divisions.length - 1)].items,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              floatingActionButton: canEdit
                  ? FloatingActionButton.extended(
                      onPressed: () => showReferenceItemForm(context, set: set),
                      icon: const Icon(AppIcons.add),
                      label: Text(l.referenceAddItem),
                    )
                  : null,
              body: ResponsivePage(
                builder: (context, size) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchFilterBar(
                      hint: l.commonSearch,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    if (divided)
                      TabBar(
                        // Scrollable and left-aligned: two tabs stretched
                        // across a desk monitor read as two buttons nobody
                        // grouped, and a fourth would not fit a phone.
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        padding: EdgeInsets.symmetric(horizontal: size.gutter),
                        tabs: [
                          for (final division in divisions)
                            Tab(text: '${division.label} · ${division.items.length}'),
                        ],
                      ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final division in divisions)
                            _DivisionList(
                              set: set,
                              items: division.items,
                              gutter: size.gutter,
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
      },
    );
  }
}

/// One tab's worth of the list.
class _DivisionList extends StatelessWidget {
  const _DivisionList({
    required this.set,
    required this.items,
    required this.gutter,
  });

  final ReferenceSet set;
  final List<ReferenceItem> items;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: AppIcons.referenceData,
        title: context.l10n.referenceEmpty,
      );
    }

    // A set is every hotel, every cluster — long enough to page in as it is
    // reached.
    return AdaptiveGridView(
      onRefresh: () => context.read<ReferenceDataCubit>().load(),
      padding: EdgeInsets.fromLTRB(
        gutter,
        0,
        gutter,
        AppSpacing.xxl * 2 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => FadeSlideIn(
        delay: Duration(milliseconds: 30 * (i < 8 ? i : 8)),
        child: _ItemCard(set: set, item: items[i]),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.set, required this.item});

  final ReferenceSet set;
  final ReferenceItem item;

  /// A one-line précis built from the set's own fields, so a hotel row reads
  /// "Makkah" and a cluster row reads its head — without this screen knowing
  /// what either of those is.
  String _summary(BuildContext context, ReferenceDataState state) {
    final parts = <String>[];
    for (final field in set.fields) {
      // Links and numbers are for acting on, not for scanning — the summary
      // stays the couple of words that tell two entries apart.
      if (field.kind == ModuleFieldKind.url ||
          field.kind == ModuleFieldKind.location ||
          field.kind == ModuleFieldKind.phone) {
        continue;
      }
      final value = item.data[field.key];
      if (value == null || '$value'.isEmpty) continue;
      if (field.kind == ModuleFieldKind.reference) {
        final target = state
            .setById(field.referenceSetId ?? '')
            ?.items
            .where((i) => i.id == value)
            .firstOrNull;
        if (target != null) parts.add(target.name.of(context));
      } else {
        parts.add('$value');
      }
    }
    return parts.join('  •  ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<ReferenceDataCubit>().state;
    final session = context.watch<SessionCubit>().state;
    final summary = _summary(context, state);
    final canEdit = session.can(PermissionCodes.referenceEdit);
    final canDelete = session.can(PermissionCodes.referenceDelete);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () {
        final cubit = context.read<ReferenceDataCubit>();
        Navigator.of(context).push(
          fadeThroughRoute(
            (_) => BlocProvider.value(
              value: cubit,
              child: ReferenceItemDetailScreen(setId: set.id, itemId: item.id),
            ),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              AppIcons.referenceData,
              size: 18,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.of(context),
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Correcting a name and removing an entry are the two things done to
          // master data, and both were a screen away behind the row. They are
          // put where the list already is — the same three dots the operational
          // files and the reports carry.
          if (canEdit || canDelete)
            OverflowMenu(
              actions: [
                if (canEdit)
                  MenuAction(
                    icon: AppIcons.edit,
                    label: l.commonEdit,
                    onSelected: () =>
                        showReferenceItemForm(context, set: set, item: item),
                  ),
                if (canDelete)
                  MenuAction(
                    icon: AppIcons.delete,
                    label: l.commonDelete,
                    isDestructive: true,
                    onSelected: () => confirmDeleteReferenceItem(context, item),
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
