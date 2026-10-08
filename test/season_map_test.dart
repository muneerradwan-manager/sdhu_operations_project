import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/map/domain/map_place.dart';
import 'package:latlong2/latlong.dart';

MapPlace place({int posted = 0, int present = 0, int incidents = 0}) => MapPlace(
  itemId: 'i1',
  placeName: 'المخيم رقم ١٤',
  position: const LatLng(21.41, 39.89),
  groupKey: 'camps:mina',
  groupName: const LocalizedName(ar: 'مخيمات منى', en: 'Mina camps'),
  posted: posted,
  present: present,
  openIncidents: incidents,
);

void main() {
  group('what colour a place is', () {
    // The whole reason to draw the season rather than list it is that a colour
    // is read before a word is. So the order these are decided in IS the
    // meaning, and it runs by what somebody would have to do about it.

    test('an open report outranks everything else', () {
      // A camp fully staffed, everybody present, and a bus on fire outside it
      // is not a green camp.
      expect(
        place(posted: 20, present: 20, incidents: 1).condition,
        PlaceCondition.incident,
      );
    });

    test('posted and somebody arrived is manned', () {
      expect(place(posted: 8, present: 3).condition, PlaceCondition.manned);
    });

    test('posted and nobody arrived is a question, not a verdict', () {
      // Deliberately NOT called "absent". A phone with no signal cannot check
      // in, and the man may well be standing there — which is the reason this
      // is a colour the room asks about rather than one it acts on.
      expect(place(posted: 8).condition, PlaceCondition.unmanned);
      expect(place(posted: 8).condition.wantsAttention, isTrue);
    });

    test('nobody posted is not the same as nobody present', () {
      // A camp the Administration has not staffed yet is not a camp whose
      // people failed to arrive. Colouring them alike would fill the map with
      // alarms about work that has not started.
      expect(place().condition, PlaceCondition.empty);
      expect(
        place().condition.wantsAttention,
        isFalse,
        reason: 'an unstaffed place is a planning matter, not an operational '
            'one',
      );
    });
  });

  group('framing the map', () {
    // The season is not in one place: مكة and المدينة are four hundred
    // kilometres apart and منى and عرفات are ten minutes apart. A fixed centre
    // and zoom shows either an empty desert or one camp.

    test('a box holds every point given to it', () {
      final bounds = MapBounds.around(const [
        LatLng(21.42, 39.82), // Makkah
        LatLng(24.47, 39.61), // Madinah
        LatLng(21.35, 39.98), // Arafat
      ]);

      expect(bounds, isNotNull);
      expect(bounds!.southWest.latitude, lessThan(21.35));
      expect(bounds.northEast.latitude, greaterThan(24.47));
      expect(bounds.southWest.longitude, lessThan(39.61));
      expect(bounds.northEast.longitude, greaterThan(39.98));
    });

    test('its centre sits between the extremes', () {
      final bounds = MapBounds.around(const [
        LatLng(20.0, 30.0),
        LatLng(22.0, 34.0),
      ])!;

      expect(bounds.centre.latitude, closeTo(21.0, 0.001));
      expect(bounds.centre.longitude, closeTo(32.0, 0.001));
    });

    test('a single point is padded rather than framed to nothing', () {
      // A zero-sized box makes the map zoom to its maximum — a street corner
      // filling the screen, with nothing around it a person could recognise.
      final bounds = MapBounds.around(const [LatLng(21.42, 39.82)])!;

      expect(bounds.northEast.latitude, greaterThan(bounds.southWest.latitude));
      expect(
        bounds.northEast.longitude,
        greaterThan(bounds.southWest.longitude),
      );
    });

    test('nothing to frame answers null rather than an empty box', () {
      // The caller falls back to a fixed centre. Framing an empty box would
      // point the camera at the null island off Africa.
      expect(MapBounds.around(const []), isNull);
    });
  });

  group('a place no file has staffed', () {
    // Most of المدينة. That file organises people by شركة الخدمة, which is a
    // company and not somewhere anybody stands, so its hotels are master data
    // and nothing else. Leaving them off the map because no member has been
    // posted to them would hide the city — and since 0112 the same is true of a
    // camp on the season's list that no file has turned into a node, which the
    // old map left off entirely.
    final loose = MapPlace.fromRow({
      'item_id': 'i-zamzam',
      'place_name': 'زمزم بولمان',
      'group_key': 'hotels:المدينة المنورة',
      'group_ar': 'فنادق المدينة المنورة',
      'group_en': 'Hotels — Madinah',
      'lat': 24.4563,
      'lng': 39.6269,
      'posted': 0,
      'present': 0,
      'open_incidents': 0,
    });

    test('it is still a place, with a position', () {
      expect(loose.placeName, 'زمزم بولمان');
      expect(loose.position.latitude, 24.4563);
    });

    test('it is the master-data entry, and nothing about a file', () {
      // The id a check-in is recorded against and a code is fixed to (0098) —
      // not a node's and not a module's. Those were carried until 0112 and were
      // never read by anything but the sheet that printed the file's name.
      expect(loose.itemId, 'i-zamzam');
    });

    test('it is empty rather than unmanned', () {
      // Nobody is posted, so there is nothing to be absent from. Colouring it
      // as "nobody checked in" would raise an alarm about work that does not
      // exist.
      expect(loose.condition, PlaceCondition.empty);
      expect(loose.condition.wantsAttention, isFalse);
    });
  });

  group('reading a row back', () {
    test('the counts arrive as counts', () {
      final read = MapPlace.fromRow({
        'item_id': 'i7',
        'place_name': 'فندق الأنصار',
        'lat': 21.4,
        'lng': 39.8,
        'posted': 12,
        'present': 5,
        'open_incidents': 1,
      });

      expect(read.placeName, 'فندق الأنصار');
      expect(read.position.latitude, 21.4);
      expect(read.condition, PlaceCondition.incident);
    });

    test('missing counts read as zero, not as null', () {
      final read = MapPlace.fromRow({
        'item_id': 'i7',
        'lat': 21.4,
        'lng': 39.8,
      });

      expect(read.posted, 0);
      expect(read.present, 0);
      expect(read.condition, PlaceCondition.empty);
    });
  });
}
