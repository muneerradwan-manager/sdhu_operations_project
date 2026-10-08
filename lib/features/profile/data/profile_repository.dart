import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/snapshots.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/profile.dart';
import '../domain/profile_enums.dart';
import '../domain/reference_choice.dart';

/// Every list a profile is described by, in the one shape they now share. Each
/// embed is aliased by the column it comes through: three of them land in
/// `reference_items` and the query has to say which is which.
const profileEmbeds =
    '*, job_title:job_title_id(name_ar, name_en), '
    'city:city_id(name_ar, name_en), '
    'mission_type:mission_type_id(name_ar, name_en)';

class ProfileRepository {
  /// The signed-in user's own profile, or null if the row is not readable yet.
  ///
  /// Kept on disk, and this is the ONE saved copy the whole offline story rests
  /// on. Everything else in the app that survives a dead network — the task
  /// list, the roster, the queue of writes waiting to go — is behind a session,
  /// and the session is behind this row. Without it a launch with no signal
  /// resolved to nothing, the router held at the splash, and an app full of
  /// carefully offline-capable screens was unreachable from the first frame.
  ///
  /// Restored on a NETWORK failure only, like every other snapshot: an account
  /// suspended this morning answers, and it answers "suspended". What is served
  /// from disk is the answer given to a question nobody can ask right now.
  Future<Cached<Profile?>> fetchMine() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const Cached(null);
    return readWithSnapshot(
      // Per account, and dropped at sign-out — a shared handset must not open
      // on the previous man's name and permissions.
      key: 'session.profile.$uid',
      fetch: () => supabase
          .from('profiles')
          .select(profileEmbeds)
          .eq('id', uid)
          .maybeSingle(),
      parse: (row) => row == null
          ? null
          : Profile.fromMap((row as Map).cast<String, dynamic>()),
    );
  }

  /// The entries of one admin-managed list, active ones only, in the order the
  /// admin put them in.
  ///
  /// The three the profile form asks for — the cities, the posts, the missions —
  /// are readable by a signed-in account before it is approved, because the
  /// registration form itself needs them.
  Future<List<ReferenceChoice>> fetchChoices(String setCode) async {
    final rows = await supabase
        .from('reference_items')
        .select('id, name_ar, name_en, reference_sets!inner(code)')
        .eq('reference_sets.code', setCode)
        .eq('is_active', true)
        .order('sort_order')
        .order('name_ar');
    return (rows as List)
        .map((r) => ReferenceChoice.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReferenceChoice>> fetchSyrianCities() =>
      fetchChoices(ReferenceSetCodes.syrianCities);

  Future<List<ReferenceChoice>> fetchActiveJobTitles() =>
      fetchChoices(ReferenceSetCodes.jobTitles);

  Future<List<ReferenceChoice>> fetchMissionTypes() =>
      fetchChoices(ReferenceSetCodes.missionTypes);

  /// Uploads a local file to [bucket] under `{uid}/{name}` and returns a URL.
  /// For the public `avatars` bucket a public URL; for private `documents`,
  /// the storage path (read through signed URLs / RLS on demand).
  Future<String> uploadImage({
    required String bucket,
    required String name,
    required File file,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    final path = '$uid/$name';
    await supabase.storage
        .from(bucket)
        .upload(path, file, fileOptions: const FileOptions(upsert: true));
    if (bucket == 'avatars') {
      return supabase.storage.from(bucket).getPublicUrl(path);
    }
    return path;
  }

  /// Updates the signed-in user's editable profile fields WITHOUT changing the
  /// account status (used when an already-approved user edits their profile).
  Future<void> updateOwnProfile({
    required String firstName,
    required String surname,
    required String fatherName,
    required String jobTitleId,
    required Gender gender,
    required DateTime dateOfBirth,
    required String missionTypeId,
    required String phoneSy,
    String? phoneSa,
    String? cityId,
    String? photoUrl,
    String? passportImageUrl,
    String? visaImageUrl,
    String? nusukCardImageUrl,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    final data = <String, dynamic>{
      'first_name': firstName,
      'surname': surname,
      'father_name': fatherName,
      'job_title_id': jobTitleId,
      'gender': gender.db,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'mission_type_id': missionTypeId,
      'phone_sy': phoneSy,
      'phone_sa': phoneSa,
      'city_id': cityId,
    };
    // Only overwrite images when a new one was provided.
    if (photoUrl != null) data['photo_url'] = photoUrl;
    if (passportImageUrl != null) data['passport_image_url'] = passportImageUrl;
    if (visaImageUrl != null) data['visa_image_url'] = visaImageUrl;
    if (nusukCardImageUrl != null) {
      data['nusuk_card_image_url'] = nusukCardImageUrl;
    }
    await supabase.from('profiles').update(data).eq('id', uid);
  }

  /// Persists the profile fields and moves the account to `pending`.
  Future<void> submitForApproval({
    required String firstName,
    required String surname,
    required String fatherName,
    required String photoUrl,
    required String jobTitleId,
    required Gender gender,
    required DateTime dateOfBirth,
    required String missionTypeId,
    required String phoneSy,
    String? phoneSa,
    String? cityId,
    String? passportImageUrl,
    String? visaImageUrl,
    String? nusukCardImageUrl,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase
        .from('profiles')
        .update({
          'first_name': firstName,
          'surname': surname,
          'father_name': fatherName,
          'photo_url': photoUrl,
          'job_title_id': jobTitleId,
          'gender': gender.db,
          'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
          'mission_type_id': missionTypeId,
          'phone_sy': phoneSy,
          'phone_sa': phoneSa,
          'city_id': cityId,
          'passport_image_url': passportImageUrl,
          'visa_image_url': visaImageUrl,
          'nusuk_card_image_url': nusukCardImageUrl,
          'account_status': AccountStatus.pending.db,
        })
        .eq('id', uid);
  }
}
