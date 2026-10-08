import '../../../core/supabase/supabase_client.dart';
import '../domain/dashboard_stats.dart';

/// Two calls, and deliberately only two.
///
/// Everything the dashboard draws comes back from ONE function. A page that
/// fires fourteen queries is a page that arrives in fourteen steps, each with
/// its own spinner and its own chance of failing on its own — and the numbers
/// would not even agree with each other, since each would have been counted at
/// a slightly different moment.
class DashboardRepository {
  /// Every season, newest first, for the filter at the top of the page.
  Future<List<DashboardSeason>> fetchSeasons() async {
    final rows = await supabase.rpc('dashboard_seasons');
    return [
      for (final r in (rows as List? ?? const []))
        DashboardSeason.fromMap(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// The whole page. Null [seasonId] means the season being worked through.
  ///
  /// What comes back depends on who is asking: the function drops the sections
  /// this reader holds no permission for rather than zeroing them.
  Future<DashboardStats> fetchStats({String? seasonId}) async {
    final row = await supabase.rpc(
      'dashboard_stats',
      params: {'p_season_id': seasonId},
    );
    if (row is! Map) return const DashboardStats();
    return DashboardStats.fromMap(Map<String, dynamic>.from(row));
  }
}
