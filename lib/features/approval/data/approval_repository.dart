import '../../../core/supabase/supabase_client.dart';
import '../../profile/data/profile_repository.dart' show profileEmbeds;
import '../../profile/domain/profile.dart';
import '../../profile/domain/profile_enums.dart';

class ApprovalRepository {
  /// All accounts awaiting review, newest first, with their job-title name.
  Future<List<Profile>> fetchPending() async {
    final rows = await supabase
        .from('profiles')
        .select(profileEmbeds)
        .eq('account_status', AccountStatus.pending.db)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((r) => Profile.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> approve(String profileId) async {
    await supabase
        .from('profiles')
        .update({
          'account_status': AccountStatus.approved.db,
          'rejection_reason': null,
        })
        .eq('id', profileId);
  }

  Future<void> reject(String profileId, String? reason) async {
    await supabase
        .from('profiles')
        .update({
          'account_status': AccountStatus.rejected.db,
          'rejection_reason': (reason == null || reason.trim().isEmpty)
              ? null
              : reason.trim(),
        })
        .eq('id', profileId);
  }

  /// Signed URL to view a private document (passport/visa/nusuk) held in the
  /// `documents` bucket. [pathOrUrl] is the stored storage path.
  Future<String> signedDocumentUrl(String path) {
    return supabase.storage.from('documents').createSignedUrl(path, 60 * 10);
  }
}
