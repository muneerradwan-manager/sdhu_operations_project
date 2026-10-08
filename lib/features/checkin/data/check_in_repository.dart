import '../../../core/offline/snapshots.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/check_in.dart';

/// What a place's code is, and what came back when somebody used it.
typedef CheckInReceipt = ({
  String id,
  String placeName,
  double distanceM,
  double radiusM,
});

/// Filing an arrival, and reading who has arrived.
///
/// Everything goes through RPCs rather than through the tables, and for a
/// sharper reason than before 0098: the distance between where a man says he is
/// and where the master data says the place is has to be measured by the
/// database, because it now DECIDES rather than annotates. A distance the
/// client offered would be a rule the client could switch off.
class CheckInRepository {
  /// Files an arrival at a place. Throws with the server's own code on refusal.
  Future<CheckInReceipt> checkIn({
    required String itemId,
    required String secret,
    required double latitude,
    required double longitude,
    double? accuracy,
    String? note,
  }) async {
    final rows = await supabase.rpc(
      'check_in_at_place',
      params: {
        'p_item_id': itemId,
        'p_secret': secret,
        'p_lat': latitude,
        'p_lng': longitude,
        'p_accuracy': accuracy,
        'p_note': note,
      },
    );
    final row = (rows as List).cast<Map<String, dynamic>>().first;
    return (
      id: row['check_in_id'] as String,
      placeName: (row['place_name'] as String?) ?? '',
      distanceM: (row['distance_m'] as num).toDouble(),
      radiusM: (row['radius_m'] as num).toDouble(),
    );
  }

  /// Who is where, everywhere, latest per person per place.
  ///
  /// [since] decides what "now" means and is the reader's to choose: an evening
  /// inspection wants today, a night in منى wants the last few hours. Left off,
  /// the database uses twelve.
  Future<List<PresenceLine>> fetchPresence({
    DateTime? since,
    String? itemId,
  }) async {
    final rows = await supabase.rpc(
      'presence_board',
      params: {
        'p_since': since?.toUtc().toIso8601String(),
        'p_item_id': itemId,
      },
    );
    return [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        _lineFromRow(row),
    ];
  }

  /// My own arrivals, every one of them, newest first.
  ///
  /// Read straight off the table rather than through `presence_board`, and for
  /// two reasons that both matter. The board answers "where is he" — one row
  /// per person per place, `distinct on` — and a personal record is the other
  /// question 0098 named and did not answer: everywhere I have been. Collapsing
  /// my own history to the latest visit per hotel would delete exactly what a
  /// record is for.
  ///
  /// And no permission is involved. `place_check_ins`'s own policy opens with
  /// `profile_id = auth.uid()`, and §30.3 states it: "your own check-ins,
  /// always, without a grant". That right has existed since 0098 and until now
  /// the app had nowhere to spend it — the only screen that read this table was
  /// the room's board, behind `checkin.board`.
  ///
  /// Kept for reading with no signal, keyed by person: this is a record
  /// consulted standing somewhere, which is where the network is not.
  Future<Cached<List<PresenceLine>>> fetchMyCheckIns({
    DateTime? since,
    String? itemId,
  }) async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) return const Cached([]);

    return readWithSnapshot(
      key: 'checkins.mine.$me',
      fetch: () {
        var query = supabase
            .from('place_check_ins')
            .select(
              '*, reference_items!inner('
              'name_ar, reference_sets!inner(code, name_ar))',
            )
            .eq('profile_id', me);
        if (since != null) {
          query = query.gte('created_at', since.toUtc().toIso8601String());
        }
        if (itemId != null) query = query.eq('item_id', itemId);
        return query.order('created_at', ascending: false);
      },
      parse: (rows) => [
        for (final row in ((rows as List?) ?? const [])
            .cast<Map<String, dynamic>>())
          _mineFromRow(row),
      ],
    );
  }

  /// The embedded shape of the row above, flattened into the same object the
  /// board draws — so one card widget serves both screens.
  PresenceLine _mineFromRow(Map<String, dynamic> row) {
    final place = (row['reference_items'] as Map?)?.cast<String, dynamic>();
    final set = (place?['reference_sets'] as Map?)?.cast<String, dynamic>();
    return PresenceLine(
      id: row['id'] as String,
      profileId: row['profile_id'] as String,
      // Deliberately empty. This is the reader's own record and every row on it
      // is theirs; printing their name on each one is noise where the PLACE is
      // the fact.
      fullName: '',
      itemId: row['item_id'] as String,
      placeName: (place?['name_ar'] as String?) ?? '',
      setCode: set?['code'] as String?,
      setName: set?['name_ar'] as String?,
      distanceM: (row['distance_m'] as num).toDouble(),
      accuracyM: (row['accuracy_m'] as num?)?.toDouble(),
      radiusM: (row['radius_m'] as num).toDouble(),
      note: row['note'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  /// Who is NOT where they are posted — the same fact from the other side.
  ///
  /// [within] is what "recently" means, and it defaults on the SERVER rather
  /// than here so this screen and the board cannot come to disagree about it:
  /// both leave it off and both get twelve hours.
  ///
  /// Postgres has no `interval` in JSON, so it travels as the string it parses
  /// from — `'8 hours'`. Built from the number rather than handed in as free
  /// text, because an interval that arrives as a sentence is one an interface
  /// can get wrong in a way the type system cannot see.
  Future<List<PresenceGap>> fetchGaps({Duration? within, String? itemId}) async {
    final rows = await supabase.rpc(
      'presence_gaps',
      params: {
        'p_within': within == null ? null : '${within.inMinutes} minutes',
        'p_item_id': itemId,
      },
    );
    return [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        PresenceGap.fromMap(row),
    ];
  }

  /// The code fixed to one place, with everything a poster needs.
  ///
  /// Refused outright for anybody without `checkin.codes` — the secret is
  /// printable, so who may read it is who may print it.
  /// [dueAt] is when the schedule of 0114 will rotate it by itself. Null when
  /// the schedule is switched off, and then nothing rotates but by hand.
  Future<
    ({PlaceCode code, String placeName, DateTime rotatedAt, DateTime? dueAt})?
  >
  fetchCode(String itemId) async {
    final rows = await supabase.rpc('place_code', params: {
      'p_item_id': itemId,
    });
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    final row = list.first;
    return (
      code: PlaceCode(
        itemId: row['item_id'] as String,
        secret: row['secret'] as String,
        latitude: (row['lat'] as num?)?.toDouble(),
        longitude: (row['lng'] as num?)?.toDouble(),
        radiusM: (row['radius_m'] as num?)?.toDouble(),
      ),
      placeName: (row['place_name'] as String?) ?? '',
      rotatedAt: DateTime.parse(row['rotated_at'] as String).toLocal(),
      // Absent, not merely null, on a database that has not had 0114 applied —
      // and there the honest answer is the same one the policy's own switch
      // gives: nothing rotates on its own.
      dueAt: switch (row['due_at']) {
        final String at => DateTime.tryParse(at)?.toLocal(),
        _ => null,
      },
    );
  }

  /// Makes every printed copy of this place's code dead, and returns the one
  /// that replaces it.
  Future<void> rotateCode(String itemId) async {
    await supabase.rpc('rotate_place_code', params: {'p_item_id': itemId});
  }

  static PresenceLine _lineFromRow(Map<String, dynamic> row) => PresenceLine(
    id: row['check_in_id'] as String,
    profileId: row['profile_id'] as String,
    fullName: (row['full_name'] as String?) ?? '',
    itemId: row['item_id'] as String,
    placeName: (row['place_name'] as String?) ?? '',
    setCode: row['set_code'] as String?,
    setName: row['set_name_ar'] as String?,
    groupName: row['group_ar'] as String?,
    distanceM: (row['distance_m'] as num?)?.toDouble() ?? 0,
    accuracyM: (row['accuracy_m'] as num?)?.toDouble(),
    radiusM:
        (row['radius_m'] as num?)?.toDouble() ?? CheckInRules.defaultRadiusM,
    note: row['note'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
  );
}
