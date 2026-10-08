import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile_enums.dart';
import '../../profile/domain/reference_choice.dart';
import '../data/employees_repository.dart';

enum CreateEmployeeStatus { loading, ready, submitting, created, error }

class CreateEmployeeState extends Equatable {
  const CreateEmployeeState({
    this.status = CreateEmployeeStatus.loading,
    this.jobTitles = const [],
    this.missionTypes = const [],
    this.error,
  });

  final CreateEmployeeStatus status;
  final List<ReferenceChoice> jobTitles;
  final List<ReferenceChoice> missionTypes;
  final String? error;

  CreateEmployeeState copyWith({
    CreateEmployeeStatus? status,
    List<ReferenceChoice>? jobTitles,
    List<ReferenceChoice>? missionTypes,
    String? error,
  }) {
    return CreateEmployeeState(
      status: status ?? this.status,
      jobTitles: jobTitles ?? this.jobTitles,
      missionTypes: missionTypes ?? this.missionTypes,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, jobTitles, missionTypes, error];
}

class CreateEmployeeCubit extends SafeCubit<CreateEmployeeState> {
  CreateEmployeeCubit(this._employees, this._profiles)
    : super(const CreateEmployeeState()) {
    _load();
  }

  final EmployeesRepository _employees;
  final ProfileRepository _profiles;

  Future<void> _load() async {
    emit(state.copyWith(status: CreateEmployeeStatus.loading));
    try {
      final titles = await _profiles.fetchActiveJobTitles();
      final missions = await _profiles.fetchMissionTypes();
      emit(
        state.copyWith(
          status: CreateEmployeeStatus.ready,
          jobTitles: titles,
          missionTypes: missions,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: CreateEmployeeStatus.error, error: e.toString()),
      );
    }
  }

  Future<void> submit({
    required String email,
    required String password,
    required String firstName,
    required String fatherName,
    required String surname,
    required String jobTitleId,
    required Gender gender,
    required DateTime dateOfBirth,
    required String missionTypeId,
    required String phoneSy,
    String? phoneSa,
    bool isExternal = false,
    String? externalOrganization,
  }) async {
    emit(state.copyWith(status: CreateEmployeeStatus.submitting));
    try {
      await _employees.createEmployee(
        email: email,
        password: password,
        firstName: firstName,
        fatherName: fatherName,
        surname: surname,
        jobTitleId: jobTitleId,
        gender: gender,
        dateOfBirth: dateOfBirth,
        missionTypeId: missionTypeId,
        phoneSy: phoneSy,
        phoneSa: phoneSa,
        isExternal: isExternal,
        externalOrganization: externalOrganization,
      );
      emit(state.copyWith(status: CreateEmployeeStatus.created));
    } catch (e) {
      emit(
        state.copyWith(status: CreateEmployeeStatus.ready, error: e.toString()),
      );
    }
  }
}
