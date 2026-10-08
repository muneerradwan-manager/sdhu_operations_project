import '../../../core/offline/outbox.dart';
import '../../../core/offline/outbox_entry.dart';
import 'check_in_repository.dart';

/// Arriving somewhere, kept until it can be reported.
///
/// Of every field write in this app, this is the one most certain to be made
/// where there is no signal: a man reports his arrival by standing at the gate
/// of a camp in منى and pointing his phone at a sticker, which is a description
/// of the worst reception in the season.
///
/// It replays cleanly because it appends: the row is a new arrival with its own
/// timestamp, and the same arrival sent twice is two rows a minute apart rather
/// than a contradiction. The board reads the latest per person per place, so a
/// duplicate changes nothing it shows.
///
/// The POSITION is captured when the button is pressed, not when the queue
/// drains — the phone may be back in مكة by then, and coordinates from wherever
/// it was finally sent from would be a lie the database computes a distance
/// against.
///
/// **A new kind, not the old one.** An entry written by a build before 0098
/// carries `module_id` and `node_id` and there is nothing left to send it to.
/// The unknown-kind path blocks such an entry rather than dropping it, so the
/// person is shown work that can no longer be filed and decides for himself
/// whether to discard it. Reusing `checkin.arrive` would have replayed it into
/// a handler that would misread every field.
abstract final class CheckInOutbox {
  static const kind = 'checkin.place';

  /// What a build before 0098 wrote. Named so it can be recognised — never
  /// registered, so an entry carrying it is blocked and surfaced rather than
  /// silently misinterpreted.
  static const retiredKind = 'checkin.arrive';

  static void register(Outbox outbox) => outbox.register(kind, _send);

  static Map<String, dynamic> payload({
    required String itemId,
    required String secret,
    required double latitude,
    required double longitude,
    double? accuracy,
    String? note,
  }) => {
    'item_id': itemId,
    'secret': secret,
    'lat': latitude,
    'lng': longitude,
    'accuracy': accuracy,
    'note': note,
  };

  static Future<void> _send(OutboxEntry entry) async {
    final payload = entry.payload;
    await CheckInRepository().checkIn(
      itemId: payload['item_id'] as String,
      secret: payload['secret'] as String,
      latitude: (payload['lat'] as num).toDouble(),
      longitude: (payload['lng'] as num).toDouble(),
      accuracy: (payload['accuracy'] as num?)?.toDouble(),
      note: payload['note'] as String?,
    );
  }
}
