import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../../l10n/app_localizations.dart';
import '../application/reference_data_cubit.dart';
import '../../seasons/data/seasons_repository.dart';
import '../data/modules_repository.dart';
import '../domain/reference_item.dart';
import 'reference_set_screen.dart';

/// The admin-managed lists that back every dropdown in a module — hotels,
/// clusters, cities, and whatever a future module type needs. Each list carries
/// its own item shape, so one screen manages all of them.
class ReferenceDataScreen extends StatelessWidget {
  const ReferenceDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ReferenceDataCubit(ModulesRepository(), SeasonsRepository()),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(l.referenceDataTitle)),
      body: BlocBuilder<ReferenceDataCubit, ReferenceDataState>(
        builder: (context, state) {
          if (state.status == ReferenceDataStatus.loading) {
            return const SkeletonList(height: 96);
          }
          if (state.status == ReferenceDataStatus.error) {
            return EmptyState(
              icon: AppIcons.referenceData,
              title: friendlyError(context, state.error),
              action: FilledButton(
                onPressed: () => context.read<ReferenceDataCubit>().load(),
                child: Text(l.commonRetry),
              ),
            );
          }
          if (state.sets.isEmpty) {
            return EmptyState(
              icon: AppIcons.referenceData,
              title: l.referenceEmpty,
            );
          }

          return ResponsivePage(
            builder: (context, size) => SinglePaneLayout(
              gutter: size.gutter,
              onRefresh: () => context.read<ReferenceDataCubit>().load(),
              children: [
                for (final shelf in _shelve(state.sets)) ...[
                  SectionHeader(
                    _shelfTitle(l, shelf.section),
                    icon: _shelfIcon(shelf.section),
                  ),
                  AdaptiveGrid(
                    children: staggered([
                      for (final set in shelf.sets) _SetCard(set: set),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One shelf and the lists on it.
typedef _Shelf = ({String? section, List<ReferenceSet> sets});

/// The order the shelves are read in.
///
/// Fixed here rather than sorted alphabetically, because the sequence is an
/// argument: the ground first, then the divisions drawn on it, then the people
/// who work there, then the vocabularies a report is filled from. It runs from
/// the most concrete to the most abstract, which is the order somebody looking
/// for a list will guess.
///
/// Anything not on this list — a section a later migration invents, or a set
/// nobody filed — falls to the end under "other". Never hidden: a list nobody
/// can find is a list nobody can correct.
const _shelfOrder = ['places', 'structure', 'mission', 'reports'];

List<_Shelf> _shelve(List<ReferenceSet> sets) {
  final held = <String?, List<ReferenceSet>>{};
  for (final set in sets) {
    final key = _shelfOrder.contains(set.section) ? set.section : null;
    held.putIfAbsent(key, () => []).add(set);
  }
  return [
    for (final section in _shelfOrder)
      if (held[section] != null) (section: section, sets: held[section]!),
    if (held[null] != null) (section: null, sets: held[null]!),
  ];
}

String _shelfTitle(AppLocalizations l, String? section) => switch (section) {
  'places' => l.referenceShelfPlaces,
  'structure' => l.referenceShelfStructure,
  'mission' => l.referenceShelfMission,
  'reports' => l.referenceShelfReports,
  _ => l.referenceShelfOther,
};

IconData _shelfIcon(String? section) => switch (section) {
  'places' => AppIcons.location,
  'structure' => AppIcons.modules,
  'mission' => AppIcons.participants,
  'reports' => AppIcons.tasks,
  _ => AppIcons.referenceData,
};

class _SetCard extends StatelessWidget {
  const _SetCard({required this.set});

  final ReferenceSet set;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () {
        final cubit = context.read<ReferenceDataCubit>();
        Navigator.of(context).push(
          fadeThroughRoute(
            (_) => BlocProvider.value(
              value: cubit,
              child: ReferenceSetScreen(setId: set.id),
            ),
          ),
        );
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
            // The shelf's glyph rather than one generic "data" icon on every
            // card — a list of hotels should look like a place before it is
            // read.
            child: Icon(
              _shelfIcon(
                _shelfOrder.contains(set.section) ? set.section : null,
              ),
              size: 22,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  set.name.of(context),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  // Counts what the set screen will actually show: this season's.
                  l.referenceItemsCount(
                    set
                        .itemsForSeason(
                          context.watch<ReferenceDataCubit>().state.season?.id,
                        )
                        .length,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const NavChevron(),
        ],
      ),
    );
  }
}
