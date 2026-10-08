import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/utils/arabic_search.dart';
import '../../profile/domain/profile.dart';
import '../data/seasons_repository.dart';

enum ParticipantsStatus { loading, ready, error }

class SeasonParticipantsState extends Equatable {
  const SeasonParticipantsState({
    this.status = ParticipantsStatus.loading,
    this.employees = const [],
    this.participantIds = const {},
    this.busy = const {},
    this.query = '',
    this.error,
  });

  final ParticipantsStatus status;
  final List<Profile> employees;
  final Set<String> participantIds;
  final Set<String> busy;
  final String query;
  final String? error;

  List<Profile> get filtered {
    if (query.trim().isEmpty) return employees;
    return employees
        .where((e) => arabicMatchesAll([e.fullName], query))
        .toList();
  }

  SeasonParticipantsState copyWith({
    ParticipantsStatus? status,
    List<Profile>? employees,
    Set<String>? participantIds,
    Set<String>? busy,
    String? query,
    String? error,
  }) {
    return SeasonParticipantsState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      participantIds: participantIds ?? this.participantIds,
      busy: busy ?? this.busy,
      query: query ?? this.query,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    employees,
    participantIds,
    busy,
    query,
    error,
  ];
}

class SeasonParticipantsCubit extends SafeCubit<SeasonParticipantsState> {
  SeasonParticipantsCubit(this._repo, this.seasonId)
    : super(const SeasonParticipantsState()) {
    _load();
  }

  final SeasonsRepository _repo;
  final String seasonId;

  Future<void> _load() async {
    emit(state.copyWith(status: ParticipantsStatus.loading));
    try {
      final results = await Future.wait([
        _repo.fetchAssignableEmployees(),
        _repo.fetchParticipantIds(seasonId),
      ]);
      emit(
        state.copyWith(
          status: ParticipantsStatus.ready,
          employees: results[0] as List<Profile>,
          participantIds: results[1] as Set<String>,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: ParticipantsStatus.error, error: e.toString()),
      );
    }
  }

  void search(String q) => emit(state.copyWith(query: q));

  /// True when every currently-listed (filtered) employee participates.
  bool get allSelected {
    final ids = state.filtered.map((e) => e.id);
    return ids.isNotEmpty && ids.every(state.participantIds.contains);
  }

  /// Adds every filtered employee (when not all selected) or withdraws them all.
  Future<void> toggleAll() async {
    final filtered = state.filtered;
    if (filtered.isEmpty) return;
    final selectAll = !allSelected;
    final targets = selectAll
        ? filtered.where((e) => !state.participantIds.contains(e.id)).toList()
        : filtered.where((e) => state.participantIds.contains(e.id)).toList();
    if (targets.isEmpty) return;

    emit(state.copyWith(busy: {...state.busy, ...targets.map((e) => e.id)}));
    try {
      for (final e in targets) {
        if (selectAll) {
          await _repo.addParticipant(seasonId, e.id);
        } else {
          await _repo.removeParticipant(seasonId, e.id);
        }
      }
      final ids = targets.map((e) => e.id).toSet();
      emit(
        state.copyWith(
          participantIds: selectAll
              ? {...state.participantIds, ...ids}
              : state.participantIds.difference(ids),
          busy: state.busy.difference(ids),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          busy: state.busy.difference(targets.map((t) => t.id).toSet()),
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> toggle(String profileId) async {
    if (state.busy.contains(profileId)) return;
    final participating = state.participantIds.contains(profileId);
    emit(state.copyWith(busy: {...state.busy, profileId}));
    try {
      if (participating) {
        await _repo.removeParticipant(seasonId, profileId);
        emit(
          state.copyWith(
            participantIds: state.participantIds.difference({profileId}),
            busy: state.busy.difference({profileId}),
          ),
        );
      } else {
        await _repo.addParticipant(seasonId, profileId);
        emit(
          state.copyWith(
            participantIds: {...state.participantIds, profileId},
            busy: state.busy.difference({profileId}),
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          busy: state.busy.difference({profileId}),
          error: e.toString(),
        ),
      );
    }
  }
}
