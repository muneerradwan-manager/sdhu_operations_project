import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../profile/domain/profile.dart';
import '../../seasons/data/seasons_repository.dart';
import '../../seasons/domain/season.dart';
import '../data/employees_repository.dart';

enum DirectoryStatus { loading, loaded, error }

class EmployeesDirectoryState extends Equatable {
  const EmployeesDirectoryState({
    this.status = DirectoryStatus.loading,
    this.permanent = const [],
    this.external = const [],
    this.season,
    this.error,
    this.savedAt,
  });

  final DirectoryStatus status;

  /// The Administration itself — the same people whatever season it is.
  final List<Profile> permanent;

  /// The externals of [season] only: a delegate is on the mission for a year,
  /// not for good.
  final List<Profile> external;

  final Season? season;
  final String? error;

  /// When this directory was last true, if it is being shown from disk.
  /// Null on a live read — see [SavedCopyBanner].
  final DateTime? savedAt;

  EmployeesDirectoryState copyWith({
    DirectoryStatus? status,
    List<Profile>? permanent,
    List<Profile>? external,
    Season? season,
    String? error,
    DateTime? savedAt,
  }) {
    return EmployeesDirectoryState(
      status: status ?? this.status,
      permanent: permanent ?? this.permanent,
      external: external ?? this.external,
      season: season ?? this.season,
      error: error,
      // Cleared rather than carried on every emit, for the same reason [error]
      // is: a screen that has just been re-read live must stop claiming to be a
      // saved copy, and `??` would make it claim that forever.
      savedAt: savedAt,
    );
  }

  @override
  List<Object?> get props => [
    status,
    permanent,
    external,
    season,
    error,
    savedAt,
  ];
}

class EmployeesDirectoryCubit extends SafeCubit<EmployeesDirectoryState> {
  EmployeesDirectoryCubit(this._repo, this._seasons)
    : super(const EmployeesDirectoryState()) {
    load();
  }

  final EmployeesRepository _repo;
  final SeasonsRepository _seasons;

  /// The telephone book first, and everything else on top of it.
  ///
  /// The order is the fix. This used to read the current season, then fetch
  /// both halves together — so with no signal the SEASON lookup was what failed,
  /// and it took the permanent staff down with it before they were even asked
  /// for. The half of this screen that survives without a network was never
  /// reached, on exactly the occasions it was wanted.
  ///
  /// Now the permanent staff are read on their own, and fall back to disk. The
  /// season and the externals are best-effort on top: an external belongs to a
  /// season, so there is no meaningful saved copy of them without knowing which
  /// season it is, and a delegate list is not what anybody opens this screen for
  /// while standing somewhere. The banner tells the reader the page is a saved
  /// one, which is the honest way to say that what is missing may be missing.
  Future<void> load() async {
    emit(state.copyWith(status: DirectoryStatus.loading));
    try {
      final permanent = await _repo.fetchPermanent();

      Season? season;
      var external = const <Profile>[];
      try {
        season = await _seasons.fetchCurrentSeason();
        external = await _repo.fetchExternal(seasonId: season?.id);
      } catch (_) {
        // Swallowed on purpose, and only this half. There is nothing to show
        // for it and nothing the reader could do about it; what they came for
        // is already in hand.
      }

      emit(
        state.copyWith(
          status: DirectoryStatus.loaded,
          permanent: permanent.data,
          external: external,
          season: season,
          savedAt: permanent.savedAt,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: DirectoryStatus.error, error: e.toString()));
    }
  }
}
