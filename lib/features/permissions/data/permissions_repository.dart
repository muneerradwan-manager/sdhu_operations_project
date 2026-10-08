import '../../../core/supabase/supabase_client.dart';
import '../domain/permission.dart';

class PermissionsRepository {
  /// The full permission catalog, ordered for hierarchical display.
  Future<List<Permission>> fetchCatalog() async {
    final rows = await supabase
        .from('permissions')
        .select()
        .order('sort_order');
    return (rows as List)
        .map((r) => Permission.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// What each permission requires before it means anything:
  /// permission id → the ids it depends on. Mirrors the DB triggers that
  /// refuse a grant without its ground and cascade a revoke onto its
  /// dependents (see migration 0073).
  Future<Map<String, Set<String>>> fetchPrerequisites() async {
    final rows = await supabase.from('permission_prerequisites').select();
    final map = <String, Set<String>>{};
    for (final r in rows as List) {
      final m = r as Map<String, dynamic>;
      map
          .putIfAbsent(m['permission_id'] as String, () => <String>{})
          .add(m['requires_id'] as String);
    }
    return map;
  }

  /// Permission ids currently granted to [userId].
  Future<Set<String>> fetchGranted(String userId) async {
    final rows = await supabase
        .from('user_permissions')
        .select('permission_id')
        .eq('user_id', userId);
    return (rows as List).map((r) => r['permission_id'] as String).toSet();
  }

  Future<void> grant(String userId, String permissionId) async {
    await supabase.from('user_permissions').insert({
      'user_id': userId,
      'permission_id': permissionId,
      'granted_by': supabase.auth.currentUser?.id,
    });
  }

  /// Grants a whole list in one insert — the bulk half of [grant], for the
  /// assign screen that writes a basket onto several people.
  ///
  /// The ORDER of [permissionIds] is part of the contract: the DB trigger
  /// refuses a grant whose prerequisites are absent, and a multi-row insert
  /// fires it row by row in list order — so the caller hands the list with
  /// every ground before what stands on it, and the whole basket lands in one
  /// round trip instead of one per permission.
  Future<void> grantMany(String userId, List<String> permissionIds) async {
    if (permissionIds.isEmpty) return;
    final by = supabase.auth.currentUser?.id;
    await supabase.from('user_permissions').insert([
      for (final id in permissionIds)
        {'user_id': userId, 'permission_id': id, 'granted_by': by},
    ]);
  }

  Future<void> revoke(String userId, String permissionId) async {
    await supabase
        .from('user_permissions')
        .delete()
        .eq('user_id', userId)
        .eq('permission_id', permissionId);
  }
}
