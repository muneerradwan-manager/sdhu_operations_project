import 'package:equatable/equatable.dart';

import '../../../core/attachments/attachment.dart';
import '../../../core/bloc/safe_cubit.dart';
import '../data/travel_repository.dart';
import '../domain/journey_leg.dart';
import '../domain/trip.dart';

enum TripDetailStatus { loading, ready, error }

class TripDetailState extends Equatable {
  const TripDetailState({
    this.status = TripDetailStatus.loading,
    this.passengers = const [],
    this.attachments = const [],
    this.busyLegIds = const {},
    this.outcome,
    this.error,
  });

  final TripDetailStatus status;
  final List<TripPassenger> passengers;
  final List<StoredAttachment> attachments;

  /// Rows mid-write, so each shows its own spinner instead of the page
  /// flickering under everybody's hands.
  final Set<String> busyLegIds;

  /// What the last assignment did — "27 assigned, 3 moved, 1 already aboard".
  /// Held in state rather than returned, because it is shown as a snackbar
  /// after a reload the caller has already stopped awaiting.
  final AssignOutcome? outcome;

  final String? error;

  int get confirmedCount => passengers.where((p) => p.isConfirmed).length;

  /// Those the trip has not yet been told about. What the "mark all arrived"
  /// prompt offers to close out — an OFFER, never a write of its own (BR-6).
  List<TripPassenger> get unconfirmed =>
      passengers.where((p) => p.status.awaitsConfirmation).toList();

  TripDetailState copyWith({
    TripDetailStatus? status,
    List<TripPassenger>? passengers,
    List<StoredAttachment>? attachments,
    Set<String>? busyLegIds,
    AssignOutcome? outcome,
    bool clearOutcome = false,
    String? error,
  }) => TripDetailState(
    status: status ?? this.status,
    passengers: passengers ?? this.passengers,
    attachments: attachments ?? this.attachments,
    busyLegIds: busyLegIds ?? this.busyLegIds,
    outcome: clearOutcome ? null : (outcome ?? this.outcome),
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    passengers.map((p) => '${p.legId}${p.status}').join(),
    attachments.length,
    busyLegIds,
    outcome?.assigned,
    outcome?.rebooked,
    outcome?.skipped,
    error,
  ];
}

/// One trip: who is on it, and everything done to that list.
class TripDetailCubit extends SafeCubit<TripDetailState> {
  TripDetailCubit(this._repo, this.tripId) : super(const TripDetailState()) {
    load();
  }

  final TravelRepository _repo;
  final String tripId;

  Future<void> load() async {
    emit(state.copyWith(status: TripDetailStatus.loading, error: null));
    try {
      final passengers = await _repo.fetchPassengers(tripId);
      final attachments = await _repo.fetchTripAttachments(tripId);
      emit(
        state.copyWith(
          status: TripDetailStatus.ready,
          passengers: passengers,
          attachments: attachments,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: TripDetailStatus.error, error: '$e'));
    }
  }

  /// Puts a group aboard in one call. Anybody already on another flight of the
  /// same role is MOVED, not duplicated, and their old leg is kept (BR-5) —
  /// which is why this is one RPC and not a loop of inserts.
  ///
  /// Takes **profile** ids, because that is what every employee picker in this
  /// app deals in — five features share it and none of the others knows what a
  /// season participation is. The translation to participations happens on the
  /// server, against the trip's own season (0132), which is the only season
  /// that can be right: doing it here would mean the phone deciding which year
  /// a man belongs to, and getting it wrong reads as the baffling refusal «a
  /// leg cannot put a participant of one season on a trip of another».
  Future<void> assign(List<String> profileIds) async {
    if (profileIds.isEmpty) return;
    emit(state.copyWith(clearOutcome: true, error: null));
    try {
      final outcome = await _repo.assignProfiles(
        tripId: tripId,
        profileIds: profileIds,
      );
      await load();
      emit(state.copyWith(outcome: outcome));
    } catch (e) {
      emit(state.copyWith(error: '$e'));
    }
  }

  Future<void> unassign(String legId) async {
    await _write(legId, () => _repo.unassign(legId));
  }

  Future<void> confirmOne(
    String legId, {
    required LegStatus status,
    DateTime? arrivedAt,
  }) async {
    await _write(
      legId,
      () => _repo.confirm(legId: legId, status: status, arrivedAt: arrivedAt),
    );
  }

  /// Closes out everybody still waiting, in one press.
  ///
  /// This is the "the flight has landed — mark its 57 passengers arrived?"
  /// action, and it is worth being precise about what it is: the OFFER is made
  /// by the screen because the trip's status changed, and this is a person
  /// accepting it. Nothing in the database ever does it unasked (BR-6).
  Future<void> confirmAll({required LegStatus status}) async {
    final ids = state.unconfirmed.map((p) => p.legId).toList();
    if (ids.isEmpty) return;
    emit(state.copyWith(busyLegIds: ids.toSet(), error: null));
    try {
      for (final id in ids) {
        await _repo.confirm(legId: id, status: status);
      }
      await load();
    } catch (e) {
      emit(state.copyWith(busyLegIds: const {}, error: '$e'));
    }
  }

  Future<void> attach(List<PendingAttachment> files) async {
    if (files.isEmpty) return;
    try {
      await _repo.attachToTrip(tripId, files);
      await load();
    } catch (e) {
      emit(state.copyWith(error: '$e'));
    }
  }

  Future<String> signedUrl(
    String path, {
    bool download = false,
    String? downloadName,
  }) => _repo.signedUrl(path, download: download, downloadName: downloadName);

  Future<void> _write(String legId, Future<void> Function() action) async {
    emit(state.copyWith(busyLegIds: {...state.busyLegIds, legId}, error: null));
    try {
      await action();
      await load();
    } catch (e) {
      emit(
        state.copyWith(
          busyLegIds: {...state.busyLegIds}..remove(legId),
          error: '$e',
        ),
      );
    }
  }
}
