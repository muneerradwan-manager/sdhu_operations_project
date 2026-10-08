import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/constants/permission_codes.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/export/data/csv_writer.dart';
import 'package:sdhu_operations_project/features/export/data/export_catalog.dart';
import 'package:sdhu_operations_project/features/export/data/export_runner.dart';
import 'package:sdhu_operations_project/features/export/domain/export_dataset.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

LocalizedName n(String ar, [String? en]) => LocalizedName(ar: ar, en: en);

/// A dataset with no database behind it, so the assembling can be tested apart
/// from the fetching. They fail differently and should be caught apart:
/// fetching is where the wrong ROWS come from, assembling is where the wrong
/// COLUMNS do.
class _Fake extends ExportDataset {
  _Fake({this.rows = const []});

  final List<Map<String, String>> rows;

  @override
  String get id => 'fake';

  @override
  LocalizedName get name => n('وهمي', 'Fake');

  @override
  Set<String> get permissions => const {};

  @override
  List<ExportColumn> get columns => [
    ExportColumn(key: 'name', label: n('الاسم', 'Name')),
    ExportColumn(key: 'job', label: n('المهنة', 'Job')),
    ExportColumn(key: 'email', label: n('البريد', 'Email')),
    ExportColumn(key: 'id', label: n('المعرّف', 'Id'), byDefault: false),
  ];

  @override
  Future<List<Map<String, String>>> fetch(ExportRequest request) async => rows;
}

void main() {
  late AppLocalizations ar;
  late AppLocalizations en;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  ExportRequest request(Set<String> columns, {bool arabic = true}) =>
      ExportRequest(
        columnKeys: columns,
        l: arabic ? ar : en,
        languageCode: arabic ? 'ar' : 'en',
      );

  group('choosing the columns', () {
    final dataset = _Fake(
      rows: [
        {'name': 'منير', 'job': 'مشرف', 'email': 'a@b.c', 'id': '1'},
        {'name': 'أحمد', 'job': 'سائق', 'email': 'd@e.f', 'id': '2'},
      ],
    );

    test('only what was ticked comes out', () async {
      final table = await ExportRunner.buildTable(
        dataset: dataset,
        request: request({'name', 'job'}),
        columns: dataset.columns,
      );

      expect(table.headers, ['الاسم', 'المهنة']);
      expect(table.rows.first, ['منير', 'مشرف']);
    });

    test('the order is the dataset\'s, not the order of ticking', () async {
      // A sheet whose columns land in different places depending on which
      // checkbox somebody pressed first is a sheet nobody can put beside
      // another one.
      final table = await ExportRunner.buildTable(
        dataset: dataset,
        request: request({'email', 'name'}),
        columns: dataset.columns,
      );

      expect(table.headers, ['الاسم', 'البريد']);
    });

    test('the defaults are the ticked ones', () {
      expect(dataset.defaultColumns, {'name', 'job', 'email'});
      expect(
        dataset.defaultColumns,
        isNot(contains('id')),
        reason: 'the long tail is offered, not given',
      );
    });

    test('a column no row has anything for is an empty cell, not a gap', () async {
      final sparse = _Fake(rows: [
        {'name': 'منير'},
      ]);

      final table = await ExportRunner.buildTable(
        dataset: sparse,
        request: request({'name', 'job', 'email'}),
        columns: sparse.columns,
      );

      expect(
        table.rows.single,
        ['منير', '', ''],
        reason: 'a short row would shift every cell after it into the wrong '
            'column, and nothing would say so',
      );
    });

    test('no rows still produces the headings', () async {
      final table = await ExportRunner.buildTable(
        dataset: _Fake(),
        request: request({'name'}),
        columns: _Fake().columns,
      );

      expect(table.headers, ['الاسم']);
      expect(table.rows, isEmpty);
    });
  });

  group('language', () {
    test('the headings follow the language the export was asked for', () async {
      final dataset = _Fake();
      final table = await ExportRunner.buildTable(
        dataset: dataset,
        request: request({'name', 'job'}, arabic: false),
        columns: dataset.columns,
      );

      expect(table.headers, ['Name', 'Job']);
      expect(table.title, 'Fake');
    });

    test('an untranslated name falls back to Arabic rather than to blank', () {
      // Master data is content: half the lists were never given an English
      // name, and a blank column heading is worse than an Arabic one.
      expect(n('التكتلات').inLanguage('en'), 'التكتلات');
      expect(n('التكتلات', '').inLanguage('en'), 'التكتلات');
      expect(n('التكتلات', 'Clusters').inLanguage('en'), 'Clusters');
    });
  });

  group('the file name', () {
    test('it is ASCII and dated', () {
      final name = ExportRunner.fileName(_Fake(), ExportFormat.csv);

      expect(name, matches(RegExp(r'^fake-\d{4}-\d{2}-\d{2}\.csv$')));
      expect(
        name.codeUnits.every((c) => c < 128),
        isTrue,
        reason: 'it goes through a file system, a share sheet and an email, '
            'and an Arabic file name survives only some of those',
      );
    });

    test('the format decides the extension', () {
      expect(
        ExportRunner.fileName(_Fake(), ExportFormat.pdf),
        endsWith('.pdf'),
      );
    });
  });

  group('who is offered what', () {
    test('a dataset behind a permission is not offered without it', () {
      final offered = ExportCatalog.visibleTo(isAdmin: false, permissions: {});

      expect(
        offered.map((d) => d.id),
        isNot(contains('people')),
        reason: 'employees.view opens the directory; without it there is '
            'nothing to take out of it either',
      );
    });

    test('holding the permission offers it', () {
      final offered = ExportCatalog.visibleTo(
        isAdmin: false,
        permissions: {PermissionCodes.employeesView},
      );

      expect(offered.map((d) => d.id), contains('people'));
    });

    test('either grant opens the merged people dataset', () {
      // «الموظفون ومشاركو الموسم» is a merge of two datasets that two different
      // grants opened. A reader holding only the second must still meet the
      // chip — the alternative is that merging two things silently took one of
      // them away from him.
      final offered = ExportCatalog.visibleTo(
        isAdmin: false,
        permissions: {PermissionCodes.seasonsParticipantsView},
      );

      expect(offered.map((d) => d.id), contains('people'));
    });

    test('an admin is offered everything', () {
      final offered = ExportCatalog.visibleTo(isAdmin: true, permissions: {});

      expect(offered.length, ExportCatalog.all.length);
    });

    test('what needs no permission is always offered', () {
      final offered = ExportCatalog.visibleTo(isAdmin: false, permissions: {});

      expect(
        offered.map((d) => d.id),
        containsAll(['modules', 'reports']),
        reason: 'these are narrowed by row security rather than by a code, '
            'and a person sees exactly what he sees on their screens',
      );
    });

    test('every dataset in the catalogue has a distinct id', () {
      // The id is written into the file name and is how a dataset is found
      // again. Two of them sharing one is a bug that shows up as the wrong
      // export.
      final ids = ExportCatalog.all.map((d) => d.id).toList();

      expect(ids.toSet().length, ids.length);
    });

    test('every column key within a dataset is distinct', () {
      for (final dataset in ExportCatalog.all) {
        final keys = dataset.columns.map((c) => c.key).toList();
        expect(
          keys.toSet().length,
          keys.length,
          reason: 'in ${dataset.id}, a duplicate key means one column silently '
              'takes the other\'s values',
        );
      }
    });

    test('a dataset with columns gives some of them by default', () {
      for (final dataset in ExportCatalog.all) {
        if (dataset.columns.isEmpty) continue;
        expect(
          dataset.defaultColumns,
          isNotEmpty,
          reason: '${dataset.id} would open with the export button dead',
        );
      }
    });

    test('the whole-record datasets are the ones we meant', () {
      // Written out so that turning a dataset into a record export is a change
      // somebody makes on purpose: what comes out stops being a table.
      expect(
        [
          for (final dataset in ExportCatalog.all)
            if (dataset is ExportRecordDataset) dataset.id,
        ],
        ['modules', 'reports'],
      );
    });

    test('the files still offer columns, and the decisions cannot', () {
      // The difference is the SHAPE of what is exported, not that one is a
      // record and the other is not. A file's blocks are tables — a roster is a
      // roster — so «which of these do you want» has an answer. A published
      // قرار is prose in the order somebody wrote it, and there is no column
      // list to offer over that.
      expect(
        ExportCatalog.byId('modules')!.columns,
        isNotEmpty,
        reason: 'a man wanting a call sheet should not carry eight columns he '
            'will delete in Excel',
      );
      expect(ExportCatalog.byId('reports')!.columns, isEmpty);
    });

    test("the file's columns are namespaced by block", () {
      // The namespacing is what lets a block whose every column is unticked be
      // dropped — and its query never sent — without a second control saying
      // the same thing twice.
      final keys = ExportCatalog.byId('modules')!.columns.map((c) => c.key);

      for (final block in const ['file_', 'member_', 'node_', 'task_']) {
        expect(
          keys.any((key) => key.startsWith(block)),
          isTrue,
          reason: 'no column belongs to the $block block',
        );
      }
    });

    test('the season is asked first wherever it is asked', () {
      // The widest question comes first, on every dataset that has one. A
      // person who has run one export has run them all — and a list narrowed by
      // an answer BELOW it is a list that contradicts what was chosen above.
      for (final dataset in ExportCatalog.all) {
        final keys = [for (final option in dataset.options) option.key];
        if (!keys.contains('season')) continue;
        expect(
          keys.first,
          'season',
          reason: '${dataset.id} asks the narrower question first',
        );
      }
    });

    test('everything that lists many things can be asked for one', () {
      // «الكل أو واحد بعينه»: the register is useful and so is the single row,
      // and a screen that only ever hands over the whole register makes a man
      // find his one line in four hundred.
      const oneOf = {
        'people': 'person',
        'modules': 'module',
        'reports': 'report',
        'complaints': 'complaint',
        'evaluations': 'evaluation',
      };

      for (final entry in oneOf.entries) {
        final dataset = ExportCatalog.byId(entry.key)!;
        expect(
          [for (final option in dataset.options) option.key],
          contains(entry.value),
          reason: '${entry.key} can only be taken whole',
        );
      }
    });

    test('exactly one column is marked as worth a warning', () {
      // The mark is only worth having while it is rare. A notice standing over
      // the telephone numbers — which are the point of half the exports this
      // office runs — is a notice nobody reads by the second week, so adding a
      // second one should be a decision somebody takes on purpose.
      final marked = [
        for (final dataset in ExportCatalog.all)
          for (final column in dataset.columns)
            if (column.isSensitive) '${dataset.id}.${column.key}',
      ];

      expect(marked, ['people.id']);
    });

    test('the marked column is not ticked to begin with', () {
      // It would be a strange warning that fired on a screen nobody had
      // touched yet.
      expect(
        ExportCatalog.byId('people')!.defaultColumns,
        isNot(contains('id')),
      );
    });

    test('the decisions can be asked for one act or the other', () {
      // A قرار binds somebody and a تعميم tells everybody, and a man asked for
      // «قرارات الموسم» does not mean the meal timetable.
      expect(
        [for (final option in ExportCatalog.byId('reports')!.options) option.key],
        ['season', 'kind', 'report'],
      );
    });

    test('the retired module datasets are gone', () {
      // 'الملفات التشغيلية', 'أعضاء ملف تشغيلي' and 'مهام ملف تشغيلي' were
      // three datasets and are now one, which is what «وإنما فقط الملفات
      // التشغيلية» asked for. Leaving either of the other two in the catalogue
      // would offer a second, thinner answer to the same question.
      expect(
        ExportCatalog.all.map((d) => d.id),
        isNot(contains('module_members')),
      );
      expect(
        ExportCatalog.all.map((d) => d.id),
        isNot(contains('module_tasks')),
      );
    });
  });

  group('all, and one in particular', () {
    test('«الكل» does not narrow, and neither does an unanswered option', () {
      // The two arrive as different values — a sentinel and nothing at all —
      // and a dataset that read them as ids would filter on the literal '*'
      // and return an empty file with no error.
      final asked = ExportRequest(
        columnKeys: const {},
        l: ar,
        languageCode: 'ar',
        options: const {'season': ExportOption.anyId, 'module': 'abc'},
      );

      expect(asked.narrowing('season'), isNull);
      expect(asked.narrowing('report'), isNull);
      expect(asked.narrowing('module'), 'abc');
    });
  });

  group('a picker a person can actually choose from', () {
    ExportChoice choice(String id, String label) =>
        ExportChoice(id: id, label: n(label));

    test('entries that read alike are told apart', () {
      // The case this exists for: one form put to a committee before twenty
      // judges writes twenty evaluations sharing their template, their subject
      // and their date. The list read the same line twenty times, and a person
      // cannot choose between two things that look the same — he picks one and
      // finds out afterwards.
      final told = ExportChoice.distinct([
        choice('6b54ae1c-18b8-4dc7-9cc4-ff6bdc1bddfa', 'نموذج — لجنة'),
        choice('0485a8a5-a5ef-4eb9-bc43-c78dcee76ad5', 'نموذج — لجنة'),
      ]);

      expect(told.map((c) => c.label.ar), [
        'نموذج — لجنة · 6b54ae1c',
        'نموذج — لجنة · 0485a8a5',
      ]);
      expect(
        told.map((c) => c.id),
        ['6b54ae1c-18b8-4dc7-9cc4-ff6bdc1bddfa', '0485a8a5-a5ef-4eb9-bc43-c78dcee76ad5'],
        reason: 'the id is what the answer is, and marking must not touch it',
      );
    });

    test('an entry that already stands alone is left alone', () {
      // Stamping an id onto every line would cost every reader something to
      // protect the rare case.
      final told = ExportChoice.distinct([
        choice('a', 'الطوافة والنقل — 1448هـ'),
        choice('b', 'الإسكان — 1448هـ'),
      ]);

      expect(told.map((c) => c.label.ar), [
        'الطوافة والنقل — 1448هـ',
        'الإسكان — 1448هـ',
      ]);
    });

    test('the mark carries into the English label too', () {
      final told = ExportChoice.distinct([
        ExportChoice(id: 'aaaaaaaa-1', label: n('نموذج', 'Form')),
        ExportChoice(id: 'bbbbbbbb-2', label: n('نموذج', 'Form')),
      ]);

      expect(told.first.label.en, 'Form · aaaaaaaa');
      expect(told.last.label.en, 'Form · bbbbbbbb');
    });
  });

  group('a record export is several blocks', () {
    test('each block keeps its own caption and width', () async {
      final dataset = _FakeRecord();
      final tables = await ExportRunner.buildTables(
        dataset: dataset,
        request: request(const {}),
        columns: const [],
      );

      expect(tables.map((t) => t.caption), ['الملف', 'الأعضاء']);
      expect(
        tables.first.headers,
        isEmpty,
        reason: 'a «البيان / القيمة» block reads worse with a heading row',
      );
      expect(
        tables.first.columnCount,
        2,
        reason: 'a width read off an empty heading list would be no columns',
      );
      expect(tables.last.columnCount, 2);
    });

    test('the blocks are laid one under another in the sheet', () {
      final csv = utf8.decode(
        CsvWriter.writeAll([
          const ExportTable(
            title: 'وهمي',
            headers: [],
            rows: [
              ['الاسم', 'الطوافة'],
            ],
            caption: 'الملف',
            opensRecord: true,
          ),
          const ExportTable(
            title: 'وهمي',
            headers: ['الاسم'],
            rows: [
              ['منير'],
            ],
            caption: 'الأعضاء',
          ),
        ]).sublist(3),
      );

      expect(csv, contains('الملف\r\nالاسم,الطوافة\r\n'));
      expect(
        csv,
        contains('\r\nالأعضاء\r\nالاسم\r\nمنير\r\n'),
        reason: 'a blank line, then the caption, then the block',
      );
    });
  });
}

/// A record dataset with no database behind it.
class _FakeRecord extends ExportRecordDataset {
  @override
  String get id => 'fake_record';

  @override
  LocalizedName get name => n('سجل وهمي', 'Fake record');

  @override
  Set<String> get permissions => const {};

  @override
  List<ExportColumn> get columns => const [];

  @override
  Future<List<ExportTable>> sections(ExportRequest request) async => [
    const ExportTable(
      title: 'سجل وهمي',
      headers: [],
      rows: [
        ['الاسم', 'الطوافة'],
        ['الموسم', '1448'],
      ],
      caption: 'الملف',
      opensRecord: true,
    ),
    const ExportTable(
      title: 'سجل وهمي',
      headers: ['الاسم', 'الدور'],
      rows: [
        ['منير', 'مشرف'],
      ],
      caption: 'الأعضاء',
    ),
  ];
}
