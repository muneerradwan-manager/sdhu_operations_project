import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/modules/domain/map_location.dart';

/// Reading a position out of whatever an administrator pasted.
///
/// The regression here was invisible, which is why it lasted. Pressing Share in
/// Google Maps gives `maps.app.goo.gl/XXXX`, which carries no coordinates at
/// all; follow it and you land on `/maps/search/21.42,+39.89`, where the pair
/// is in the PATH and has a `+` after the comma. Neither shape was matched, and
/// a null here is indistinguishable from a field nobody filled in — so every
/// place set from a share link was simply absent from the map, with nothing
/// anywhere reporting a failure.
void main() {
  group('the three shapes that carry a position', () {
    test('the canonical one this app writes', () {
      final read = MapLocation.parse('https://www.google.com/maps?q=21.4241,39.8965');

      expect(read?.latitude, 21.4241);
      expect(read?.longitude, 39.8965);
    });

    test('the address-bar one, with its zoom on the end', () {
      final read = MapLocation.parse(
        'https://www.google.com/maps/@21.4241,39.8965,17z',
      );

      expect(read?.latitude, 21.4241);
      expect(read?.longitude, 39.8965);
    });

    test('what a share link RESOLVES to — path, and a plus', () {
      // Taken verbatim from following a real link out of the mission's own
      // address sheet.
      final read = MapLocation.parse(
        'https://www.google.com/maps/search/21.424128,+39.896510'
        '?entry=tts&g_ep=EgoyMDI2MDQwOC4wIPu8ASoASAFQAw%3D%3D',
      );

      expect(read, isNotNull, reason: 'this is the one that was being lost');
      expect(read!.latitude, 21.424128);
      expect(read.longitude, 39.896510);
    });

    test('and the place and dir variants of it', () {
      expect(
        MapLocation.parse('https://www.google.com/maps/place/21.3,39.9')?.latitude,
        21.3,
      );
      expect(
        MapLocation.parse('https://www.google.com/maps/dir/21.3,+39.9')?.longitude,
        39.9,
      );
    });
  });

  group('what does not carry a position', () {
    test('a short link is refused, because it genuinely has none', () {
      // Not a parser failure. The coordinates are on the far side of a
      // redirect and no amount of reading the string will produce them.
      expect(
        MapLocation.parse('https://maps.app.goo.gl/5Qh2fJPTPMAYcx6v8'),
        isNull,
      );
    });

    test('but it is RECOGNISED, which is a different fact', () {
      // "Nothing here" and "one redirect away" want opposite things from the
      // app, and telling them apart is what lets a paste be resolved instead
      // of quietly dropped.
      expect(
        MapLocation.isShortLink('https://maps.app.goo.gl/5Qh2fJPTPMAYcx6v8'),
        isTrue,
      );
      expect(MapLocation.isShortLink('https://goo.gl/maps/abc'), isTrue);
      expect(MapLocation.isShortLink('https://example.com'), isFalse);
      expect(MapLocation.isShortLink(null), isFalse);
    });

    test('an ordinary link, empty, and null', () {
      expect(MapLocation.parse('https://example.com/hotel'), isNull);
      expect(MapLocation.parse(''), isNull);
      expect(MapLocation.parse(null), isNull);
    });

    test('two numbers that are not on the globe', () {
      // A URL can carry any pair of numbers. 800 is not a latitude.
      expect(MapLocation.parse('https://x/maps?q=800,39.9'), isNull);
      expect(MapLocation.parse('https://x/maps?q=21.4,900'), isNull);
    });
  });

  group('what gets stored', () {
    test('is the canonical form, whatever came in', () {
      // The stored value must not depend on a URL shape Google may change, and
      // the DATABASE has to be able to read it without following anything —
      // `node_location` is what puts a place on the season map.
      final read = MapLocation.parse(
        'https://www.google.com/maps/search/21.424128,+39.896510?entry=tts',
      )!;

      expect(read.url, 'https://www.google.com/maps?q=21.424128,39.89651');
      expect(
        MapLocation.parse(read.url)?.latitude,
        21.424128,
        reason: 'what we write must be what we can read back',
      );
    });
  });
}
