import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sdhu_operations_project/features/checkin/application/my_check_ins_cubit.dart';
import 'package:sdhu_operations_project/core/router/app_router.dart';
import 'package:sdhu_operations_project/core/theme/app_icons.dart';
import 'package:sdhu_operations_project/features/auth/application/session_cubit.dart';
import 'package:sdhu_operations_project/features/checkin/domain/check_in.dart';
import 'package:sdhu_operations_project/features/home/domain/home_destinations.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

/// A person's own record: what the two filters may and may not do to it —
/// and the one door on the home page that both opens it and adds to it.
late List<HomeDestination> _general;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final l = await AppLocalizations.delegate.load(const Locale('ar'));
    _general = homeDestinations(
      SessionState(status: SessionStatus.approved),
      l,
    );
  });

  PresenceLine at(String place, {String id = 'x'}) => PresenceLine(
    id: id,
    profileId: 'me',
    fullName: '',
    itemId: place,
    placeName: place,
    distanceM: 12,
    radiusM: 200,
    createdAt: DateTime(2026, 8, 7, 6),
  );

  test('the place filter offers only places this person has stood in', () {
    // Derived from the rows rather than from the master list: the filter should
    // offer the two hotels he has actually been to, not the sixty the mission
    // contracted.
    final state = MyCheckInsState(
      lines: [
        at('فندق', id: '1'),
        at('مخيم', id: '2'),
        at('فندق', id: '3'),
      ],
    );

    expect(state.places.map((p) => p.name), ['فندق', 'مخيم']);
  });

  test('narrowing to a place does not empty the list of places', () {
    // The reason the place filter runs in memory and the window at the server.
    // Asked of the server, choosing a place would return only those rows — and
    // the choices, being derived from the rows, would collapse to the one
    // already chosen, with no way back to the others.
    final state = MyCheckInsState(
      lines: [
        at('فندق', id: '1'),
        at('مخيم', id: '2'),
      ],
    ).copyWith(place: 'فندق');

    expect(state.shown, hasLength(1));
    expect(state.places, hasLength(2), reason: 'the way back must remain');
  });

  test('clearing the place is a state, not the absence of one', () {
    // `copyWith(place: null)` cannot mean "clear" — null is what an unset
    // named argument looks like, so it would mean "leave it alone". Every
    // filter that can be turned off needs this and it is easy to miss.
    final narrowed = const MyCheckInsState().copyWith(place: 'فندق');
    expect(narrowed.place, 'فندق');
    expect(narrowed.copyWith(clearPlace: true).place, isNull);
  });

  test('a window knows how far back it reaches, and "all" reaches forever', () {
    expect(CheckInWindow.day.since(), isNotNull);
    expect(CheckInWindow.week.since(), isNotNull);
    expect(
      CheckInWindow.all.since(),
      isNull,
      reason: 'no lower bound is what "all" means to the query',
    );
    expect(
      CheckInWindow.week.since()!.isBefore(CheckInWindow.day.since()!),
      isTrue,
    );
  });

  group('the door on the home page', () {
    test('every general door carries a colour of its own', () {
      // These six used to be coloured by INDEX, out of a parallel list — so
      // adding a seventh door without a seventh colour was a range error on the
      // home page, for everybody, on the first frame. The colour is now a
      // property of the door and that whole failure is gone; what has to be
      // held on to is the reason the palette was spread in the first place.
      //
      // Green once held nine of the thirteen tiles, on a green backdrop, under
      // a green app bar. A colour that covers three quarters of a screen is not
      // an accent, it is the paper — and the six doors of العام are the run
      // where that is easiest to slip back into, because they are the six a new
      // reader sees first.
      final general = _general.where((d) => d.group == HomeGroup.general);

      for (final door in general) {
        expect(
          door.accent,
          isNotNull,
          reason:
              '${door.title} fell back to the shelf colour, and العام is '
              'the one shelf whose doors are not one kind of thing',
        );
      }

      final colours = general.map((d) => d.accent).toSet();
      expect(
        colours.length,
        general.length,
        reason: 'two general doors share a colour — the wash is coming back',
      );
    });

    test('the act and the record are one door', () {
      // Check-in used to be a full-width button under the prayer card, among
      // the facts about the moment rather than among the things a person does —
      // and the record it produces had nowhere to live at all. If the button
      // comes back to the prayer column there are two doors to the same act
      // again, which is what the card was built to end.
      final moment = File(
        'lib/features/home/presentation/widgets/home_pieces.dart',
      ).readAsStringSync();

      expect(
        moment.contains('CheckInButton'),
        isFalse,
        reason:
            'the act belongs on the record card, not beside the prayer times',
      );

      final door = _general.firstWhere((d) => d.route == Routes.myCheckIns);
      expect(door.action, contains('compose=1'));
      expect(door.actionIcon, AppIcons.qrCode);
    });
  });
}
