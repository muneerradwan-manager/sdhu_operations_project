import '../../../core/l10n/localized_name.dart';
import '../../profile/domain/profile.dart';

/// A file an employee already holds a role in, as it appears while somebody is
/// choosing who to put into another one.
///
/// Deliberately thin: which file, and which season. Where in it and in what
/// capacity is the employee's own page to answer — here it only has to be
/// enough to make a chooser stop and think.
class EmployeeFileRef {
  const EmployeeFileRef({
    required this.moduleId,
    required this.name,
    this.seasonHijriYear,
  });

  final String moduleId;
  final LocalizedName name;
  final int? seasonHijriYear;

  factory EmployeeFileRef.fromMap(Map<String, dynamic> map) => EmployeeFileRef(
    moduleId: map['module_id'] as String,
    name: LocalizedName.fromMap(map),
    seasonHijriYear: map['hijri_year'] as int?,
  );
}

/// One candidate for a role in a file: the person, and what they are already
/// committed to.
///
/// Comes back from the `assignable_employees` function rather than from a table
/// read — the search, the filter and this list of commitments are all done in
/// the database, so what crosses the wire is one page of answers.
class AssignableEmployee {
  const AssignableEmployee({required this.profile, this.files = const []});

  final Profile profile;

  /// The files this person already serves in, newest season first. Empty means
  /// free, and is worth showing as plainly as the opposite.
  final List<EmployeeFileRef> files;

  factory AssignableEmployee.fromMap(Map<String, dynamic> map) =>
      AssignableEmployee(
        profile: Profile.fromMap(map),
        files: ((map['assignments'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(EmployeeFileRef.fromMap)
            .toList(),
      );
}
