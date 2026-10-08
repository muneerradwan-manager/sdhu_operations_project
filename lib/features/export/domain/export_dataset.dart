import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/localized_name.dart';
import '../../../l10n/app_localizations.dart';

/// Who is asking, and what they are allowed to see.
///
/// Carried into the options and into the fetch because two of the datasets are
/// merges of things that used to be separate, and the halves are not opened by
/// the same grant: «الموظفون ومشاركو الموسم» is one chip whose «من يُصدَّر»
/// offers the permanent staff to whoever holds `employees.view` and the
/// season's participants to whoever holds `seasons.participants_view` — a
/// reader may hold either, both, or (through `export.data`) everything.
///
/// The narrowing has to be OFFERED correctly rather than merely enforced. A
/// choice the reader's row policies refuse comes back as an EMPTY FILE and no
/// error, and an empty export is worse than a refusal: he carries it away
/// believing it is the data. Same argument `ExportCatalog` makes about
/// offering a whole dataset, one level down.
class ExportViewer {
  const ExportViewer({this.isAdmin = false, this.permissions = const {}});

  final bool isAdmin;
  final Set<String> permissions;

  /// Whether this reader may see what [code] opens.
  ///
  /// `export.data` passes everything, and that is the point of it (0100): the
  /// row policies themselves were widened to accept it, so a holder exports the
  /// employees whether or not he may open the employees screen.
  bool can(String? code) =>
      code == null ||
      isAdmin ||
      permissions.contains(PermissionCodes.exportData) ||
      permissions.contains(code);
}

/// One field a dataset can put in a column.
///
/// A dataset offers every column it HAS; the person exporting picks the ones he
/// wants and their order is this list's order. Nothing is computed for a column
/// nobody asked for.
class ExportColumn {
  const ExportColumn({
    required this.key,
    required this.label,
    this.byDefault = true,
    this.isSensitive = false,
  });

  /// Stable, and the key each row is written under. Never renamed: it is what a
  /// saved selection is remembered by.
  final String key;

  final LocalizedName label;

  /// Whether it starts ticked. The identifying columns do; a person opening a
  /// list of forty fields should get a sensible sheet by pressing export, and
  /// should have to ask for the rest.
  final bool byDefault;

  /// Whether taking this column out is a decision worth pausing over.
  ///
  /// The screen says so, once, under the checklist — it does not refuse and it
  /// does not ask again. Anybody who reached this screen is entitled to the
  /// column; what he may not have in mind is that the FILE outlives the
  /// screen's protections. A person's internal identifier is the case this was
  /// built for: on the page it is a row nobody reads, and in a spreadsheet on
  /// somebody else's desk it is the key that joins him to every other table he
  /// appears in.
  ///
  /// Deliberately not a blanket mark on everything personal. A warning that
  /// stands over the telephone numbers — which are the point of half the
  /// exports this office runs — is a warning nobody reads by the second week.
  final bool isSensitive;
}

/// A choice a dataset needs before it can fetch anything — which season, which
/// master-data list, which operational file.
///
/// Kept separate from the columns because it changes WHICH ROWS there are, not
/// which parts of them are shown. Getting that wrong is how an export quietly
/// returns last season's people.
class ExportOption {
  const ExportOption({
    required this.key,
    required this.label,
    required this.choices,
    this.required = true,
    this.initial,
  });

  /// The answer that means "every one of them".
  ///
  /// A real choice with an id rather than an empty answer, because the two are
  /// not the same question. An unanswered dropdown says «لم يُختر بعد» and a
  /// person leaves it alone wondering what he missed; «الكل» says what the
  /// file will contain and can be the answer the screen opens on.
  static const anyId = '*';

  final String key;
  final LocalizedName label;

  /// Resolved when the screen opens, and AGAIN whenever another option is
  /// answered.
  ///
  /// [chosen] is what has been answered so far, which is what makes one option
  /// able to narrow another: the list of decisions offered is the list of
  /// decisions of the season above it, and a list that were resolved once when
  /// the screen opened would offer every season's.
  final Future<List<ExportChoice>> Function(
    Map<String, String> chosen,
    ExportViewer viewer,
  )
  choices;

  final bool required;

  /// The answer this option starts on, or null to start unanswered.
  ///
  /// Set to [anyId] wherever "all of them" is the sensible opening: a person
  /// who came to export the operational files and pressed the button should get
  /// the operational files, not an error telling him to answer a question whose
  /// answer was obvious.
  final String? initial;
}

class ExportChoice {
  const ExportChoice({required this.id, required this.label});
  final String id;
  final LocalizedName label;

  /// The same list, with any two entries that READ alike told apart.
  ///
  /// A picker whose entries are built out of rows can produce identical labels
  /// from different rows, and when it does it is not merely untidy — it is
  /// unusable. The case that produced this: a form assigned to twenty people
  /// about one committee writes twenty evaluations that share their template,
  /// their subject and their date, so the list read «Jvjvj — لجنة دراسة
  /// الخدمات — 2026-08-20» twenty times over and there was no way to say which
  /// one was wanted. A person cannot choose between two things that look the
  /// same; he picks one and finds out afterwards.
  ///
  /// The FIRST answer is to put the distinguishing fact in the label itself —
  /// the evaluator's name, the complainant's, the words the complaint opens
  /// with — and each picker does that. This is the net under it, for the cases
  /// nothing readable separates: the head of the row's own id, which is also
  /// what the file's «المعرّف» column carries, so the two can be matched up
  /// afterwards.
  ///
  /// Only the entries that actually collide are marked. Stamping an id onto
  /// every line would cost every reader something to protect the rare case.
  static List<ExportChoice> distinct(List<ExportChoice> choices) {
    final counts = <String, int>{};
    for (final choice in choices) {
      final key = choice.label.ar;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    return [
      for (final choice in choices)
        if ((counts[choice.label.ar] ?? 0) < 2)
          choice
        else
          ExportChoice(
            id: choice.id,
            label: LocalizedName(
              ar: '${choice.label.ar} · ${_head(choice.id)}',
              en: choice.label.en == null
                  ? null
                  : '${choice.label.en} · ${_head(choice.id)}',
            ),
          ),
    ];
  }

  /// The head of a uuid — enough to tell two rows apart by eye, short enough
  /// to sit at the end of a line without swallowing it.
  static String _head(String id) =>
      id.length <= 8 ? id : id.substring(0, 8);
}

/// What the person asked for.
class ExportRequest {
  const ExportRequest({
    required this.columnKeys,
    required this.l,
    required this.languageCode,
    this.options = const {},
    this.viewer = const ExportViewer(),
  });

  /// Which columns, and in the dataset's own order rather than in the order
  /// they happened to be ticked.
  final Set<String> columnKeys;

  /// The answers to [ExportDataset.options], by key.
  final Map<String, String> options;

  /// The language the file comes out in, carried rather than read from a
  /// context: the file is built after the screen that asked for it may already
  /// have gone, and half a sheet in each language is not a sheet.
  final AppLocalizations l;
  final String languageCode;

  /// Who asked. A dataset that offers several kinds of thing under one chip
  /// reads this to leave out the kind this reader may not have.
  final ExportViewer viewer;

  String? option(String key) => options[key];

  /// The answer to [key] when it NARROWS something, and null when it does not.
  ///
  /// «الكل» and «لم يُختر» mean the same thing to a query — do not filter — and
  /// they arrive as two different values, [ExportOption.anyId] and nothing at
  /// all. A dataset asking `option('season') != null` would take «الكل» for a
  /// season id and return an empty file.
  String? narrowing(String key) {
    final value = options[key];
    if (value == null || value.isEmpty || value == ExportOption.anyId) {
      return null;
    }
    return value;
  }

  bool wants(String columnKey) => columnKeys.contains(columnKey);

  String text(LocalizedName? name) => name?.inLanguage(languageCode) ?? '';
}

/// One kind of thing that can be taken out of this app.
///
/// The catalogue is deliberately built out of these rather than out of an
/// export button on each screen. A button on a screen exports what that screen
/// happens to be showing — the filter that was applied, the hundred rows that
/// were loaded — and the person cannot tell which. A dataset states what it
/// fetches and is answerable for it.
///
/// Every one of them reads through the ordinary repositories, so row security
/// narrows an export exactly as it narrows the screen. [permissions] is what
/// decides whether the dataset is OFFERED; it is not what makes it safe.
abstract class ExportDataset {
  const ExportDataset();

  /// Stable identifier. Written into the file name and into a saved selection.
  String get id;

  LocalizedName get name;

  /// The codes that open it — ANY one of them is enough — or empty when
  /// anybody may.
  ///
  /// A set rather than one code because «الموظفون ومشاركو الموسم» is a merge of
  /// two things that two different grants opened, and a reader holding either
  /// should meet the chip. Which HALF he is then offered is [ExportViewer]'s
  /// business, inside the option.
  Set<String> get permissions;

  List<ExportColumn> get columns;

  List<ExportOption> get options => const [];

  /// Columns that only exist once an option has been answered.
  ///
  /// The master-data lists are why. A hotel has a capacity and a camp has a
  /// location — extra fields the Administration adds to a list during a season,
  /// held in the row's own JSON. They are real columns of that list and a
  /// person exporting the hotels should be offered them; but they cannot be
  /// named until he has said WHICH list, and a catalogue that had to be edited
  /// whenever a field was added would always be a season behind.
  ///
  /// Resolved by the screen after the options are chosen, and appended to
  /// [columns]. Off by default: they are the long tail, and the sheet a person
  /// gets for pressing export should be the short one.
  Future<List<ExportColumn>> extraColumns(Map<String, String> options) async =>
      const [];

  /// Reads the rows. Each row is keyed by [ExportColumn.key]; a key the row has
  /// nothing for is simply absent and comes out as an empty cell.
  Future<List<Map<String, String>>> fetch(ExportRequest request);

  /// The columns the person gets before touching anything.
  Set<String> get defaultColumns => {
    for (final column in columns)
      if (column.byDefault) column.key,
  };
}

/// A finished export: the headings, and the rows under them, both already
/// narrowed to what was asked for and in the dataset's column order.
class ExportTable {
  const ExportTable({
    required this.title,
    required this.headers,
    required this.rows,
    this.caption,
    this.opensRecord = false,
  });

  final String title;

  /// The headings. EMPTY is meaningful and not a mistake: a two-column block of
  /// «البيان / القيمة» reads worse with a heading row over it than without one,
  /// and the whole-record exports are mostly made of those.
  final List<String> headers;

  final List<List<String>> rows;

  /// What this block of the file is — «الأعضاء», «المهام», the name of the
  /// record it belongs to. Null for an export that is one table and needs no
  /// heading beyond the document's own title.
  final String? caption;

  /// Whether this table STARTS a record rather than continuing one.
  ///
  /// A whole-file export of forty operational files is forty runs of five
  /// tables, and without this the reader meets two hundred captions of equal
  /// weight and cannot tell where one file ends. The first table of each record
  /// carries the file's own name and is set apart; the rest sit under it.
  final bool opensRecord;

  bool get isEmpty => rows.isEmpty;

  /// How wide the block is.
  ///
  /// Read off the widest ROW as well as the headings, because a table may have
  /// none — see [headers] — and a width taken from an empty heading list is
  /// zero, which lays a two-column block out as no columns at all.
  int get columnCount {
    var widest = headers.length;
    for (final row in rows) {
      if (row.length > widest) widest = row.length;
    }
    return widest;
  }
}

/// A dataset that hands over whole RECORDS rather than a table of them.
///
/// The two are different in kind, not in size, and that is why this is a
/// separate class rather than a flag. An ordinary dataset answers "give me the
/// operational files, with these columns" — a table, one line per file, and the
/// person picks which of its fields he wants. This one answers "give me THIS
/// FILE" — its dates and its decision number, the values of its own fields, its
/// people and where each of them stands, its sectors and towers, its duties —
/// laid out as the sections of a document.
///
/// Whether it can still be TICKED is left to each one, and the two in this app
/// answer differently on purpose.
///
///   * The operational files DO offer columns. A file's blocks are tables of a
///     known shape — a roster, a list of towers, a list of duties — so a person
///     can say he wants the names and the telephones and not the identifiers,
///     exactly as he can of the employees. Keys are namespaced by block, and a
///     block whose every column is unticked is simply not written.
///   * The decisions do NOT. A published قرار is prose in the order it was
///     written — headings, paragraphs, a table somebody typed — and there is no
///     column list to offer over that. It is printed whole.
///
/// So [columns] is inherited and may be empty; the screen draws a checklist
/// only when there is one, and [sections] decides what the file contains.
abstract class ExportRecordDataset extends ExportDataset {
  const ExportRecordDataset();

  /// The file, in reading order. Each entry is one block of it.
  Future<List<ExportTable>> sections(ExportRequest request);

  /// Never reached — [sections] is what the runner asks a record dataset for —
  /// and implemented here so that the record datasets do not each carry a stub.
  @override
  Future<List<Map<String, String>>> fetch(ExportRequest request) async =>
      const [];
}
