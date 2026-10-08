import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/creator_page.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../application/trips_cubit.dart';
import '../data/travel_repository.dart';
import '../domain/trip.dart';
import 'travel_gaps_screen.dart';
import 'travel_labels.dart';
import 'trip_detail_screen.dart';
import 'widgets/trip_editor_sheet.dart';

/// The season's trips, one part of it at a time — القدوم, التنقل الداخلي,
/// العودة — chosen with the segmented control at the top rather than shown
/// all together. A season may carry a huge number of each, and a board that
/// concatenated all three into one scroll would bury العودة under however
/// many arrivals came before it; the segmented control is the navigation, not
/// a narrowing on top of some other view.
///
/// The counter on each card is the number the room lives by: a flight is
/// interesting when it is full and alarming when it is empty two days out. It
/// counts LIVE legs only — people moved off a flight are kept in the table
/// precisely so that nobody has to delete them to make this figure right.
class TripsBoardScreen extends StatelessWidget {
  const TripsBoardScreen({super.key, this.seasonId});

  final String? seasonId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => TripsCubit(TravelRepository(), seasonId: seasonId),
    child: const _View(),
  );
}

class _View extends StatelessWidget {
  const _View();

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<TripsCubit>();
    final draft = await showTripEditorSheet(
      context,
      points: cubit.state.points,
    );
    if (draft == null) return;
    final id = await cubit.create(draft);
    if (id == null || !context.mounted) return;
    // Straight into the new trip, because entering a flight and then putting
    // people on it is one errand, not two.
    await Navigator.of(
      context,
    ).push(fadeThroughRoute((_) => TripDetailScreen(tripId: id)));
    if (context.mounted) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.watch<SessionCubit>().state;
    final canEdit = session.can(PermissionCodes.travelEdit);

    return Scaffold(
      appBar: GlassAppBar(
        title: Text(l.travelTripsTitle),
        actions: [
          IconButton(
            tooltip: l.travelGapsTitle,
            icon: const Icon(AppIcons.warning),
            onPressed: () => Navigator.of(
              context,
            ).push(fadeThroughRoute((_) => const TravelGapsScreen())),
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? CreateFab(label: l.travelNewTrip, onPressed: () => _create(context))
          : null,
      body: SafeArea(
        child: BlocConsumer<TripsCubit, TripsState>(
          listenWhen: (p, c) => c.error != null && p.error != c.error,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(friendlyError(context, state.error))),
              );
          },
          builder: (context, state) {
            final cubit = context.read<TripsCubit>();

            return ResponsivePage(
              builder: (context, size) => Column(
                children: [
                  SearchFilterBar(
                    hint: l.commonSearch,
                    onChanged: cubit.search,
                    filters: _Filters(state: state, cubit: cubit),
                  ),
                  Expanded(
                    child: switch (state.status) {
                      TripsStatus.loading => const SkeletonList(height: 84),
                      TripsStatus.error => EmptyState(
                        icon: AppIcons.warning,
                        title: friendlyError(context, state.error),
                      ),
                      TripsStatus.ready when state.trips.isEmpty => EmptyState(
                        icon: AppIcons.travel,
                        title: l.travelNoTrips,
                        message: l.travelNoTripsHint,
                      ),
                      // Two different empty screens: switching to a part of
                      // the season nothing has been entered for yet is not a
                      // failed search, and must not read as one.
                      TripsStatus.ready
                          when state.filtered.isEmpty && !state.isNarrowed =>
                        EmptyState(
                          icon: AppIcons.travel,
                          title: l.travelNoTripsInRole,
                          message: l.travelNoTripsHint,
                        ),
                      TripsStatus.ready when state.filtered.isEmpty =>
                        EmptyState(
                          icon: AppIcons.travel,
                          title: l.travelNoTripsMatch,
                        ),
                      TripsStatus.ready => _Board(
                        trips: state.inRole,
                        gutter: size.gutter,
                      ),
                    },
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

/// Which part of the season the board is open on. Always exactly one
/// selected — a [SegmentedButton], not chips that toggle off, because with a
/// season able to carry a "huge number" of arrivals, transfers and
/// departures apiece there is no view of "all of them" worth having; the
/// question the room actually asks is always "which of the three".
class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.cubit});

  final TripsState state;
  final TripsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final role = state.role ?? LegRole.inbound;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<LegRole>(
          segments: [
            for (final r in LegRole.values)
              ButtonSegment(
                value: r,
                icon: Icon(legRoleIcon(r), size: 16),
                label: Text(legRoleLabel(context, r)),
              ),
          ],
          selected: {role},
          showSelectedIcon: false,
          onSelectionChanged: (s) => cubit.filterRole(s.first),
        ),
        // Search text is the one thing left that narrows a role rather than
        // choosing between them, so it is the one thing "مسح" still answers
        // for.
        if (state.isNarrowed) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: cubit.clearFilters,
              icon: const Icon(AppIcons.reject, size: 16),
              label: Text(l.moduleRosterClear),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.trips, required this.gutter});

  final List<Trip> trips;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    // The same grid every list in this app uses: one column on a phone, three
    // or four on the operations-room desktop.
    return AdaptiveGridView(
      padding: EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.sm,
        gutter,
        AppSpacing.xxl * 2 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      spacing: AppSpacing.sm,
      itemCount: trips.length,
      itemBuilder: (context, i) => _TripCard(trip: trips[i]),
    );
  }
}

/// One vehicle, drawn the way every other card in this app draws a thing: an
/// accent icon block, a title, two lines of meta under it, and a row of
/// badges at the foot — not the thin single-row tile this card used to be,
/// which read as a list app borrowed for a screen the rest of the app was
/// never built like.
class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final accent = legRoleAccent(trip.role).of(context);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () => Navigator.of(
        context,
      ).push(fadeThroughRoute((_) => TripDetailScreen(tripId: trip.id))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Icon(travelModeIcon(trip.mode), size: 22, color: accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The route is the identity: a flight is created once and
                // never renamed, same as a file's type in الملفات.
                Text(
                  '${trip.fromPoint.of(context)} ← ${trip.toPoint.of(context)}',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  travelWhen(context, trip.plannedDepartureAt),
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (trip.label != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    trip.label!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
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
                    // Absence is never red (BR-12) — scheduled wears no badge
                    // at all, and only what actually happened earns a colour.
                    if (trip.status != TripStatus.scheduled)
                      GlassBadge(
                        label: tripStatusLabel(context, trip.status),
                        color: tripStatusColor(context, trip.status),
                        dense: true,
                      ),
                    GlassBadge(
                      label: l.travelAssignedCount(trip.assignedCount),
                      icon: AppIcons.travel,
                      color: trip.assignedCount == 0
                          ? scheme.onSurfaceVariant
                          : accent,
                      dense: true,
                    ),
                    if (trip.assignedCount > 0)
                      GlassBadge(
                        label: l.travelConfirmedOf(
                          trip.completedCount,
                          trip.assignedCount,
                        ),
                        color: scheme.onSurfaceVariant,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const NavChevron(),
        ],
      ),
    );
  }
}
