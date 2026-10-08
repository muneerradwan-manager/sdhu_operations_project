import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/router/app_router.dart';
import 'package:sdhu_operations_project/features/auth/application/session_cubit.dart';
import 'package:sdhu_operations_project/features/home/domain/home_destinations.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

/// When a home door carries a raised button, and when it must not.
///
/// The rule, and it is worth writing down because it is what stops the pattern
/// spreading until it means nothing:
///
///   **the button appears exactly where the door lists something you can add
///   to, and does nothing else.**
///
/// Check-in, tasks and complaints qualify — each is a list the reader writes
/// into. Operational files do not: they are created by administration, not from
/// here. Decisions do not: they are published TO the reader. And evaluations do
/// not, which is the sharpest case — they arrive by NAME, so there is no "new
/// evaluation" for anybody to press. A button there would be offering an act
/// that does not exist.
///
/// Three of six is not the ceiling and not the target; it is however many doors
/// happen to satisfy the rule. What this test guards is that the ones which do
/// not satisfy it stay bare.
///
/// It used to read the home screen as TEXT and match the card blocks with a
/// regular expression, because the cards were written inline in the screen that
/// drew them and there was nothing else to ask. There are now two screens
/// drawing them — the grid and the rail — from one catalogue, and the catalogue
/// is a list this can simply read. Which is the better test as well as the
/// simpler one: it is about what the app OFFERS rather than about how the
/// offer happens to be spelled.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l;
  late List<HomeDestination> doors;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('ar'));
    // Somebody holding nothing, because العام is the whole of what this file is
    // about and a permission cannot add to it.
    doors = homeDestinations(SessionState(status: SessionStatus.approved), l);
  });

  HomeDestination doorTo(String route) => doors.firstWhere(
    (d) => d.route == route,
    orElse: () => fail('no door routes to $route any more'),
  );

  group('doors you can add to carry the button', () {
    test('my attendance — the act that writes the record', () {
      final door = doorTo(Routes.myCheckIns);
      expect(door.action, isNotNull);
      expect(door.action, contains('compose=1'));
      // The scanner's own glyph, not the generic plus: what this button opens
      // is a camera pointed at a code on a wall.
      expect(door.actionIcon, isNotNull);
    });

    test('my tasks — a list the reader writes into', () {
      expect(doorTo(Routes.tasks).action, contains('compose=1'));
    });

    test(
      'my complaints — anyone approved may file, by design (0079 rule 1)',
      () {
        expect(doorTo(Routes.complaints).action, contains('compose=1'));
      },
    );

    test('every button says what it does', () {
      // A raised button with no tooltip is an unlabelled control on a card that
      // already looks tappable everywhere — and it is the only thing on these
      // cards a screen reader has nothing to say about.
      for (final door in doors.where((d) => d.action != null)) {
        expect(
          door.actionLabel,
          isNotNull,
          reason: '${door.title} raised a button with nothing to call it',
        );
      }
    });
  });

  group('doors with nothing to add stay bare', () {
    test('operational files — assignment puts them there, not the reader', () {
      expect(doorTo(Routes.modules).action, isNull);
    });

    test('decisions — published TO the reader', () {
      expect(doorTo(Routes.reports).action, isNull);
    });

    test('evaluations — they arrive by name; there is no new one to press', () {
      expect(doorTo(Routes.evaluations).action, isNull);
    });
  });

  test('a compose request is a query parameter the router actually reads', () {
    // The cards ask for `?compose=1`. If the router stops reading it the
    // buttons keep working — they still navigate — and silently stop opening
    // anything, which is the shape of bug that survives a demo.
    final router = File('lib/core/router/app_router.dart').readAsStringSync();

    final listens = RegExp(
      RegExp.escape("compose: s.uri.queryParameters['compose'] == '1'"),
    ).allMatches(router).length;

    expect(
      listens,
      greaterThanOrEqualTo(2),
      reason: 'both cards that ask to compose need a route that listens',
    );
  });
}
