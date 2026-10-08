import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/modules/presentation/widgets/location_button.dart';

/// A place is stored as a map URL and must never be printed as one — a hundred
/// characters that mean "منى، مخيم ٣٤" to nobody. It is offered as a button.
///
/// Which means deciding what is worth offering: an empty field is not a place,
/// and neither is a note somebody typed into it by hand. Coordinates are NOT
/// the test — a shortened share link names a place without saying where it is,
/// and opening it still works.
void main() {
  group('isOpenableLocation', () {
    test('a map link is a place', () {
      expect(
        isOpenableLocation('https://www.google.com/maps?q=21.4225,39.8262'),
        isTrue,
      );
    });

    test('a shortened share link is a place, coordinates or not', () {
      expect(isOpenableLocation('https://maps.app.goo.gl/abcd1234'), isTrue);
      expect(locationCoordinates('https://maps.app.goo.gl/abcd1234'), isNull);
    });

    test('nothing is not a place', () {
      expect(isOpenableLocation(null), isFalse);
      expect(isOpenableLocation(''), isFalse);
      expect(isOpenableLocation('   '), isFalse);
    });

    test('a sentence somebody typed is not a place', () {
      expect(isOpenableLocation('خلف مستشفى منى الطوارئ'), isFalse);
    });

    test('a number is not a place', () {
      expect(isOpenableLocation(250), isFalse);
    });
  });

  group('locationCoordinates', () {
    test('reads them out of the form this app writes', () {
      expect(
        locationCoordinates('https://www.google.com/maps?q=21.4225,39.8262'),
        '21.42250, 39.82620',
      );
    });

    test("and out of Google's own @lat,lng form", () {
      expect(
        locationCoordinates('https://www.google.com/maps/@21.4225,39.8262,17z'),
        '21.42250, 39.82620',
      );
    });
  });
}
