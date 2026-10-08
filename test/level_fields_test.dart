import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/modules/domain/module_type.dart';

/// A field used to belong to the file, always. A مخيم carries its own — the
/// الطاقة الاستيعابية the whole distribution turns on, and where it is — so
/// `module_type_fields.level_id` now says whose a field is, exactly as
/// `module_type_roles.level_id` has said whose a role is since 0024.
///
/// The two are sorted apart in one place, [ModuleType.fromMap]. Get that wrong
/// and a camp's capacity turns up as a field of the file, on the first screen
/// of the editor, asked once for a file that has twenty camps.
void main() {
  Map<String, dynamic> field(String key, {String? levelId, int sort = 1}) => {
    'id': 'f-$key',
    'key': key,
    'label_ar': key,
    'label_en': key,
    'kind': 'text',
    'level_id': levelId,
    'sort_order': sort,
  };

  final type = ModuleType.fromMap({
    'id': 't',
    'code': 'arafat_camp_assignment',
    'name_ar': 'x',
    'name_en': 'x',
    'module_type_levels': [
      {
        'id': 'lv-center',
        'code': 'center',
        'name_ar': 'المركز',
        'name_en': 'Center',
        'depth': 1,
      },
      {
        'id': 'lv-camp',
        'code': 'camp',
        'name_ar': 'المخيم',
        'name_en': 'Camp',
        'depth': 2,
      },
    ],
    'module_type_fields': [
      field('official_pdf'),
      field('capacity', levelId: 'lv-camp', sort: 1),
      field('location', levelId: 'lv-camp', sort: 2),
    ],
    'module_type_roles': const [],
  });

  test("the file keeps only what is the file's", () {
    expect(type.fields.map((f) => f.key), ['official_pdf']);
  });

  test('a level carries the fields that name it, in order', () {
    final camp = type.levels.firstWhere((l) => l.code == 'camp');
    expect(camp.fields.map((f) => f.key), ['capacity', 'location']);
  });

  test('a level that names none carries none', () {
    final center = type.levels.firstWhere((l) => l.code == 'center');
    expect(center.fields, isEmpty);
  });
}
