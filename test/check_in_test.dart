import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/error_text.dart';
import 'package:sdhu_operations_project/core/utils/arabic_search.dart';
import 'package:sdhu_operations_project/features/checkin/domain/check_in.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

void main() {
  group('the code on the gate', () {
    test('it survives being written and read back', () {
      const code = PlaceCode(
        itemId: 'i-1',
        secret: 'abcdef0123456789',
        latitude: 21.421147,
        longitude: 39.914453,
        radiusM: 250,
      );

      expect(PlaceCode.parse(code.encode()), code);
    });

    test('a payload with no secret is not a code of ours', () {
      // Either a poster printed before 0098 or somebody's guess at an id. Both
      // must be refused rather than sent: a check-in with no secret cannot be
      // accepted, and pretending otherwise puts a man at a gate waiting for a
      // confirmation that will never come.
      expect(PlaceCode.parse('hajjops://check-in?p=i-1'), isNull);
      expect(PlaceCode.parse('hajjops://check-in?p=i-1&k='), isNull);
      expect(PlaceCode.parse('hajjops://check-in?k=abc'), isNull);
    });

    test('somebody else\'s QR is not a check-in', () {
      // A camera held up in a crowd reads all sorts of things. Each of these
      // must be refused as what it is, rather than sent to the server as an id
      // that happens not to exist.
      for (final noise in const [
        'https://example.com',
        'WIFI:S:CampGuest;T:WPA;P:12345;;',
        '5901234123457',
        'i-1',
        '',
        'hajjops://something-else?p=i-1&k=abc',
        'http://check-in?p=i-1&k=abc',
      ]) {
        expect(
          PlaceCode.parse(noise),
          isNull,
          reason: '"$noise" should not read as a check-in',
        );
      }
    });

    test('an old poster with no coordinates still scans', () {
      // A sticker printed before the position was carried on it is still a
      // sticker on a real gate. It simply cannot be judged without a network —
      // which is what `canCheckLocally` says, and the flow sends rather than
      // refusing.
      final code = PlaceCode.parse('hajjops://check-in?p=i-1&k=abcdef01');

      expect(code, isNotNull);
      expect(code!.canCheckLocally, isFalse);
      expect(code.itemId, 'i-1');
    });

    test('half a position is no position', () {
      // Otherwise `canCheckLocally` could be true with a null longitude and the
      // local check would compare against nothing.
      final code = PlaceCode.parse(
        'hajjops://check-in?p=i-1&k=abc&c=999,39.9&r=200',
      );

      expect(code?.latitude, isNull);
      expect(code?.longitude, isNull);
      expect(code?.canCheckLocally, isFalse);
    });

    test('surrounding whitespace from a scanner is tolerated', () {
      expect(
        PlaceCode.parse('  hajjops://check-in?p=i-1&k=abc\n')?.itemId,
        'i-1',
      );
    });

    test('null is not a crash', () {
      expect(PlaceCode.parse(null), isNull);
    });
  });

  group('how near is near enough', () {
    test('the phone\'s haversine agrees with the database\'s', () {
      // `metres_between` in 0087 is the authority — it is what decides, and
      // this copy exists only so an offline phone can refuse honestly. Two
      // formulas differing by ten metres would be a man refused by his phone
      // and accepted by the server, at the boundary, without either being able
      // to explain itself.
      //
      // Three fixed pairs, checked against the same haversine with R =
      // 6371000. Tolerance is a metre: this is arithmetic, not measurement.
      expect(
        CheckInRules.metresBetween(21.4225, 39.8262, 21.4225, 39.8262),
        closeTo(0, 0.001),
      );
      // One minute of latitude is a nautical mile.
      expect(
        CheckInRules.metresBetween(21.0, 39.0, 21.0 + 1 / 60, 39.0),
        closeTo(1853.0, 2),
      );
      // The Holy Mosque to منى, roughly seven kilometres.
      expect(
        CheckInRules.metresBetween(21.422510, 39.826168, 21.421147, 39.914453),
        closeTo(9145, 30),
      );
    });

    test('the phone\'s doubt is subtracted before the radius applies', () {
      // A fix 400 m out from a phone that will only vouch for 500 m is not
      // evidence anybody was in the wrong place. The same 400 m from a phone
      // sure to 8 m is.
      expect(
        CheckInRules.tooFar(distance: 400, accuracy: 500, radius: 200),
        isFalse,
      );
      expect(
        CheckInRules.tooFar(distance: 400, accuracy: 8, radius: 200),
        isTrue,
      );
    });

    test('a phone that reported no accuracy is taken at its word', () {
      expect(CheckInRules.tooFar(distance: 400, radius: 200), isTrue);
      expect(CheckInRules.tooFar(distance: 40, radius: 200), isFalse);
    });

    test('the doubt cannot push it below zero', () {
      expect(CheckInRules.worstCase(30, 500), 0);
    });

    test('exactly at the radius is inside it', () {
      // The boundary is a rule, not an accident: a man at 200 m of a 200 m
      // radius is at the place. Refusing him would make the number mean
      // something different from what it says.
      expect(
        CheckInRules.tooFar(distance: 200, accuracy: 0, radius: 200),
        isFalse,
      );
    });
  });

  test('one number governs the radius', () {
    // The default lives twice — here and in `place_radius_m` in 0098 — because
    // the phone must be able to answer without a network. Twice is acceptable;
    // twice and DIFFERENT is a man refused locally and accepted remotely, so
    // this reads the migration rather than trusting a comment.
    final sql = File(
      'supabase/migrations/0098_a_place_is_a_thing_in_the_world.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains(CheckInRules.defaultRadiusM.toInt().toString()),
      reason: 'place_radius_m must default to CheckInRules.defaultRadiusM',
    );
  });

  group('the refusals reach him as sentences', () {
    late AppLocalizations ar;

    setUpAll(() async {
      WidgetsFlutterBinding.ensureInitialized();
      ar = await AppLocalizations.delegate.load(const Locale('ar'));
    });

    test('every one of them, and none as a Postgres code', () {
      const codes = {
        'check_in_needs_a_position',
        'check_in_too_far',
        'check_in_code_expired',
        'check_in_place_has_no_location',
        'check_in_not_a_place',
        'check_in_not_approved',
        'check_in_codes_denied',
        'check_in_rotate_denied',
      };

      for (final code in codes) {
        final said = friendlyErrorL(
          ar,
          'PostgrestException(message: $code, code: 23514)',
        );
        expect(
          said,
          isNot(contains(code)),
          reason: '"$code" reached a man at a gate as a raw error code',
        );
        expect(said, isNot(ar.commonGenericError));
      }
    });

    test('and the two he can act on say what to DO', () {
      // These are the only two a man standing there can fix himself. The rest
      // are somebody else's job, and saying "turn something on" for those would
      // send him hunting for a setting that would not help.
      // Folded before it is searched: the sentences are vocalised —
      // «فَعِّلْ خِدْمَةَ الْمَوْقِعِ» — and a bare `contains('الموقع')` asks
      // after a spelling nothing on screen uses. What is being asserted is
      // that the WORD is in there, which is exactly what foldArabic compares.
      expect(foldArabic(ar.checkInNeedsAPosition), contains('الموقع'));
      expect(foldArabic(ar.checkInCodeExpired), contains('الجديد'));
    });

    test('the local refusals and the server\'s are one sentence', () {
      // The app raises `check_in_needs_a_position` itself, without asking, and
      // decides `check_in_too_far` for itself when the network is gone. Naming
      // them exactly what the server names them is what keeps a man from being
      // told two different things about one situation.
      expect(
        friendlyErrorL(ar, 'check_in_needs_a_position'),
        ar.checkInNeedsAPosition,
      );
      expect(friendlyErrorL(ar, 'check_in_too_far'), ar.checkInTooFar);
    });
  });

  group('where an arrival can be filed at all', () {
    // `mobile_scanner` declares four platforms — android, ios, macos, web —
    // and Windows and Linux have no implementation. The failure there is not a
    // graceful one: `start()` throws MissingPluginException out of an async gap
    // the widget's own errorBuilder never sees, so the operations-room desktop
    // got a red screen where a camera should have been.
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('the desktops the app also runs on are not offered the act', () {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          isPlaceScannerSupported,
          isFalse,
          reason: '$platform has no scanner plugin at all',
        );
      }
    });

    test('the phones it is actually used on are', () {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(isPlaceScannerSupported, isTrue, reason: '$platform scans');
      }
    });
  });
}
