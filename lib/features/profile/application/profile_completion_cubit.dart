import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';
import '../domain/profile_enums.dart';
import '../domain/reference_choice.dart';

enum ProfileFormStatus { loading, ready, submitting, submitted, error }

class ProfileCompletionState extends Equatable {
  const ProfileCompletionState({
    this.status = ProfileFormStatus.loading,
    this.jobTitles = const [],
    this.cities = const [],
    this.missionTypes = const [],
    this.error,
  });

  final ProfileFormStatus status;
  final List<ReferenceChoice> jobTitles;

  /// The Syrian cities to choose from. Read before the account is approved,
  /// which is the whole reason the list is readable that early.
  final List<ReferenceChoice> cities;

  final List<ReferenceChoice> missionTypes;

  final String? error;

  ProfileCompletionState copyWith({
    ProfileFormStatus? status,
    List<ReferenceChoice>? jobTitles,
    List<ReferenceChoice>? cities,
    List<ReferenceChoice>? missionTypes,
    String? error,
  }) {
    return ProfileCompletionState(
      status: status ?? this.status,
      jobTitles: jobTitles ?? this.jobTitles,
      cities: cities ?? this.cities,
      missionTypes: missionTypes ?? this.missionTypes,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, jobTitles, cities, missionTypes, error];
}

class ProfileCompletionCubit extends SafeCubit<ProfileCompletionState> {
  ProfileCompletionCubit(this._repo, {this.existing})
    : super(const ProfileCompletionState()) {
    _load();
  }

  final ProfileRepository _repo;

  /// When non-null, the form edits an existing (approved) profile instead of
  /// completing a new one — status is preserved and the photo is optional.
  final Profile? existing;
  bool get isEdit => existing != null;

  Future<void> _load() async {
    emit(state.copyWith(status: ProfileFormStatus.loading));
    try {
      final titles = await _repo.fetchActiveJobTitles();
      final cities = await _repo.fetchSyrianCities();
      final missions = await _repo.fetchMissionTypes();
      emit(
        state.copyWith(
          status: ProfileFormStatus.ready,
          jobTitles: titles,
          cities: cities,
          missionTypes: missions,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: ProfileFormStatus.error, error: e.toString()),
      );
    }
  }

  Future<void> retry() => _load();

  /// Uploads any newly picked images then persists the profile. In create mode
  /// this submits for approval; in edit mode it updates the fields in place.
  Future<void> submit({
    required String firstName,
    required String surname,
    required String fatherName,
    File? photo,
    required String jobTitleId,
    required Gender gender,
    required DateTime dateOfBirth,
    required String missionTypeId,
    required String phoneSy,
    String? phoneSa,
    String? cityId,
    File? passport,
    File? visa,
    File? nusuk,
  }) async {
    emit(state.copyWith(status: ProfileFormStatus.submitting));
    try {
      // Upload a newly picked avatar; null means "keep the existing one".
      final photoUrl = photo == null
          ? null
          : await _repo.uploadImage(
              bucket: 'avatars',
              name: 'avatar.jpg',
              file: photo,
            );

      Future<String?> uploadDoc(String name, File? f) async {
        if (f == null) return null;
        return _repo.uploadImage(bucket: 'documents', name: name, file: f);
      }

      final passportUrl = await uploadDoc('passport.jpg', passport);
      final visaUrl = await uploadDoc('visa.jpg', visa);
      final nusukUrl = await uploadDoc('nusuk.jpg', nusuk);

      if (isEdit) {
        await _repo.updateOwnProfile(
          firstName: firstName,
          surname: surname,
          fatherName: fatherName,
          jobTitleId: jobTitleId,
          gender: gender,
          dateOfBirth: dateOfBirth,
          missionTypeId: missionTypeId,
          phoneSy: phoneSy,
          phoneSa: phoneSa,
          cityId: cityId,
          photoUrl: photoUrl,
          passportImageUrl: passportUrl,
          visaImageUrl: visaUrl,
          nusukCardImageUrl: nusukUrl,
        );
      } else {
        await _repo.submitForApproval(
          firstName: firstName,
          surname: surname,
          fatherName: fatherName,
          photoUrl: photoUrl!,
          jobTitleId: jobTitleId,
          gender: gender,
          dateOfBirth: dateOfBirth,
          missionTypeId: missionTypeId,
          phoneSy: phoneSy,
          phoneSa: phoneSa,
          cityId: cityId,
          passportImageUrl: passportUrl,
          visaImageUrl: visaUrl,
          nusukCardImageUrl: nusukUrl,
        );
      }

      emit(state.copyWith(status: ProfileFormStatus.submitted));
    } catch (e) {
      emit(
        state.copyWith(status: ProfileFormStatus.error, error: e.toString()),
      );
    }
  }
}
