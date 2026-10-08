import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/map/application/season_map_cubit.dart';
import 'package:sdhu_operations_project/features/map/domain/map_place.dart';
import 'package:latlong2/latlong.dart';

MapPlace at(String groupKey, String groupAr, String name) => MapPlace(
  itemId: name,
  placeName: name,
  position: const LatLng(21.4, 39.8),
  groupKey: groupKey,
  groupName: LocalizedName(ar: groupAr),
);

/// Narrowing the map to one part of the season.
///
/// The four groups the mission thinks in — the camps of منى, the camps of
/// عرفات, the hotels of مكة, the hotels of المدينة — are not written down
/// anywhere in the app. They fall out of the data: a place drawn from the
/// hotels list is grouped by the hotel's city and a camp by its مشعر — both
/// read off the entry's own `data`, so a fifth appears on the day a fifth
/// exists and nothing has to be edited. (Until 0112 that was true of the hotels
/// alone: everything else was grouped by the FILE it stood in, so the chips
/// read «توزيع أعضاء مكاتب البعثة على مخيمات منى» instead of «مخيمات منى».)
void main() {
  final season = SeasonMapState(
    status: SeasonMapStatus.ready,
    places: [
      at('type:mina', 'مخيمات منى', 'المخيم 11'),
      at('type:mina', 'مخيمات منى', 'المخيم 14'),
      at('type:arafat', 'مخيمات عرفات', 'المخيم 10'),
      at('hotels:مكة', 'فنادق مكة', 'فيلفيت ان'),
      at('hotels:المدينة', 'فنادق المدينة', 'زمزم بولمان'),
    ],
  );

  group('the groups', () {
    test('are discovered from the places, not declared', () {
      expect(
        season.groups.map((g) => g.key),
        ['type:mina', 'type:arafat', 'hotels:مكة', 'hotels:المدينة'],
      );
    });

    test('each carries how many it holds', () {
      final mina = season.groups.firstWhere((g) => g.key == 'type:mina');

      expect(mina.count, 2);
      expect(mina.name.ar, 'مخيمات منى');
    });
  });

  group('switching them', () {
    test('everything is drawn to begin with', () {
      expect(season.drawnPlaces, hasLength(5));
    });

    test('hiding one leaves the rest', () {
      final narrowed = season.copyWith(hiddenGroups: {'type:mina'});

      expect(narrowed.drawnPlaces, hasLength(3));
      expect(
        narrowed.drawnPlaces.every((p) => p.groupKey != 'type:mina'),
        isTrue,
      );
    });

    test('"only this" is the gesture the filter exists for', () {
      // Switching the other three off one at a time to look at the fourth is
      // the same work the map was meant to save.
      final cubit = _StateOnly(season)..showOnly('hotels:المدينة');

      expect(cubit.state.drawnPlaces, hasLength(1));
      expect(cubit.state.drawnPlaces.single.placeName, 'زمزم بولمان');
    });

    test('and it can be undone in one press', () {
      final cubit = _StateOnly(season)
        ..showOnly('hotels:المدينة')
        ..showAllGroups();

      expect(cubit.state.drawnPlaces, hasLength(5));
    });

    test('toggling the same group twice returns to where it started', () {
      final cubit = _StateOnly(season)
        ..toggleGroup('type:arafat')
        ..toggleGroup('type:arafat');

      expect(cubit.state.drawnPlaces, hasLength(5));
    });
  });

  test('a group that appears later arrives VISIBLE', () {
    // The reason the state holds what is HIDDEN rather than what is shown. A
    // file created mid-season, or a hotel finally given a city, must not be
    // invisible until somebody notices it is missing — which is the one state
    // a map may never be in.
    final narrowed = season.copyWith(hiddenGroups: {'type:mina'});
    final withNewGroup = narrowed.copyWith(
      places: [
        ...season.places,
        at('type:new_file', 'ملف جديد', 'مكان جديد'),
      ],
    );

    expect(
      withNewGroup.drawnPlaces.any((p) => p.groupKey == 'type:new_file'),
      isTrue,
    );
  });
}

/// A cubit standing on a fixed state, so the filter logic can be exercised
/// without a repository or a network behind it.
class _StateOnly extends SeasonMapCubit {
  _StateOnly(super.initial) : super.forTest();
}
