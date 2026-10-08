import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/profile_enums.dart';
import '../../seasons/data/seasons_repository.dart';
import '../../seasons/domain/season.dart';
import '../data/employees_repository.dart';

class EmployeeManageState extends Equatable {
  const EmployeeManageState({
    required this.profile,
    this.currentSeason,
    this.inCurrentSeason = false,
    this.seasonHistory = const [],
    this.loadingSeason = true,
    this.busy = false,
    this.error,
  });

  final Profile profile;
  final Season? currentSeason;
  final bool inCurrentSeason;

  /// Every season this employee is taking part in, newest first.
  final List<Season> seasonHistory;
  final bool loadingSeason;
  final bool busy;
  final String? error;

  EmployeeManageState copyWith({
    Profile? profile,
    Season? currentSeason,
    bool? inCurrentSeason,
    List<Season>? seasonHistory,
    bool? loadingSeason,
    bool? busy,
    String? error,
  }) {
    return EmployeeManageState(
      profile: profile ?? this.profile,
      currentSeason: currentSeason ?? this.currentSeason,
      inCurrentSeason: inCurrentSeason ?? this.inCurrentSeason,
      seasonHistory: seasonHistory ?? this.seasonHistory,
      loadingSeason: loadingSeason ?? this.loadingSeason,
      busy: busy ?? this.busy,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    profile,
    currentSeason,
    inCurrentSeason,
    seasonHistory,
    loadingSeason,
    busy,
    error,
  ];
}

/// Backs the admin employee-detail hub: view + suspend/reactivate, external
/// designation, and current-season participation toggling.
class EmployeeManageCubit extends SafeCubit<EmployeeManageState> {
  EmployeeManageCubit(this._employees, this._seasons, Profile profile)
    : super(EmployeeManageState(profile: profile)) {
    _loadSeason();
  }

  final EmployeesRepository _employees;
  final SeasonsRepository _seasons;

  Future<void> _loadSeason() async {
    try {
      final history = await _seasons.fetchParticipationHistory(
        state.profile.id,
      );
      final season = await _seasons.fetchCurrentSeason();
      emit(
        state.copyWith(
          currentSeason: season,
          // Derived from the history rather than a second round trip.
          inCurrentSeason:
              season != null && history.any((s) => s.id == season.id),
          seasonHistory: history,
          loadingSeason: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loadingSeason: false, error: e.toString()));
    }
  }

  Future<void> toggleSuspended() async {
    final next = !state.profile.isSuspended;
    emit(state.copyWith(busy: true));
    try {
      await _employees.setSuspended(state.profile.id, next);
      emit(
        state.copyWith(
          profile: state.profile.copyWith(isSuspended: next),
          busy: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
    }
  }

  /// Correct the record, then read it back.
  ///
  /// Reading back rather than patching in place: an edit may clear a field, and
  /// it resolves the job title and city names that only exist as ids here.
  Future<void> saveDetails({
    required String firstName,
    required String fatherName,
    required String surname,
    String? jobTitleId,
    Gender? gender,
    String? missionTypeId,
    DateTime? dateOfBirth,
    String? cityId,
    String? phoneSy,
    String? phoneSa,
  }) async {
    emit(state.copyWith(busy: true));
    try {
      await _employees.updateEmployee(
        profileId: state.profile.id,
        firstName: firstName,
        fatherName: fatherName,
        surname: surname,
        jobTitleId: jobTitleId,
        gender: gender,
        missionTypeId: missionTypeId,
        dateOfBirth: dateOfBirth,
        cityId: cityId,
        phoneSy: phoneSy,
        phoneSa: phoneSa,
      );
      final fresh = await _employees.fetchOne(state.profile.id);
      emit(state.copyWith(profile: fresh, busy: false));
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
    }
  }

  /// Set a new password on this employee's account.
  ///
  /// Returns true once it is actually stored. The caller waits for that before
  /// saying so: a sheet that closes on "saved" while the function is still
  /// deciding would announce a password the employee does not have.
  Future<bool> changePassword(String password) async {
    emit(state.copyWith(busy: true));
    try {
      await _employees.setEmployeePassword(
        profileId: state.profile.id,
        password: password,
      );
      emit(state.copyWith(busy: false));
      return true;
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }

  /// Set a new email address on this employee's account.
  ///
  /// Same contract as [changePassword]: true only once it is actually stored.
  /// On success the profile is read back rather than patched — the address
  /// shown on screen is the `profiles.email` mirror, and reading it back
  /// confirms the trigger delivered it.
  Future<bool> changeEmail(String email) async {
    emit(state.copyWith(busy: true));
    try {
      await _employees.setEmployeeEmail(
        profileId: state.profile.id,
        email: email,
      );
      final fresh = await _employees.fetchOne(state.profile.id);
      emit(state.copyWith(profile: fresh, busy: false));
      return true;
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }

  /// Remove the account. Returns true when it is gone, so the screen knows to
  /// leave — there is nothing left to show.
  Future<bool> deleteEmployee() async {
    emit(state.copyWith(busy: true));
    try {
      await _employees.deleteEmployee(state.profile.id);
      emit(state.copyWith(busy: false));
      return true;
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }

  Future<void> saveExternal({
    required bool isExternal,
    String? organization,
  }) async {
    emit(state.copyWith(busy: true));
    try {
      await _employees.updateExternalStatus(
        profileId: state.profile.id,
        isExternal: isExternal,
        organization: organization,
      );
      emit(
        state.copyWith(
          profile: state.profile.copyWith(
            isExternal: isExternal,
            externalOrganization: isExternal ? organization : null,
          ),
          busy: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
    }
  }

  Future<void> toggleCurrentSeason() async {
    final season = state.currentSeason;
    if (season == null) return;
    final next = !state.inCurrentSeason;
    emit(state.copyWith(busy: true));
    try {
      if (next) {
        await _seasons.addParticipant(season.id, state.profile.id);
      } else {
        await _seasons.removeParticipant(season.id, state.profile.id);
      }
      // Keep the history list in step with the toggle.
      final history = [...state.seasonHistory]
        ..removeWhere((s) => s.id == season.id);
      if (next) {
        history.add(season);
        history.sort((a, b) => b.hijriYear.compareTo(a.hijriYear));
      }
      emit(
        state.copyWith(
          inCurrentSeason: next,
          seasonHistory: history,
          busy: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
    }
  }
}
