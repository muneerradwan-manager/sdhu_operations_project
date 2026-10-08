import '../../../core/l10n/localized_name.dart';
import 'profile_enums.dart';

/// A single employee profile row (public.profiles).
class Profile {
  const Profile({
    required this.id,
    this.firstName,
    this.surname,
    this.fatherName,
    this.photoUrl,
    this.jobTitleId,
    this.gender,
    this.dateOfBirth,
    this.missionTypeId,
    this.missionTypeName,
    this.phoneSy,
    this.phoneSa,
    this.passportImageUrl,
    this.visaImageUrl,
    this.nusukCardImageUrl,
    required this.accountStatus,
    this.rejectionReason,
    this.isAdmin = false,
    this.isSuspended = false,
    this.isExternal = false,
    this.externalOrganization,
    this.jobTitleName,
    this.cityId,
    this.cityName,
    this.email,
  });

  final String id;
  final String? firstName;
  final String? surname;
  final String? fatherName;
  final String? photoUrl;
  final String? jobTitleId;
  final Gender? gender;
  final DateTime? dateOfBirth;

  /// Which mission this employee is on — an entry of the admin-managed
  /// `mission_types` list. It was an enum of three until 0085; the office adds
  /// the fourth itself now.
  final String? missionTypeId;

  /// Joined from reference_items when the query embeds it.
  final LocalizedName? missionTypeName;

  final String? phoneSy;
  final String? phoneSa;
  final String? passportImageUrl;
  final String? visaImageUrl;
  final String? nusukCardImageUrl;
  final AccountStatus accountStatus;
  final String? rejectionReason;
  final bool isAdmin;
  final bool isSuspended;
  final bool isExternal;
  final String? externalOrganization;

  /// Joined from the `job_titles` list when the query embeds it, in both
  /// languages — a job description is content, and reads in whichever one the
  /// app is set to.
  final LocalizedName? jobTitleName;

  /// The Syrian city this employee is from — an entry of the admin-managed
  /// `syrian_cities` list. Null for the accounts that registered before the
  /// question was asked.
  final String? cityId;

  /// Joined from reference_items when the query embeds it.
  final LocalizedName? cityName;

  /// Joined from the auth user when available (admin views).
  final String? email;

  String get fullName => [
    firstName,
    fatherName,
    surname,
  ].where((p) => p != null && p.isNotEmpty).join(' ');

  Profile copyWith({
    bool? isSuspended,
    bool? isExternal,
    String? externalOrganization,
    AccountStatus? accountStatus,
  }) {
    return Profile(
      id: id,
      firstName: firstName,
      surname: surname,
      fatherName: fatherName,
      photoUrl: photoUrl,
      jobTitleId: jobTitleId,
      gender: gender,
      dateOfBirth: dateOfBirth,
      missionTypeId: missionTypeId,
      missionTypeName: missionTypeName,
      phoneSy: phoneSy,
      phoneSa: phoneSa,
      passportImageUrl: passportImageUrl,
      visaImageUrl: visaImageUrl,
      nusukCardImageUrl: nusukCardImageUrl,
      accountStatus: accountStatus ?? this.accountStatus,
      rejectionReason: rejectionReason,
      isAdmin: isAdmin,
      isSuspended: isSuspended ?? this.isSuspended,
      isExternal: isExternal ?? this.isExternal,
      externalOrganization: externalOrganization ?? this.externalOrganization,
      jobTitleName: jobTitleName,
      cityId: cityId,
      cityName: cityName,
      email: email,
    );
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      firstName: map['first_name'] as String?,
      surname: map['surname'] as String?,
      fatherName: map['father_name'] as String?,
      photoUrl: map['photo_url'] as String?,
      jobTitleId: map['job_title_id'] as String?,
      gender: Gender.fromDb(map['gender'] as String?),
      dateOfBirth: map['date_of_birth'] == null
          ? null
          : DateTime.parse(map['date_of_birth'] as String),
      missionTypeId: map['mission_type_id'] as String?,
      missionTypeName: _embedded(map['mission_type']),
      phoneSy: map['phone_sy'] as String?,
      phoneSa: map['phone_sa'] as String?,
      passportImageUrl: map['passport_image_url'] as String?,
      visaImageUrl: map['visa_image_url'] as String?,
      nusukCardImageUrl: map['nusuk_card_image_url'] as String?,
      accountStatus: AccountStatus.fromDb(map['account_status'] as String?),
      rejectionReason: map['rejection_reason'] as String?,
      isAdmin: (map['is_admin'] as bool?) ?? false,
      isSuspended: (map['is_suspended'] as bool?) ?? false,
      isExternal: (map['is_external'] as bool?) ?? false,
      externalOrganization: map['external_organization'] as String?,
      jobTitleName: jobTitleNameOrNull(map),
      cityId: map['city_id'] as String?,
      cityName: _embedded(map['city']),
      email: map['email'] as String?,
    );
  }
}

/// The two names of a `reference_items` row embedded beside the profile, or null
/// when the query did not ask for it.
///
/// Profiles point at the catalog three times over — the city, the post, the
/// mission — so every embed is aliased by the column it came through
/// (`city:city_id(…)`) rather than named for its table, which since 0085 would
/// no longer say which of the three was meant.
LocalizedName? _embedded(Object? value) => value is Map
    ? LocalizedName.fromMap(value.cast<String, dynamic>())
    : null;

/// Reads a job description's two names out of whatever shape it arrived in.
///
/// The `job_title` embed of a profile query, or the flat `job_title_name` /
/// `job_title_name_en` that `assignable_employees` returns. Null when the query
/// did not ask for it at all.
LocalizedName? jobTitleNameOrNull(Map<String, dynamic> map) {
  final joined = _embedded(map['job_title']);
  if (joined != null) return joined;
  final flat = map['job_title_name'] as String?;
  if (flat == null) return null;
  return LocalizedName(ar: flat, en: map['job_title_name_en'] as String?);
}
