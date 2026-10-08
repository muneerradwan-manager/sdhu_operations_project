import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/modules/domain/module_type.dart';

/// Which levels of a file can carry a check-in code.
///
/// A code is a sticker screwed to something physical — a tower's entrance, a
/// camp's gate. Some levels are that and some are only arrangements, and the
/// difference is now STATED by the level (`is_place`, migration 0089) rather
/// than worked out from the tree.
///
/// It is stated because working it out is what shipped wrong. The first version
/// took "the deepest level", which quietly dropped every hotel in مكة: the tree
/// there is القطاع(1) → البرج/الفندق(2) → التكتل(3), and the تكتل — a bloc of
/// pilgrims INSIDE a building — was added below the tower in 0061. So the codes
/// were printed for the blocs and none for the buildings, which is backwards.
///
/// Two other inferences fail the same way, and the tests below hold each of
/// them down:
///   * "a level with a reference list" — the تكتل draws from `clusters` exactly
///     as the tower draws from `hotels`.
///   * "anything but the outermost" — منى's المركز is outermost and the المخيم
///     under it is the place, but مكة has two non-outermost levels and only one
///     of them is a place.
void main() {
  Map<String, dynamic> level(
    String code,
    String name,
    int depth, {
    bool isPlace = false,
    String? set,
  }) => {
    'id': 'lv-$code',
    'code': code,
    'name_ar': name,
    'name_en': code,
    'depth': depth,
    'is_place': isPlace,
    'reference_set_id': set,
  };

  ModuleType typeWith(String code, List<Map<String, dynamic>> levels) =>
      ModuleType.fromMap({
        'id': 't',
        'code': code,
        'name_ar': code,
        'name_en': code,
        'module_type_levels': levels,
      });

  /// مكة, exactly as the migrations build it.
  final makkah = typeWith('makkah_sectors_towers', [
    level('sector', 'القطاع', 1),
    level('tower', 'البرج/الفندق', 2, isPlace: true, set: 'rs-hotels'),
    level('cluster', 'التكتل', 3, set: 'rs-clusters'),
  ]);

  group('مكة — the case that was shipped wrong', () {
    test('the hotel carries a code', () {
      expect(
        makkah.placeLevels.map((l) => l.code),
        ['tower'],
        reason: 'the hotels are the whole point of this screen',
      );
    });

    test('the cluster does not, though it is the deepest', () {
      final deepest = makkah.levels.last;

      expect(deepest.code, 'cluster');
      expect(
        deepest.isPlace,
        isFalse,
        reason: 'a تكتل is a bloc of pilgrims inside a tower that already has '
            'a code — two places answering to one code is the failure',
      );
    });

    test('the sector does not either', () {
      expect(makkah.levels.first.isPlace, isFalse);
    });

    test('having a reference list is not what makes a place', () {
      // Both of these draw from master data. Only one is somewhere you stand.
      final tower = makkah.levels[1];
      final cluster = makkah.levels[2];

      expect(tower.referenceSetId, isNotNull);
      expect(cluster.referenceSetId, isNotNull);
      expect(tower.isPlace != cluster.isPlace, isTrue);
    });
  });

  group('the camps', () {
    test('منى offers the camp and not the centre', () {
      final mina = typeWith('mina_camp_assignment', [
        level('center', 'المركز', 1),
        level('camp', 'المخيم', 2, isPlace: true),
      ]);

      expect(mina.placeLevels.map((l) => l.code), ['camp']);
    });
  });

  group('files with nowhere to stand', () {
    test('المدينة offers nothing, and that is an answer', () {
      // شركة الخدمة is a company, not a building.
      final madinah = typeWith('madinah_admin_office', [
        level('service_company', 'شركة الخدمة', 1),
      ]);

      expect(madinah.placeLevels, isEmpty);
    });

    test('a file with no tree offers nothing', () {
      expect(typeWith('flat', []).placeLevels, isEmpty);
    });
  });

  group('a database that has not had 0089 applied', () {
    test('offers no codes rather than the wrong ones', () {
      // The column is absent, so every level reads as false. An empty list
      // with a sentence explaining it is a far better failure than codes
      // printed for something with no gate to put them on.
      final old = ModuleType.fromMap({
        'id': 't',
        'code': 'makkah_sectors_towers',
        'name_ar': 'x',
        'name_en': 'x',
        'module_type_levels': [
          {'id': 'lv-t', 'code': 'tower', 'name_ar': 'البرج', 'name_en': 'T',
           'depth': 2},
        ],
      });

      expect(old.placeLevels, isEmpty);
    });
  });

  test('the flag survives being parsed', () {
    // Every level is rebuilt with its roles and fields while a type is read.
    // A field left out of that rebuild is not defaulted, it is ERASED — which
    // would switch every place off on the way in and show an empty screen.
    expect(makkah.levelById('lv-tower')?.isPlace, isTrue);
  });
}
