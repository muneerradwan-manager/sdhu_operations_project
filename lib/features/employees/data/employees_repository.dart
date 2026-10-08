import '../../../core/offline/snapshots.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../profile/data/profile_repository.dart' show profileEmbeds;
import '../../profile/domain/profile.dart';
import '../../profile/domain/profile_enums.dart';

class EmployeesRepository {
  /// Admin-only: create a brand-new account (auth user + profile) via the
  /// `admin-create-user` Edge Function (which holds the service role). Returns
  /// the new user id.
  Future<String> createEmployee({
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
    final res = await supabase.functions.invoke(
      'admin-create-user',
      body: {
        'email': email.trim(),
        'password': password,
        'first_name': firstName,
        'father_name': fatherName,
        'surname': surname,
        'job_title_id': jobTitleId,
        'gender': gender.db,
        'mission_type_id': missionTypeId,
        'phone_sy': phoneSy,
        'phone_sa': phoneSa,
        'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        'is_external': isExternal,
        'external_organization': externalOrganization,
      },
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    return (data is Map ? data['id'] as String? : null) ?? '';
  }

  /// Permanent staff: internal + approved. Uses the permanent_employees view so
  /// the "not external, approved" rule lives in one place.
  ///
  /// Readable with no signal, from the last good answer — see [Snapshots]. This
  /// is the mission's telephone book, and looking a colleague up is the single
  /// most common thing anybody does on a phone standing in a place: the whole
  /// point of the call and WhatsApp buttons on these rows is defeated if the
  /// list they sit on cannot be opened without a network.
  ///
  /// Not keyed by person, unlike the task list: this is the same directory for
  /// everyone who may see it, and it is guarded by `employees.view` at the
  /// door. It is still dropped at sign-out with everything else, because a
  /// shared handset must not hand the next man a staff directory he was never
  /// shown.
  Future<Cached<List<Profile>>> fetchPermanent() => readWithSnapshot(
    key: 'employees.permanent',
    fetch: () => supabase
        .from('permanent_employees')
        .select(profileEmbeds)
        .order('first_name'),
    parse: (rows) => ((rows as List?) ?? const [])
        .map((r) => Profile.fromMap((r as Map).cast<String, dynamic>()))
        .toList(),
  );

  /// External participants: approved accounts flagged as external.
  ///
  /// Scoped to [seasonId] when given, and it usually should be. Permanent staff
  /// are permanent — they are the Administration whatever year it is — but an
  /// external is external FOR A SEASON: a delegate from the foreign ministry
  /// this year is not on the mission next year, and listing them all together
  /// says otherwise.
  Future<List<Profile>> fetchExternal({String? seasonId}) async {
    if (seasonId == null) {
      final rows = await supabase
          .from('profiles')
          .select(profileEmbeds)
          .eq('account_status', 'approved')
          .eq('is_external', true)
          .order('first_name');
      return (rows as List)
          .map((r) => Profile.fromMap(r as Map<String, dynamic>))
          .toList();
    }

    // Through the participation row: an external belongs to the directory of a
    // season because they were put into that season, not because they exist.
    final rows = await supabase
        .from('season_participants')
        .select('profiles!inner($profileEmbeds)')
        .eq('season_id', seasonId)
        .eq('status', 'active')
        .eq('profiles.is_external', true)
        .eq('profiles.account_status', 'approved');
    final people = (rows as List)
        .map(
          (r) => Profile.fromMap(
            (r as Map<String, dynamic>)['profiles'] as Map<String, dynamic>,
          ),
        )
        .toList();
    people.sort((a, b) => a.fullName.compareTo(b.fullName));
    return people;
  }

  /// One employee, with the job title and city resolved.
  ///
  /// Used to re-read a record after it has been corrected: an edit may CLEAR a
  /// field, and patching the in-memory copy cannot express that without a
  /// sentinel for every nullable column. Reading it back says what was actually
  /// stored, which is the only version worth showing.
  Future<Profile> fetchOne(String profileId) async {
    final row = await supabase
        .from('profiles')
        .select(profileEmbeds)
        .eq('id', profileId)
        .single();
    return Profile.fromMap(row);
  }

  /// Correct an employee's record.
  ///
  /// Only the columns that describe the person — not the ones that decide what
  /// they are. is_admin, is_external and account_status are guarded in the
  /// database (0011) and would be reverted for anyone but an admin anyway;
  /// keeping them out of here means the caller is never misled into thinking
  /// they were saved. External designation and suspension have their own
  /// permissions and their own paths.
  Future<void> updateEmployee({
    required String profileId,
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
    String? trimmed(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    await supabase
        .from('profiles')
        .update({
          'first_name': firstName.trim(),
          'father_name': fatherName.trim(),
          'surname': surname.trim(),
          'job_title_id': jobTitleId,
          'gender': gender?.db,
          'mission_type_id': missionTypeId,
          'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
          'city_id': cityId,
          'phone_sy': trimmed(phoneSy),
          'phone_sa': trimmed(phoneSa),
        })
        .eq('id', profileId);
  }

  /// Remove an account for good.
  ///
  /// Goes through the `admin-delete-user` Edge Function: the profile row is not
  /// the account, and deleting it would leave a login behind with nothing
  /// attached. The function holds the service role, checks `employees.delete`,
  /// and removes the auth user so the profile cascades away with it.
  Future<void> deleteEmployee(String profileId) async {
    final res = await supabase.functions.invoke(
      'admin-delete-user',
      body: {'id': profileId},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }

  /// Set a new password on someone else's account.
  ///
  /// Goes through the `admin-set-password` Edge Function for the same reason
  /// deletion does: a password lives in the auth schema, which the client has no
  /// key for. The function checks `employees.password` and refuses an
  /// administrator's account to anyone who is not one.
  Future<void> setEmployeePassword({
    required String profileId,
    required String password,
  }) async {
    final res = await supabase.functions.invoke(
      'admin-set-password',
      body: {'id': profileId, 'password': password},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }

  /// Set a new email address on someone else's account.
  ///
  /// Goes through the `admin-set-email` Edge Function: the address is the
  /// login itself and lives in the auth schema. The function checks
  /// `employees.email`, refuses an administrator's account to anyone who is
  /// not one, and auth refuses an address already in use (`email_taken`).
  /// The `profiles.email` mirror follows by trigger.
  Future<void> setEmployeeEmail({
    required String profileId,
    required String email,
  }) async {
    final res = await supabase.functions.invoke(
      'admin-set-email',
      body: {'id': profileId, 'email': email.trim()},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }

  /// Admin-only: suspend or reactivate an account.
  Future<void> setSuspended(String profileId, bool suspended) async {
    await supabase
        .from('profiles')
        .update({'is_suspended': suspended})
        .eq('id', profileId);
  }

  /// Admin-only: mark/unmark an account as external and set its organization
  /// details. is_external is a guarded column — only admins may change it.
  Future<void> updateExternalStatus({
    required String profileId,
    required bool isExternal,
    String? organization,
  }) async {
    await supabase
        .from('profiles')
        .update({
          'is_external': isExternal,
          'external_organization': isExternal ? organization : null,
        })
        .eq('id', profileId);
  }
}
