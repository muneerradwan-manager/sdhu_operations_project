import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/attachments/attachment_picker.dart';
import '../../../core/attachments/attachments_view.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../../../core/widgets/overflow_menu.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../../modules/presentation/employee_picker_screen.dart';
import '../application/trip_detail_cubit.dart';
import '../application/trips_cubit.dart';
import '../data/travel_repository.dart';
import '../domain/journey_leg.dart';
import '../domain/trip.dart';
import 'travel_labels.dart';
import 'widgets/trip_editor_sheet.dart';

/// One trip, and everything done to the list of people on it.
///
/// This is where the «إنشاء رحلة ثم إسناد مجموعة» requirement lands. The
/// assignment itself is one atomic RPC and not a loop, because moving a man who
/// is already on another flight of the same kind has to keep his old leg
/// (BR-5) — and a rule like that must exist in exactly one place.
class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key, required this.tripId, this.trip});

  final String tripId;

  /// Handed in when the board already had it, to spare a round trip. The
  /// passengers are always fetched.
  final Trip? trip;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => TripDetailCubit(TravelRepository(), tripId)),
      BlocProvider(create: (_) => TripsCubit(TravelRepository())),
    ],
    child: _View(tripId: tripId, seed: trip),
  );
}

class _View extends StatelessWidget {
  const _View({required this.tripId, this.seed});

  final String tripId;
  final Trip? seed;

  Trip? _trip(TripsState state) {
    for (final t in state.trips) {
      if (t.id == tripId) return t;
    }
    return seed;
  }

  /// Opens the shared employee picker, pre-selected with everybody already
  /// aboard so a second visit adds people rather than replacing them.
  Future<void> _assign(BuildContext context, Trip trip) async {
    final detail = context.read<TripDetailCubit>();
    final l = context.l10n;
    final picked = await showEmployeePicker(
      context,
      title: l.travelAssign,
      seasonId: trip.seasonId,
      selected: {for (final p in detail.state.passengers) p.profileId},
    );
    if (picked == null) return;
    await detail.assign(picked.toList());
  }

  /// The quick way at four hundred people: everybody who has no leg of this
  /// kind at all. The single most useful selection the room can be offered,
  /// and the answer to «لا أريد اختيار الموظفين واحداً واحداً».
  Future<void> _assignUnassigned(BuildContext context, Trip trip) async {
    final detail = context.read<TripDetailCubit>();
    final l = context.l10n;
    final repo = TravelRepository();
    final ids = await repo.withoutLeg(role: trip.role, seasonId: trip.seasonId);
    if (!context.mounted) return;
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.travelGapsClear)));
      return;
    }
    // Still through the picker, never straight into the database: eighty people
    // assigned by one press with no chance to look at the list first is not a
    // convenience, it is a mistake waiting to be made.
    final picked = await showEmployeePicker(
      context,
      title: l.travelAssign,
      seasonId: trip.seasonId,
      selected: ids.toSet(),
    );
    if (picked == null) return;
    await detail.assign(picked.toList());
  }

  Future<void> _edit(BuildContext context, Trip trip) async {
    final trips = context.read<TripsCubit>();
    final draft = await showTripEditorSheet(
      context,
      points: trips.state.points,
      existing: trip,
    );
    if (draft == null) return;
    await trips.update(trip.id, draft);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.watch<SessionCubit>().state;
    final canEdit = session.can(PermissionCodes.travelEdit);
    final canAssign = session.can(PermissionCodes.travelAssign);
    final canConfirm = session.can(PermissionCodes.travelConfirm);
    final canDelete = session.can(PermissionCodes.travelDelete);

    return BlocBuilder<TripsCubit, TripsState>(
      builder: (context, tripsState) {
        final trip = _trip(tripsState);

        return Scaffold(
          appBar: GlassAppBar(
            title: Text(l.travelTripDetailTitle),
            actions: [
              if (trip != null)
                OverflowMenu(
                  actions: [
                    if (canEdit)
                      MenuAction(
                        icon: AppIcons.edit,
                        label: l.travelEditTrip,
                        onSelected: () => _edit(context, trip),
                      ),
                    if (canEdit && !trip.status.isCancelled)
                      MenuAction(
                        icon: AppIcons.reject,
                        label: l.travelCancelTrip,
                        isDestructive: true,
                        onSelected: () => context.read<TripsCubit>().setStatus(
                          trip.id,
                          TripStatus.cancelled,
                        ),
                      ),
                    if (canDelete)
                      MenuAction(
                        icon: AppIcons.delete,
                        label: l.travelDeleteTrip,
                        isDestructive: true,
                        onSelected: () => _confirmDelete(context, trip),
                      ),
                  ],
                ),
            ],
          ),
          floatingActionButton: canAssign && trip != null
              ? FloatingActionButton.extended(
                  onPressed: () => _assign(context, trip),
                  icon: const Icon(AppIcons.addUser),
                  label: Text(l.travelAssign),
                )
              : null,
          body: SafeArea(
            child: BlocConsumer<TripDetailCubit, TripDetailState>(
              listenWhen: (p, c) =>
                  (c.error != null && p.error != c.error) ||
                  (c.outcome != null && p.outcome != c.outcome),
              listener: (context, state) {
                final messenger = ScaffoldMessenger.of(context);
                if (state.error != null) {
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(friendlyError(context, state.error)),
                      ),
                    );
                  return;
                }
                final outcome = state.outcome;
                if (outcome != null) {
                  // Said in numbers, because "27 assigned, 3 moved off another
                  // flight" is exactly what the person who pressed the button
                  // needs to know and cannot see from the list.
                  // Only mentioned when it happened. A trailing "and 0 are not
                  // participants" on every successful assignment is noise that
                  // teaches the reader to stop reading the sentence.
                  final said = [
                    l.travelAssignOutcome(
                      outcome.assigned,
                      outcome.rebooked,
                      outcome.skipped,
                    ),
                    if (outcome.notInSeason > 0)
                      l.travelAssignNotInSeason(outcome.notInSeason),
                  ].join(' — ');
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(said)));
                }
              },
              builder: (context, state) {
                if (state.status == TripDetailStatus.loading || trip == null) {
                  return const SkeletonList(height: 72);
                }

                return ResponsivePage(
                  builder: (context, size) => SinglePaneLayout(
                    gutter: size.gutter,
                    // Room for the assign FAB to sit over, and nothing more:
                    // `scrollPadding` already adds the safe-area inset.
                    bottom: AppSpacing.xxl * 2,
                    children: staggered([
                      _TripHeader(trip: trip),
                      const SizedBox(height: AppSpacing.lg),
                      if (canConfirm && state.unconfirmed.isNotEmpty) ...[
                        _ConfirmAllCard(count: state.unconfirmed.length),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _Passengers(
                        state: state,
                        canAssign: canAssign,
                        canConfirm: canConfirm,
                        onFillGaps: () => _assignUnassigned(context, trip),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _Attachments(state: state, canEdit: canEdit),
                    ]),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Trip trip) async {
    final l = context.l10n;
    final cubit = context.read<TripsCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.travelDeleteTrip),
        content: Text(l.travelDeleteTripConfirm),
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
    if (ok != true || !context.mounted) return;
    final done = await cubit.delete(trip.id);
    if (done && context.mounted) Navigator.of(context).pop();
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return InfoSection(
      title: legRoleLabel(context, trip.role),
      icon: travelModeIcon(trip.mode),
      children: [
        InfoRow(
          icon: AppIcons.travel,
          label: l.travelFieldFrom,
          value: trip.fromPoint.of(context),
        ),
        InfoRow(
          icon: AppIcons.location,
          label: l.travelFieldTo,
          value: trip.toPoint.of(context),
        ),
        InfoRow(
          icon: AppIcons.travelWhen,
          label: l.travelFieldDeparture,
          value: travelWhen(context, trip.plannedDepartureAt),
        ),
        if (trip.plannedArrivalAt != null)
          InfoRow(
            icon: AppIcons.pending,
            label: l.travelFieldArrival,
            value: travelWhen(context, trip.plannedArrivalAt),
          ),
        if (trip.tripNumber != null && trip.tripNumber!.isNotEmpty)
          InfoRow(
            icon: AppIcons.travelTicket,
            label: l.travelFieldNumber,
            value: trip.tripNumber,
          ),
        InfoRow(
          icon: AppIcons.pending,
          label: l.travelTripState,
          value: tripStatusLabel(context, trip.status),
        ),
        InfoRow(
          icon: AppIcons.employees,
          label: l.travelPassengers,
          value: l.travelAssignedCount(trip.assignedCount),
        ),
        if (trip.note != null && trip.note!.isNotEmpty)
          InfoRow(
            icon: AppIcons.reports,
            label: l.travelFieldNote,
            value: trip.note,
          ),
      ],
    );
  }
}

/// The offer made after a flight lands.
///
/// It is an OFFER and the wording says so: the aeroplane arriving is a fact
/// about the aeroplane, and whether any particular man was on it is a separate
/// claim that only a person may make (BR-6). Nothing in the database ever
/// writes these rows unasked.
class _ConfirmAllCard extends StatelessWidget {
  const _ConfirmAllCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final gold = Accent.gold.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.pending, size: 18, color: gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(l.travelConfirmAllPrompt(count))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: () => context.read<TripDetailCubit>().confirmAll(
                status: LegStatus.completed,
              ),
              icon: const Icon(AppIcons.approve, size: 18),
              label: Text(l.travelConfirmAll),
            ),
          ),
        ],
      ),
    );
  }
}

class _Passengers extends StatelessWidget {
  const _Passengers({
    required this.state,
    required this.canAssign,
    required this.canConfirm,
    required this.onFillGaps,
  });

  final TripDetailState state;
  final bool canAssign;
  final bool canConfirm;
  final VoidCallback onFillGaps;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    if (state.passengers.isEmpty) {
      return EmptyState(
        icon: AppIcons.employees,
        title: l.travelNoPassengers,
        action: canAssign
            ? FilledButton.tonalIcon(
                onPressed: onFillGaps,
                icon: const Icon(AppIcons.addUser),
                label: Text(l.travelAssign),
              )
            : null,
      );
    }

    // Left to lay itself out: [InfoSection] counts columns from the width it is
    // given, so a manifest of sixty reads as one list on a phone and as two or
    // three on the desktop the room actually works from. Pinning it to one
    // column — which this did — turned a flight's roster into a mile of
    // scrolling on the widest screen in the building.
    return InfoSection(
      title: l.travelPassengers,
      icon: AppIcons.employees,
      separated: false,
      children: [
        for (final passenger in state.passengers)
          _PassengerRow(
            passenger: passenger,
            busy: state.busyLegIds.contains(passenger.legId),
            canAssign: canAssign,
            canConfirm: canConfirm,
          ),
      ],
    );
  }
}

class _PassengerRow extends StatelessWidget {
  const _PassengerRow({
    required this.passenger,
    required this.busy,
    required this.canAssign,
    required this.canConfirm,
  });

  final TripPassenger passenger;
  final bool busy;
  final bool canAssign;
  final bool canConfirm;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<TripDetailCubit>();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: busy
          ? const SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : ProfileAvatar(
              photoUrl: passenger.photoUrl,
              name: passenger.fullName,
              radius: 20,
            ),
      title: Text(passenger.fullName.isEmpty ? '—' : passenger.fullName),
      subtitle: Text(
        [
          legStatusLabel(context, passenger.status),
          if (passenger.seat != null && passenger.seat!.isNotEmpty)
            passenger.seat!,
        ].join(' · '),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: legStatusColor(context, passenger.status),
        ),
      ),
      trailing: busy
          ? null
          : OverflowMenu(
              actions: [
                if (canConfirm && passenger.status.awaitsConfirmation) ...[
                  MenuAction(
                    icon: AppIcons.approve,
                    label: l.travelLegCompleted,
                    onSelected: () => cubit.confirmOne(
                      passenger.legId,
                      status: LegStatus.completed,
                    ),
                  ),
                  MenuAction(
                    icon: AppIcons.reject,
                    label: l.travelLegMissed,
                    onSelected: () => cubit.confirmOne(
                      passenger.legId,
                      status: LegStatus.missed,
                    ),
                  ),
                ],
                if (canAssign)
                  MenuAction(
                    icon: AppIcons.suspend,
                    label: l.travelRemoveFromTrip,
                    isDestructive: true,
                    onSelected: () => cubit.unassign(passenger.legId),
                  ),
              ],
            ),
    );
  }
}

/// The ticket, the manifest, the schedule as the airline sent it.
///
/// One file or twenty, PDF or photograph — the whole picker the rest of this
/// app uses ([pickAttachment]: camera, gallery, or any file), uploading into a
/// private bucket that only this trip's passengers and the travel team may read
/// (0129). The list is deliberately given a sentence when it is empty rather
/// than being drawn as a blank: an empty section with a button under it reads
/// as broken, and «لا مرفقات» reads as a fact.
class _Attachments extends StatelessWidget {
  const _Attachments({required this.state, required this.canEdit});

  final TripDetailState state;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<TripDetailCubit>();

    Future<void> add() async {
      final picked = await pickAttachment(context);
      if (picked != null) await cubit.attach([picked]);
    }

    return InfoSection(
      title: l.travelAttachments,
      icon: AppIcons.file,
      separated: false,
      maxColumns: 1,
      children: [
        if (state.attachments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              canEdit ? l.travelNoAttachmentsHint : l.travelNoAttachments,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          AttachmentsView(
            attachments: state.attachments,
            signer: cubit.signedUrl,
          ),
        if (canEdit)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: add,
              icon: const Icon(AppIcons.add, size: 18),
              label: Text(l.travelAddAttachment),
            ),
          ),
      ],
    );
  }
}
