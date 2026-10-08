import '../../../core/supabase/supabase_client.dart';
import '../domain/map_place.dart';

/// The season's places, with what is true of each of them now.
class SeasonMapRepository {
  /// [seasonId] left off means the current season, resolved by the database —
  /// which is the same rule every other screen in this app follows, and is not
  /// the phone's business to decide.
  Future<List<MapPlace>> fetchPlaces({String? seasonId}) async {
    final rows = await supabase.rpc(
      'season_map',
      params: {'p_season_id': seasonId},
    );
    return ((rows as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(MapPlace.fromRow)
        .toList();
  }
}
