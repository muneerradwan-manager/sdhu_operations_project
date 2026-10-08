import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/utils/hijri_utils.dart';
import '../data/seasons_repository.dart';
import '../domain/season.dart';

enum SeasonsStatus { loading, loaded, error }

class SeasonsState extends Equatable {
  const SeasonsState({
    this.status = SeasonsStatus.loading,
    this.seasons = const [],
    this.error,
  });

  final SeasonsStatus status;
  final List<Season> seasons;
  final String? error;

  Season? get current => seasons.where((s) => s.isCurrent).firstOrNull;

  /// Seasons that come after the current one — the admin may pin an earlier
  /// season as current, which leaves later ones neither current nor past.
  List<Season> get upcoming {
    final year = current?.hijriYear;
    if (year == null) return const [];
    return seasons.where((s) => s.hijriYear > year).toList();
  }

  /// Seasons already behind the current one. With no current season set, every
  /// season falls here rather than disappearing from the screen.
  List<Season> get archive {
    final year = current?.hijriYear;
    if (year == null) return seasons;
    return seasons.where((s) => s.hijriYear < year).toList();
  }

  SeasonsState copyWith({
    SeasonsStatus? status,
    List<Season>? seasons,
    String? error,
  }) {
    return SeasonsState(
      status: status ?? this.status,
      seasons: seasons ?? this.seasons,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, seasons, error];
}

class SeasonsCubit extends SafeCubit<SeasonsState> {
  SeasonsCubit(this._repo, {required this.isAdmin})
    : super(const SeasonsState()) {
    load();
  }

  final SeasonsRepository _repo;
  final bool isAdmin;

  Future<void> load({bool ensureCurrent = true}) async {
    emit(state.copyWith(status: SeasonsStatus.loading));
    try {
      // Admins derive/refresh the current season from the Hijri calendar.
      if (isAdmin && ensureCurrent) {
        try {
          await _repo.ensureCurrentSeason(
            HijriUtils.currentYear(),
            HijriUtils.currentGregorianLabel(),
          );
        } catch (_) {
          // Non-fatal: still show whatever seasons exist.
        }
      }
      final seasons = await _repo.fetchSeasons();
      emit(state.copyWith(status: SeasonsStatus.loaded, seasons: seasons));
    } catch (e) {
      emit(state.copyWith(status: SeasonsStatus.error, error: e.toString()));
    }
  }

  Future<void> setCurrent(String seasonId) async {
    try {
      // Pinned to this Hijri year so ensureCurrentSeason respects the choice
      // until the calendar moves past it.
      await _repo.setCurrent(
        seasonId,
        pinnedForHijriYear: HijriUtils.currentYear(),
      );
      // Skip the ensure step: it would race the pin we just wrote.
      await load(ensureCurrent: false);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
