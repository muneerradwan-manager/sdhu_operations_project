import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/modules/application/module_editor_cubit.dart';
import 'package:sdhu_operations_project/features/modules/data/modules_repository.dart';
import 'package:sdhu_operations_project/features/modules/domain/module_type.dart';
import 'package:sdhu_operations_project/features/modules/domain/operational_module.dart';
import 'package:sdhu_operations_project/features/modules/domain/reference_item.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile.dart';

/// The first section of creating a file is the same on every type: when the
/// work starts, when it ends, a note beside each of those, the decision number
/// and how often the file asks for a report.
///
/// The two notes are what 0113 added, and they stand where the TYPE's
/// `start_condition` and `end_condition` used to be printed into the form. That
/// distinction is the whole point of them and is what these tests hold: a
/// condition is one sentence about every file of a kind, the same every season;
/// a note is this file's own, written by whoever opened it, and it reaches
/// `modules.start_note` — never `modules.data`, which is the type's territory.
class _FakeModules extends ModulesRepository {
  _FakeModules(this._type);

  final ModuleType _type;

  /// What the last create/update actually sent, so a test can read the columns
  /// rather than the intention.
  Map<String, Object?>? written;

  @override
  Future<ModuleType?> fetchModuleType(String id) async => _type;

  @override
  Future<List<ModuleType>> fetchModuleTypes({bool activeOnly = true}) async =>
      const [];

  @override
  Future<List<Profile>> fetchAssignableEmployees(String seasonId) async =>
      const [];

  @override
  Future<List<ReferenceSet>> fetchReferenceSets({
    bool activeOnly = true,
  }) async => const [];

  @override
  Future<String> createModule({
    required String moduleTypeId,
    required String seasonId,
    required DateTime startsOn,
    required Map<String, dynamic> data,
    DateTime? endsOn,
    String? startNote,
    String? endNote,
    String? decisionNumber,
    ReportCadence? reportCadence,
  }) async {
    written = {
      'start_note': startNote,
      'end_note': endNote,
      'decision_number': decisionNumber,
      'data': data,
    };
    return 'module-1';
  }

  @override
  Future<void> updateModule(
    String id, {
    required DateTime startsOn,
    required Map<String, dynamic> data,
    DateTime? endsOn,
    String? startNote,
    String? endNote,
    String? decisionNumber,
    ReportCadence? reportCadence,
  }) async {
    written = {
      'start_note': startNote,
      'end_note': endNote,
      'decision_number': decisionNumber,
      'data': data,
    };
  }
}

void main() {
  LocalizedName n(String s) => LocalizedName(ar: s, en: s);

  // A type that states both conditions, which is what makes it worth asking
  // whether the file's own notes came out separate from them.
  final type = ModuleType(
    id: 't',
    code: 'makkah_sectors_towers',
    name: n('قطاعات وأبراج'),
    startCondition: n('من تاريخ اعتماد مجموعات الحج السوري'),
    endCondition: n('ترحيل آخر حاج إلى المدينة المنورة'),
  );

  Future<_FakeModules> saveWith({String? startNote, String? endNote}) async {
    final repo = _FakeModules(type);
    final cubit = ModuleEditorCubit(repo, moduleTypeId: 't', seasonId: 's');
    // The type is fetched in the constructor; nothing may be entered before it
    // lands, and neither may anything be asserted.
    await Future<void>.delayed(Duration.zero);

    cubit.setStartsOn(DateTime(2026, 5, 1));
    if (startNote != null) cubit.setStartNote(startNote);
    if (endNote != null) cubit.setEndNote(endNote);

    final result = await cubit.saveInfo();
    expect(result.ok, isTrue);
    return repo;
  }

  group('what the row carries', () {
    test('both notes reach their own columns, not the type\'s data', () async {
      final repo = await saveWith(
        startNote: 'بدأ العمل مع وصول الدفعة الأولى',
        endNote: 'أُغلق بعد ترحيل آخر فوج',
      );

      expect(repo.written!['start_note'], 'بدأ العمل مع وصول الدفعة الأولى');
      expect(repo.written!['end_note'], 'أُغلق بعد ترحيل آخر فوج');
      // The notes are facts of the FILE. Nothing of them belongs in `data`,
      // which is keyed by the type's own fields.
      expect(repo.written!['data'], isEmpty);
    });

    test('a note nobody wrote is null, not an empty string', () async {
      final repo = await saveWith();

      expect(repo.written!['start_note'], isNull);
      expect(repo.written!['end_note'], isNull);
    });

    test('a note cleared to blank is null too', () async {
      // Typing into the box and deleting it again says nothing, and saying
      // nothing is a null — an empty string is a value that reads as one.
      final repo = await saveWith(startNote: '   ', endNote: '');

      expect(repo.written!['start_note'], isNull);
      expect(repo.written!['end_note'], isNull);
    });

    test('the space inside a note survives the trip', () async {
      final repo = await saveWith(startNote: ' سطران\nمن الكلام ');

      expect(repo.written!['start_note'], 'سطران\nمن الكلام');
    });
  });

  group('reading a file back', () {
    OperationalModule parse(Map<String, dynamic> extra) =>
        OperationalModule.fromMap({
          'id': 'm',
          'module_type_id': 't',
          'season_id': 's',
          ...extra,
        });

    test('the notes come off the row', () {
      final module = parse({
        'start_note': 'بدأ مع وصول الدفعة الأولى',
        'end_note': 'أُغلق بعد ترحيل آخر فوج',
      });

      expect(module.startNote, 'بدأ مع وصول الدفعة الأولى');
      expect(module.endNote, 'أُغلق بعد ترحيل آخر فوج');
    });

    test('a database without 0113 yields no notes rather than failing', () {
      // The app outlives any one deployment of the schema, and a missing
      // column is a file with nothing written on it — not a crash on open.
      final module = parse(const {});

      expect(module.startNote, isNull);
      expect(module.endNote, isNull);
    });

    test('a note is not the type\'s condition', () {
      // Both can be present at once and they answer different questions: the
      // condition names the event that closes every file of the kind, the note
      // says what happened to this one.
      final module = parse({
        'end_note': 'انتهى قبل الموعد',
        'module_types': {
          'name_ar': 'قطاعات وأبراج',
          'end_condition_ar': 'ترحيل آخر حاج إلى المدينة المنورة',
        },
      });

      expect(module.endNote, 'انتهى قبل الموعد');
      expect(module.endCondition?.ar, 'ترحيل آخر حاج إلى المدينة المنورة');
    });
  });
}
