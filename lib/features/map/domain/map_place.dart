import 'package:latlong2/latlong.dart';

import '../../../core/l10n/localized_name.dart';

/// How a place is doing, at a glance, from across a room.
///
/// The whole point of drawing the season instead of listing it is that a colour
/// is read before a word is. So there are three and only three, and they are
/// ordered by what somebody would have to DO about them.
enum PlaceCondition {
  /// Something is wrong here and nobody has closed it.
  incident,

  /// Nobody has reported arriving in the last shift, though people are posted.
  ///
  /// Not an accusation. A phone with no signal cannot check in, and the man may
  /// well be standing there — which is exactly why this is drawn as a question
  /// and not as a failure.
  unmanned,

  /// Somebody is there and nothing is outstanding.
  manned,

  /// Nobody is posted here at all. The place exists on the season's list and no
  /// file has staffed it.
  empty;

  /// Whether it is worth the operations room's attention.
  bool get wantsAttention =>
      this == PlaceCondition.incident || this == PlaceCondition.unmanned;
}

/// One place of the season, as the map draws it.
///
/// A place, and not a node of a file. It stopped being one in 0095 and the map
/// caught up in 0112 — which is where the file's name, the file's id and the
/// node's id went: a hotel does not belong to an operational file, several
/// files may post people to one camp, and a pin drawn per node put two of them
/// on the same spot.
class MapPlace {
  const MapPlace({
    required this.itemId,
    required this.placeName,
    required this.position,
    required this.groupKey,
    required this.groupName,
    this.posted = 0,
    this.present = 0,
    this.openIncidents = 0,
  });

  /// The master-data entry this place IS — a row of the hotels list or the
  /// camps list. The same id a check-in is recorded against and a place code is
  /// fixed to (0098).
  final String itemId;

  /// Which of the season's four groups this belongs to — the camps of منى, the
  /// camps of عرفات, the hotels of مكة, the hotels of المدينة.
  ///
  /// Stable and never shown: a filter has to survive a refresh, and the label
  /// beside it is content that changes with the reader's language.
  final String groupKey;

  final LocalizedName groupName;

  /// The place itself — "المخيم رقم ١٤", "فندق الأنصار".
  final String placeName;

  final LatLng position;

  /// How many hold a post here.
  final int posted;

  /// How many have reported arriving in the last twelve hours.
  final int present;

  final int openIncidents;

  /// There is no "cannot be checked into" any more, and the flag that carried
  /// it is gone with the node branch of `season_map`. It meant a node standing
  /// on no master-data entry — nothing to fix a sticker to. Every pin is now an
  /// entry, and 0098 seeds a code for every entry of a place list by trigger,
  /// so the state cannot arise.
  PlaceCondition get condition {
    if (openIncidents > 0) return PlaceCondition.incident;
    if (posted == 0) return PlaceCondition.empty;
    if (present > 0) return PlaceCondition.manned;
    return PlaceCondition.unmanned;
  }

  static MapPlace fromRow(Map<String, dynamic> map) => MapPlace(
    itemId: map['item_id'] as String,
    placeName: (map['place_name'] as String?) ?? '',
    position: LatLng(
      (map['lat'] as num).toDouble(),
      (map['lng'] as num).toDouble(),
    ),
    groupKey: (map['group_key'] as String?) ?? '—',
    groupName: LocalizedName(
      ar: (map['group_ar'] as String?) ?? '',
      en: map['group_en'] as String?,
    ),
    posted: (map['posted'] as num?)?.toInt() ?? 0,
    present: (map['present'] as num?)?.toInt() ?? 0,
    openIncidents: (map['open_incidents'] as num?)?.toInt() ?? 0,
  );
}

/// One of the season's groups of places, and how many are in it.
///
/// The four the mission actually thinks in — the camps of منى, the camps of
/// عرفات, the hotels of مكة, the hotels of المدينة — are not hard-coded
/// anywhere. They fall out of the data: a place drawn from the hotels list is
/// grouped by the hotel's city, and everything else by the file it belongs to.
/// A fifth arrives on the day a fifth exists.
class MapGroup {
  const MapGroup({required this.key, required this.name, required this.count});

  final String key;
  final LocalizedName name;

  /// How many places carry this group. Shown on the filter, because a group
  /// with nothing in it is worth knowing about before it is switched on.
  final int count;
}

/// The box that holds every point being drawn.
///
/// Needed because the season is not in one place: مكة and المدينة are four
/// hundred kilometres apart, and منى and عرفات are ten minutes apart. Opening
/// on a fixed centre and zoom would show either an empty desert or one camp,
/// depending on which file the reader happened to be looking at.
class MapBounds {
  const MapBounds({required this.southWest, required this.northEast});

  final LatLng southWest;
  final LatLng northEast;

  LatLng get centre => LatLng(
    (southWest.latitude + northEast.latitude) / 2,
    (southWest.longitude + northEast.longitude) / 2,
  );

  /// Null when there is nothing to frame — which the caller must handle by
  /// falling back to a fixed centre rather than by framing an empty box.
  static MapBounds? around(Iterable<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in points) {
      minLat = (minLat == null || p.latitude < minLat) ? p.latitude : minLat;
      maxLat = (maxLat == null || p.latitude > maxLat) ? p.latitude : maxLat;
      minLng = (minLng == null || p.longitude < minLng) ? p.longitude : minLng;
      maxLng = (maxLng == null || p.longitude > maxLng) ? p.longitude : maxLng;
    }
    if (minLat == null) return null;

    // A single point has no extent, and a zero-sized box makes the map zoom to
    // its maximum — a street corner filling the screen. Padded to something a
    // person can recognise the surroundings of.
    const pad = 0.002;
    return MapBounds(
      southWest: LatLng(minLat - pad, minLng! - pad),
      northEast: LatLng(maxLat! + pad, maxLng! + pad),
    );
  }
}
