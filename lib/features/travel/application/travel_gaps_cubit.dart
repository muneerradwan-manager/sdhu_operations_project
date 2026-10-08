import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/utils/arabic_search.dart';
import '../data/travel_repository.dart';

enum GapsStatus { loading, ready, error }

class TravelGapsState extends Equatable {
  const TravelGapsState({
    this.status = GapsStatus.loading,
    this.gaps = const [],
    this.query = '',
    this.kind,
    this.error,
  });

  final GapsStatus status;
  final List<TravelGap> gaps;
  final String query;
  final TravelGapKind? kind;
  final String? error;

  List<TravelGap> get filtered {
    final q = query.trim();
    return gaps
        .where((g) {
          if (kind != null && g.kind != kind) return false;
          if (q.isEmpty) return true;
          return arabicMatchesAll([g.fullName, g.tripNumber], q);
        })
        .toList(growable: false);
  }

  /// One count per kind, for the tabs across the top. Computed from the
  /// unfiltered list so narrowing to one kind does not zero the others.
  Map<TravelGapKind, int> get counts {
    final out = <TravelGapKind, int>{};
    for (final g in gaps) {
      out[g.kind] = (out[g.kind] ?? 0) + 1;
    }
    return out;
  }

  Map<TravelGapKind, List<TravelGap>> get grouped {
    final out = <TravelGapKind, List<TravelGap>>{};
    for (final kind in TravelGapKind.values) {
      final of = filtered.where((g) => g.kind == kind).toList();
      if (of.isNotEmpty) out[kind] = of;
    }
    return out;
  }

  bool get isClear => gaps.isEmpty;

  TravelGapsState copyWith({
    GapsStatus? status,
    List<TravelGap>? gaps,
    String? query,
    TravelGapKind? kind,
    bool clearKind = false,
    String? error,
  }) => TravelGapsState(
    status: status ?? this.status,
    gaps: gaps ?? this.gaps,
    query: query ?? this.query,
    kind: clearKind ? null : (kind ?? this.kind),
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    gaps.map((g) => '${g.kind}${g.participantId}${g.legId}').join(),
    query,
    kind,
    error,
  ];
}

/// What is not answered — the screen the operations room opens every morning.
///
/// Deliberately not a list of everything: it holds only rows that need somebody
/// to do something, and every kind on it has an obvious next action. The rows
/// it does NOT carry are as much a part of the design as the ones it does —
/// see `travel_gaps` in 0130 for why an unrecorded مكة→المدينة transfer is
/// shown on the man's own timeline and never shouted about here.
class TravelGapsCubit extends SafeCubit<TravelGapsState> {
  TravelGapsCubit(this._repo, {this.seasonId})
    : super(const TravelGapsState()) {
    load();
  }

  final TravelRepository _repo;
  final String? seasonId;

  Future<void> load() async {
    emit(state.copyWith(status: GapsStatus.loading, error: null));
    try {
      final gaps = await _repo.fetchGaps(seasonId: seasonId);
      emit(state.copyWith(status: GapsStatus.ready, gaps: gaps));
    } catch (e) {
      emit(state.copyWith(status: GapsStatus.error, error: '$e'));
    }
  }

  void search(String value) => emit(state.copyWith(query: value));

  void filterKind(TravelGapKind? value) => value == null || state.kind == value
      ? emit(state.copyWith(clearKind: true))
      : emit(state.copyWith(kind: value));

  /// Says this man is not expected to travel at all — the answer to a
  /// `no_inbound` row for somebody already resident in the Kingdom. Removes him
  /// from every count on this screen, which is the whole point of the flag: a
  /// board that reports forty people who will never have a flight is a board
  /// nobody opens in the second week.
  Future<void> markDoesNotTravel(String participantId) async {
    try {
      await _repo.setTravels(participantId, false);
      await load();
    } catch (e) {
      emit(state.copyWith(error: '$e'));
    }
  }
}
