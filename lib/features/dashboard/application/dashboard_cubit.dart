import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_stats.dart';

enum DashboardStatus { loading, ready, error }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.loading,
    this.seasons = const [],
    this.selectedSeasonId,
    this.stats = const DashboardStats(),
    this.error,
  });

  final DashboardStatus status;

  /// Every season, newest first — the filter's own list.
  final List<DashboardSeason> seasons;

  /// Null until the first load answers with whichever season is current.
  final String? selectedSeasonId;

  final DashboardStats stats;
  final String? error;

  DashboardSeason? get selectedSeason =>
      seasons.where((s) => s.id == selectedSeasonId).firstOrNull;

  DashboardState copyWith({
    DashboardStatus? status,
    List<DashboardSeason>? seasons,
    String? selectedSeasonId,
    DashboardStats? stats,
    String? error,
  }) {
    return DashboardState(
      status: status ?? this.status,
      seasons: seasons ?? this.seasons,
      selectedSeasonId: selectedSeasonId ?? this.selectedSeasonId,
      stats: stats ?? this.stats,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, seasons, selectedSeasonId, stats, error];
}

/// Loads the season list once and the figures once per season chosen.
///
/// The seasons are fetched alongside the first set of figures rather than
/// before them, so the page arrives whole: a filter that appears a moment
/// before the thing it filters invites a tap that is about to be overwritten.
class DashboardCubit extends SafeCubit<DashboardState> {
  DashboardCubit(this._repo) : super(const DashboardState()) {
    load();
  }

  final DashboardRepository _repo;

  Future<void> load({String? seasonId}) async {
    emit(state.copyWith(status: DashboardStatus.loading));
    try {
      // The season list only ever changes when an admin opens a new one, so it
      // is fetched once and kept; only the figures are re-read on a switch.
      final seasons = state.seasons.isEmpty
          ? await _repo.fetchSeasons()
          : state.seasons;
      final stats = await _repo.fetchStats(
        seasonId: seasonId ?? state.selectedSeasonId,
      );
      emit(
        state.copyWith(
          status: DashboardStatus.ready,
          seasons: seasons,
          // What the database ACTUALLY answered about, which on the first load
          // is whichever season is current — the app never had to know which.
          selectedSeasonId: stats.season?.id ?? seasonId,
          stats: stats,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: DashboardStatus.error, error: '$e'));
    }
  }

  Future<void> selectSeason(String seasonId) {
    if (seasonId == state.selectedSeasonId) return Future.value();
    return load(seasonId: seasonId);
  }

  Future<void> refresh() => load();
}
