import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/travel_repository.dart';
import '../domain/journey.dart';
import '../domain/journey_leg.dart';
import '../domain/trip.dart';

enum JourneyStatus { loading, ready, error }

class JourneyState extends Equatable {
  const JourneyState({
    this.status = JourneyStatus.loading,
    this.journey,
    this.points = const [],
    this.busyLegId,
    this.error,
  });

  final JourneyStatus status;

  /// Null while loading, and also when this man is not in the season at all —
  /// which is an ordinary answer for a great many accounts in any given year,
  /// and reads as "no travel recorded" rather than as a failure.
  final Journey? journey;

  /// The places a self-arranged movement may be recorded between. Loaded with
  /// the journey so the record sheet opens instantly.
  final List<TravelPoint> points;

  /// The one leg currently being confirmed, so its row can show a spinner
  /// without the whole page going blank under the reader.
  final String? busyLegId;

  final String? error;

  bool get isEmpty => journey?.isEmpty ?? true;

  JourneyState copyWith({
    JourneyStatus? status,
    Journey? journey,
    List<TravelPoint>? points,
    String? busyLegId,
    bool clearBusy = false,
    String? error,
  }) => JourneyState(
    status: status ?? this.status,
    journey: journey ?? this.journey,
    points: points ?? this.points,
    busyLegId: clearBusy ? null : (busyLegId ?? this.busyLegId),
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    journey?.allLegs.length,
    journey?.legs.map((l) => '${l.id}${l.status}').join(),
    points.length,
    busyLegId,
    error,
  ];
}

/// One man's journey: reading it, and the two things he may do to it himself.
///
/// [participantId] is null when the person has no participation in this season.
/// That is not an error state — the screen says so in a sentence — so it is
/// resolved once here rather than being an exception every screen must catch.
class JourneyCubit extends SafeCubit<JourneyState> {
  JourneyCubit(this._repo, {this.participantId, this.profileId})
    : super(const JourneyState()) {
    load();
  }

  final TravelRepository _repo;

  /// Whose journey, when the caller already knew the participation row.
  final String? participantId;

  /// Whose journey, when the caller knew the person but not their
  /// participation row. Null for both means "the reader's own".
  final String? profileId;

  /// Filled in by [load] once the participation has been looked up. Held apart
  /// from [participantId] so the seed the screen was built with stays what it
  /// was — a reload must not depend on what the last one happened to resolve.
  String? _resolved;

  /// Whose journey this actually is, once known.
  String? get resolvedParticipantId => _resolved ?? participantId;

  Future<void> load() async {
    emit(state.copyWith(status: JourneyStatus.loading));
    try {
      // Resolve whose journey this is, if the caller only knew the person.
      final of = profileId;
      _resolved ??=
          participantId ??
          (of == null
              ? await _repo.myParticipation()
              : await _repo.participationOf(of));

      final id = _resolved;
      if (id == null) {
        // Not in the season. An empty journey, not an error.
        emit(
          JourneyState(
            status: JourneyStatus.ready,
            journey: Journey(participantId: '', legs: const []),
          ),
        );
        return;
      }

      final journey = await _repo.fetchJourney(id);
      final points = state.points.isEmpty
          ? await _repo.fetchPoints()
          : state.points;
      emit(
        JourneyState(
          status: JourneyStatus.ready,
          journey: journey,
          points: points,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: JourneyStatus.error, error: '$e'));
    }
  }

  /// Records what happened to one movement.
  ///
  /// Allowed to the traveller for his own legs and to whoever holds
  /// `travel.confirm` for anybody's — the database decides which, and a refusal
  /// arrives here as an error rather than being predicted in the UI.
  Future<void> confirm(
    String legId, {
    required LegStatus status,
    DateTime? departedAt,
    DateTime? arrivedAt,
  }) async {
    emit(state.copyWith(busyLegId: legId, error: null));
    try {
      await _repo.confirm(
        legId: legId,
        status: status,
        departedAt: departedAt,
        arrivedAt: arrivedAt,
      );
      await load();
    } catch (e) {
      emit(state.copyWith(clearBusy: true, error: '$e'));
    }
  }

  /// Records a movement he arranged himself — the private car, and everything
  /// like it. The one write in this feature a man may make about his own
  /// travel without holding any permission at all.
  Future<void> recordSelfLeg(SelfLegDraft draft) async {
    final id = resolvedParticipantId;
    if (id == null) return;
    emit(state.copyWith(error: null));
    try {
      await _repo.recordSelfLeg(participantId: id, draft: draft);
      await load();
    } catch (e) {
      emit(state.copyWith(error: '$e'));
    }
  }
}
