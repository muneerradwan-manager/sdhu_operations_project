import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../application/travel_gaps_cubit.dart';
import '../data/travel_repository.dart';
import 'my_journey_screen.dart';
import 'travel_labels.dart';

/// What is not answered — and nothing else.
///
/// This is the screen the operations room actually opens every morning, and it
/// earns that by being short. Everything on it needs somebody to do something,
/// and the rows it deliberately does NOT carry are as much of the design as the
/// ones it does:
///
///   * A man with no train booking is not here. He may have gone by car, and
///     «بسيارة خاصة» is a complete answer.
///   * Two legs whose endpoints do not meet are not here either. That fires on
///     مطار جدة → مكة for every arrival in the mission — the airport coach,
///     which nobody tracks and nobody needs to. A board whose commonest row
///     never needs acting on is a board that gets ignored by the second week.
///   * Anybody marked as not travelling is not here, which is what that flag
///     exists for.
class TravelGapsScreen extends StatelessWidget {
  const TravelGapsScreen({super.key, this.seasonId});

  final String? seasonId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => TravelGapsCubit(TravelRepository(), seasonId: seasonId),
    child: const _View(),
  );
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.watch<SessionCubit>().state;
    final canEdit = session.can(PermissionCodes.travelEdit);

    return Scaffold(
      appBar: GlassAppBar(title: Text(l.travelGapsTitle)),
      body: SafeArea(
        child: BlocConsumer<TravelGapsCubit, TravelGapsState>(
          listenWhen: (p, c) => c.error != null && p.error != c.error,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(friendlyError(context, state.error))),
              );
          },
          builder: (context, state) {
            final cubit = context.read<TravelGapsCubit>();

            if (state.status == GapsStatus.loading) {
              return const SkeletonList(height: 72);
            }
            if (state.isClear) {
              // Worth a real empty state rather than a blank list: "nothing
              // outstanding" is the answer this screen exists to give, and on a
              // good day it is the only one.
              return EmptyState(
                icon: AppIcons.approve,
                title: l.travelGapsClear,
                message: l.travelGapsClearHint,
              );
            }

            return ResponsivePage(
              builder: (context, size) => Column(
                children: [
                  SearchFilterBar(
                    hint: l.commonSearch,
                    onChanged: cubit.search,
                    filters: _KindFilters(state: state, cubit: cubit),
                  ),
                  Expanded(
                    child: _List(
                      state: state,
                      gutter: size.gutter,
                      canEdit: canEdit,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KindFilters extends StatelessWidget {
  const _KindFilters({required this.state, required this.cubit});

  final TravelGapsState state;
  final TravelGapsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final counts = state.counts;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final kind in TravelGapKind.values)
          if ((counts[kind] ?? 0) > 0)
            FilterChip(
              selected: state.kind == kind,
              onSelected: (_) => cubit.filterKind(kind),
              avatar: Icon(travelGapIcon(kind), size: 16),
              label: Text('${travelGapLabel(context, kind)} · ${counts[kind]}'),
              visualDensity: VisualDensity.compact,
            ),
      ],
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.state,
    required this.gutter,
    required this.canEdit,
  });

  final TravelGapsState state;
  final double gutter;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final entries = state.grouped.entries.toList();
    if (entries.isEmpty) {
      return EmptyState(
        icon: AppIcons.approve,
        title: context.l10n.travelGapsClear,
      );
    }

    // Sectioned rather than a plain column of cards. On a phone it reads as one
    // list; on the operations-room desktop the same rows lay out three abreast,
    // which is the difference between scrolling past ninety names and seeing
    // thirty of them. The columns are counted once for the whole list, so a
    // heading never re-flows the cards beneath it.
    return AdaptiveGridView.sectioned(
      padding: EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.sm,
        gutter,
        AppSpacing.xl + MediaQuery.viewPaddingOf(context).bottom,
      ),
      spacing: AppSpacing.sm,
      sections: [
        for (final entry in entries)
          GridSection(
            header: SectionHeader(
              '${travelGapLabel(context, entry.key)} · ${entry.value.length}',
              icon: travelGapIcon(entry.key),
            ),
            itemCount: entry.value.length,
            itemBuilder: (context, i) =>
                _GapRow(gap: entry.value[i], canEdit: canEdit),
          ),
      ],
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow({required this.gap, required this.canEdit});

  final TravelGap gap;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colour = travelGapColor(context, gap.kind);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _open(context),
      child: Row(
        children: [
          ProfileAvatar(photoUrl: gap.photoUrl, name: gap.fullName, radius: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gap.fullName.isEmpty ? '—' : gap.fullName,
                  style: text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    travelGapLabel(context, gap.kind),
                    if (gap.tripNumber != null) gap.tripNumber!,
                    if (gap.at != null) travelWhen(context, gap.at),
                  ].join(' · '),
                  style: text.bodySmall?.copyWith(color: colour),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // The one action this board offers directly, and only where it makes
          // sense: a man with no arrival flight who is already in the Kingdom
          // is not a gap at all, and saying so takes him off every count here.
          if (canEdit && gap.kind == TravelGapKind.noInbound)
            IconButton(
              tooltip: l.travelMarkDoesNotTravel,
              icon: Icon(AppIcons.suspend, color: scheme.onSurfaceVariant),
              onPressed: () => _markStays(context),
            )
          else
            const NavChevron(),
        ],
      ),
    );
  }

  /// Opens the man's own مساري, then re-asks the board once he is back.
  ///
  /// Confirming his arrival is the ordinary way an `unconfirmed` row on THIS
  /// screen gets answered, and it happens on the very screen this push opens
  /// — so a board that did not reload on return would keep showing him as
  /// outstanding until the reader left and came back, which read as the
  /// confirmation not having worked at all.
  Future<void> _open(BuildContext context) async {
    final cubit = context.read<TravelGapsCubit>();
    await Navigator.of(context).push(
      fadeThroughRoute(
        (_) => JourneyScreen(
          participantId: gap.participantId,
          title: gap.fullName,
        ),
      ),
    );
    if (context.mounted) await cubit.load();
  }

  Future<void> _markStays(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<TravelGapsCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.travelMarkDoesNotTravel),
        content: Text(l.travelMarkDoesNotTravelConfirm(gap.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.commonOk),
          ),
        ],
      ),
    );
    if (ok == true) await cubit.markDoesNotTravel(gap.participantId);
  }
}
