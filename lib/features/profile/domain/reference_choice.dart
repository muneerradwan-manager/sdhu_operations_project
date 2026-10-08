import '../../../core/l10n/localized_name.dart';

/// One entry of an admin-managed list, as a form field sees it: an id to store
/// and a name to read.
///
/// Its own small type rather than the master-data `ReferenceItem`: a dropdown
/// needs those two things and nothing else the catalog carries, and this keeps
/// the profile feature from depending on the modules one for them. The rows are
/// the same rows — the lists the admin edits under البيانات المرجعية.
///
/// One type for all three lists a person is described by (the city, the post,
/// the mission) because they are one shape. They were three classes while they
/// were three different tables; they are one table now.
class ReferenceChoice {
  const ReferenceChoice({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  final String id;
  final LocalizedName name;
  final bool isActive;

  factory ReferenceChoice.fromMap(Map<String, dynamic> map) => ReferenceChoice(
    id: map['id'] as String,
    name: LocalizedName.fromMap(map),
    isActive: (map['is_active'] as bool?) ?? true,
  );
}

/// The `reference_sets.code` of each list the profile form chooses from.
///
/// All three are readable before an account is approved (0085): they ARE the
/// registration form, and a form field is not a secret.
abstract final class ReferenceSetCodes {
  static const syrianCities = 'syrian_cities';
  static const jobTitles = 'job_titles';
  static const missionTypes = 'mission_types';
}
