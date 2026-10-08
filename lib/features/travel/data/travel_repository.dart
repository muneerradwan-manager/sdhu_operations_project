import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/attachments/attachment.dart';
import '../../../core/l10n/localized_name.dart';
import '../../../core/supabase/storage_key.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/journey.dart';
import '../domain/journey_leg.dart';
import '../domain/journey_stay.dart';
import '../domain/trip.dart';

/// Reading and writing the season's travel.
///
/// Reads go through the `returns table` functions of 0130 rather than through
/// PostgREST embeds, because every one of them has to merge the trip's half of
/// a movement with the man's half (BR-4) and doing that in Dart would mean the
/// coalescing rule living in two languages.
///
/// Writes split in two, and the split is the permission model made concrete:
/// **trips** are ordinary table writes guarded by RLS, while **legs** go
/// through RPCs. A leg is where the interesting refusals live — a man may
/// confirm his own arrival but not rewrite his flight number, and RLS cannot
/// express "these columns and not those".
class TravelRepository {
  static const _bucket = 'travel';

  // ---------------------------------------------------------------- reading

  /// One man's whole journey for a season: where he stayed, and what carried
  /// him between.
  ///
  /// Two calls rather than one joined query, because they answer two different
  /// questions and the spine has to be readable on its own — a man resident in
  /// the Kingdom has stays and no legs at all.
  Future<Journey> fetchJourney(String participantId) async {
    final legs = await supabase.rpc(
      'employee_journey',
      params: {'p_participant_id': participantId},
    );
    final stays = await supabase.rpc(
      'employee_stays',
      params: {'p_participant_id': participantId},
    );
    return Journey.fromRows(
      participantId,
      ((legs as List?) ?? const []).cast<Map<String, dynamic>>(),
      stayRows: ((stays as List?) ?? const []).cast<Map<String, dynamic>>(),
    );
  }

  /// A stay nothing carried him to — the man already resident in the Kingdom,
  /// or the المشاعر days somebody wants on the record.
  Future<String> addStay({
    required String participantId,
    required StayKind kind,
    String? cityItemId,
    DateTime? arrivedAt,
    DateTime? departedAt,
    String? note,
  }) async {
    final id = await supabase.rpc(
      'add_stay',
      params: {
        'p_participant_id': participantId,
        'p_kind': kind.dbName,
        'p_city_item_id': cityItemId,
        'p_arrived_at': arrivedAt?.toUtc().toIso8601String(),
        'p_departed_at': departedAt?.toUtc().toIso8601String(),
        'p_note': note,
      },
    );
    return id as String;
  }

  Future<void> deleteStay(String stayId) =>
      supabase.rpc('delete_stay', params: {'p_stay_id': stayId});

  /// Which participation row is this man's, for this season. Null when he is
  /// not in the season at all — an ordinary answer, not an error, and it reads
  /// as "no travel recorded" rather than as a failure.
  Future<String?> participationOf(String profileId, {String? seasonId}) async {
    final id = await supabase.rpc(
      'participation_of',
      params: {'p_profile_id': profileId, 'p_season_id': seasonId},
    );
    return id as String?;
  }

  /// The caller's own participation.
  Future<String?> myParticipation({String? seasonId}) async {
    final id = await supabase.rpc(
      'my_participation',
      params: {'p_season_id': seasonId},
    );
    return id as String?;
  }

  /// Every trip of a season, with its live passenger count.
  Future<List<Trip>> fetchTrips({String? seasonId}) async {
    final rows = await supabase.rpc(
      'season_trips',
      params: {'p_season_id': seasonId},
    );
    return ((rows as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Trip.fromRow)
        .toList();
  }

  /// Who is on one. Those moved off it are deliberately not in the manifest.
  Future<List<TripPassenger>> fetchPassengers(String tripId) async {
    final rows = await supabase.rpc(
      'trip_passengers',
      params: {'p_trip_id': tripId},
    );
    return ((rows as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(TripPassenger.fromRow)
        .toList();
  }

  /// What is not answered. The screen the operations room opens every morning.
  Future<List<TravelGap>> fetchGaps({String? seasonId}) async {
    final rows = await supabase.rpc(
      'travel_gaps',
      params: {'p_season_id': seasonId},
    );
    return ((rows as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(TravelGap.fromRow)
        .toList();
  }

  /// The airports, stations and cities a movement may run between.
  ///
  /// Read straight off the reference list rather than through an RPC: it is
  /// master data, any approved employee may read it (0017), and it changes
  /// perhaps twice a year.
  Future<List<TravelPoint>> fetchPoints() async {
    final rows =
        await supabase
                .from('reference_items')
                .select(
                  'id, name_ar, name_en, data, reference_sets!inner(code)',
                )
                .eq('reference_sets.code', 'travel_points')
                .eq('is_active', true)
                .order('sort_order')
            as List;
    return rows.cast<Map<String, dynamic>>().map(TravelPoint.fromMap).toList();
  }

  // ---------------------------------------------------------------- trips

  Future<String> createTrip(TripDraft draft, {required String seasonId}) async {
    final row = await supabase
        .from('trips')
        .insert(draft.toInsert(seasonId))
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Changing a trip changes it for everybody on it — which is the point of
  /// the trip existing (BR-4). The passengers are told by the trigger in 0131,
  /// not from here: a client that wrote the row and then died before sending
  /// sixty notifications would be the one failure this must not have.
  Future<void> updateTrip(String tripId, TripDraft draft) {
    // The season is not editable: a trip belongs to the year it was flown in,
    // and moving one between seasons would strand every leg hanging off it
    // against BR-2's trigger anyway.
    final patch = draft.toInsert('')..remove('season_id');
    return supabase.from('trips').update(patch).eq('id', tripId);
  }

  Future<void> setTripStatus(String tripId, TripStatus status) =>
      supabase.from('trips').update({'status': status.dbName}).eq('id', tripId);

  /// Refused by the database while anybody is still on it (BR-11). Cancelling
  /// is [setTripStatus]; this is for a trip entered by mistake.
  Future<void> deleteTrip(String tripId) =>
      supabase.from('trips').delete().eq('id', tripId);

  // ----------------------------------------------------------------- legs

  /// Puts a group on a trip in one atomic call, handling rebooking for anybody
  /// already on another flight of the same role (BR-5).
  ///
  /// Returns what it did, because "27 assigned, 3 moved, 1 already aboard" is a
  /// sentence the person who pressed the button needs to read.
  Future<AssignOutcome> assign({
    required String tripId,
    required List<String> participantIds,
  }) async {
    final result = await supabase.rpc(
      'assign_to_trip',
      params: {'p_trip_id': tripId, 'p_participant_ids': participantIds},
    );
    return AssignOutcome.fromMap((result as Map).cast<String, dynamic>());
  }

  /// The same act, from the employee picker — which deals in profile ids
  /// because it is shared with five features that know nothing about seasons.
  ///
  /// The translation to participations happens on the server against the
  /// TRIP's own season (0132), which is the only season that can be right.
  Future<AssignOutcome> assignProfiles({
    required String tripId,
    required List<String> profileIds,
  }) async {
    final result = await supabase.rpc(
      'assign_profiles_to_trip',
      params: {'p_trip_id': tripId, 'p_profile_ids': profileIds},
    );
    return AssignOutcome.fromMap((result as Map).cast<String, dynamic>());
  }

  /// Who still has no live leg of this kind — the eighty of four hundred an
  /// assign screen should actually be offering.
  Future<List<String>> withoutLeg({
    required LegRole role,
    String? seasonId,
  }) async {
    final rows = await supabase.rpc(
      'participants_without_leg',
      params: {'p_season_id': seasonId, 'p_role': role.dbName},
    );
    return ((rows as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((r) => r['profile_id'] as String)
        .toList();
  }

  /// Takes a man off. Not a delete — `cancelled`, so the gaps board can tell
  /// "he is not going" apart from "he was moved".
  Future<void> unassign(String legId, {String? note}) =>
      supabase.rpc('unassign_leg', params: {'p_leg_id': legId, 'p_note': note});

  /// Records what actually happened. Allowed to whoever holds `travel.confirm`
  /// **and to the traveller himself** — the private-car case, where nothing
  /// else in the world can say he arrived.
  Future<void> confirm({
    required String legId,
    required LegStatus status,
    DateTime? departedAt,
    DateTime? arrivedAt,
  }) => supabase.rpc(
    'confirm_leg',
    params: {
      'p_leg_id': legId,
      'p_status': status.dbName,
      'p_departed_at': departedAt?.toUtc().toIso8601String(),
      'p_arrived_at': arrivedAt?.toUtc().toIso8601String(),
    },
  );

  /// A movement he arranged himself: a private car, a lift, anything the
  /// mission did not book.
  Future<String> recordSelfLeg({
    required String participantId,
    required SelfLegDraft draft,
  }) async {
    final id = await supabase.rpc(
      'record_self_leg',
      params: {
        'p_participant_id': participantId,
        'p_role': draft.role.dbName,
        'p_mode': draft.mode.dbName,
        'p_from_point_id': draft.fromPointId,
        'p_to_point_id': draft.toPointId,
        'p_departure_at': draft.departureAt.toUtc().toIso8601String(),
        'p_arrival_at': draft.arrivalAt?.toUtc().toIso8601String(),
        'p_note': draft.note,
        'p_completed': draft.completed,
      },
    );
    return id as String;
  }

  /// Whether this participation is expected to travel at all. False for staff
  /// already resident in the Kingdom, and it is what keeps the gaps board from
  /// crying wolf about people who will never have an arrival flight (BR-9).
  Future<void> setTravels(String participantId, bool travels) => supabase.rpc(
    'set_participant_travels',
    params: {'p_participant_id': participantId, 'p_travels': travels},
  );

  // ---------------------------------------------------------- attachments

  Future<List<StoredAttachment>> fetchTripAttachments(String tripId) =>
      _attachments('trip_attachments', 'trip_id', tripId);

  Future<List<StoredAttachment>> fetchLegAttachments(String legId) =>
      _attachments('leg_attachments', 'leg_id', legId);

  Future<List<StoredAttachment>> _attachments(
    String table,
    String column,
    String id,
  ) async {
    final rows =
        await supabase
                .from(table)
                .select('id, kind, path, name, mime_type, size_bytes')
                .eq(column, id)
                .order('sort_order')
            as List;
    return rows
        .cast<Map<String, dynamic>>()
        .map(StoredAttachment.fromMap)
        .toList();
  }

  /// The manifest, the schedule, the ticket. Path convention `trips/{id}/…` and
  /// `legs/{id}/…` — the prefix is what `can_read_travel_file` (0129) reads to
  /// know which row to ask about the reader.
  Future<void> attachToTrip(String tripId, List<PendingAttachment> files) =>
      _attach('trips', tripId, 'trip_attachments', 'trip_id', files);

  Future<void> attachToLeg(String legId, List<PendingAttachment> files) =>
      _attach('legs', legId, 'leg_attachments', 'leg_id', files);

  Future<void> _attach(
    String prefix,
    String ownerId,
    String table,
    String column,
    List<PendingAttachment> files,
  ) async {
    if (files.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    var index = -1;
    for (final file in files) {
      index++;
      final path =
          '$prefix/$ownerId/${index}_'
          '${storageKey(file.name, fallback: '$index')}';
      await supabase.storage
          .from(_bucket)
          .upload(
            path,
            file.file,
            fileOptions: FileOptions(upsert: true, contentType: file.mimeType),
          );
      rows.add({
        column: ownerId,
        'kind': file.kind.name,
        'path': path,
        'name': file.name,
        'mime_type': file.mimeType,
        'size_bytes': file.file.lengthSync(),
        'sort_order': index,
      });
    }
    await supabase.from(table).insert(rows);
  }

  /// A short-lived link. The bucket is private and stays that way — a boarding
  /// pass carries a passport number.
  Future<String> signedUrl(
    String path, {
    bool download = false,
    String? downloadName,
  }) =>
      supabase.storage.from(_bucket).createSignedUrl(path, 60 * 10).then((url) {
        if (!download) return url;
        final separator = url.contains('?') ? '&' : '?';
        final name = Uri.encodeComponent(downloadName ?? '');
        return '$url${separator}download${name.isEmpty ? '' : '=$name'}';
      });
}

/// What [TravelRepository.assign] did.
class AssignOutcome {
  const AssignOutcome({
    required this.assigned,
    required this.rebooked,
    required this.skipped,
    this.notInSeason = 0,
  });

  /// Newly put on the trip.
  final int assigned;

  /// Moved here off another flight of the same role. Their old leg is kept.
  final int rebooked;

  /// Already aboard, or already arrived somewhere else — left alone rather
  /// than rewritten.
  final int skipped;

  /// Picked, but not an active participant of this trip's season — withdrawn
  /// between the picker opening and the button being pressed. Left out rather
  /// than failing the whole call (0132).
  final int notInSeason;

  static AssignOutcome fromMap(Map<String, dynamic> map) => AssignOutcome(
    assigned: (map['assigned'] as num?)?.toInt() ?? 0,
    rebooked: (map['rebooked'] as num?)?.toInt() ?? 0,
    skipped: (map['skipped'] as num?)?.toInt() ?? 0,
    notInSeason: (map['not_in_season'] as num?)?.toInt() ?? 0,
  );
}

/// What kind of unanswered question a gaps row is.
enum TravelGapKind {
  /// Nobody has booked him a flight in.
  noInbound,

  /// Nobody has booked him a flight home. **Normal** for most of the season.
  noOutbound,

  /// Its hour came and went and nobody said whether it happened.
  unconfirmed,

  /// The flight is off and he is still on it.
  cancelledTrip;

  static TravelGapKind fromDb(String? value) => switch (value) {
    'no_inbound' => TravelGapKind.noInbound,
    'unconfirmed' => TravelGapKind.unconfirmed,
    'cancelled_trip' => TravelGapKind.cancelledTrip,
    _ => TravelGapKind.noOutbound,
  };
}

/// One unanswered question about one man, with everything the row needs to
/// offer an action beside it.
class TravelGap {
  const TravelGap({
    required this.kind,
    required this.participantId,
    required this.profileId,
    required this.fullName,
    this.photoUrl,
    this.legId,
    this.tripId,
    this.tripNumber,
    this.role,
    this.at,
  });

  final TravelGapKind kind;
  final String participantId;
  final String profileId;
  final String fullName;
  final String? photoUrl;
  final String? legId;
  final String? tripId;
  final String? tripNumber;
  final LegRole? role;
  final DateTime? at;

  static TravelGap fromRow(Map<String, dynamic> map) => TravelGap(
    kind: TravelGapKind.fromDb(map['kind'] as String?),
    participantId: map['participant_id'] as String,
    profileId: map['profile_id'] as String,
    fullName: (map['full_name'] as String?) ?? '',
    photoUrl: map['photo_url'] as String?,
    legId: map['leg_id'] as String?,
    tripId: map['trip_id'] as String?,
    tripNumber: map['trip_number'] as String?,
    role: map['role'] == null ? null : LegRole.fromDb(map['role'] as String?),
    at: DateTime.tryParse(map['at'] as String? ?? '')?.toLocal(),
  );
}

/// Kept out of [TravelPoint] so the domain file has no Supabase import.
extension TravelPointLabel on TravelPoint {
  LocalizedName get label => name;
}
