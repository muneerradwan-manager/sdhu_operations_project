import '../../../core/l10n/localized_name.dart';
import '../../modules/domain/module_type.dart';
import '../../modules/domain/operational_module.dart';
import '../../modules/domain/reference_item.dart';
import '../domain/export_dataset.dart';
import 'export_values.dart';

/// The two ways a block of a whole-record export is built.
///
/// A record is not a row. Exporting one operational file «دون نقص» means its
/// dates and its decision number, the values of the fields its type declares,
/// everyone posted anywhere in it, its sectors and towers, and the duties
/// written on it — five different shapes, and forcing them into one table is
/// what makes a wide sheet of mostly-empty cells that nobody reads.
///
/// So a record export is a sequence of blocks, and there are exactly two kinds:
/// a [ExportFacts] block of «البيان / القيمة» for the things a record has ONE
/// of, and an ordinary table for the things it has MANY of.
class ExportFacts {
  ExportFacts();

  final List<List<String>> _rows = [];

  /// One fact. A blank value is DROPPED rather than written as an empty line.
  ///
  /// That is not an omission: «دون نقص» is about not leaving information out,
  /// and a field nobody filled in carries none. Twenty blank lines above the
  /// three that were filled is how a reader stops reading the block at all.
  void add(String label, String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return;
    _rows.add([label, value!]);
  }

  void addName(String label, LocalizedName? name, String languageCode) =>
      add(label, name?.inLanguage(languageCode));

  bool get isEmpty => _rows.isEmpty;

  /// The block. No headings over it on purpose — «البيان / القيمة» above two
  /// columns that are self-evidently a label and its value is a line of the
  /// sheet spent saying nothing.
  ExportTable toTable({
    required String title,
    String? caption,
    bool opensRecord = false,
  }) => ExportTable(
    title: title,
    headers: const [],
    rows: _rows,
    caption: caption,
    opensRecord: opensRecord,
  );
}

/// What one of a type's own fields holds, as a person reads it.
///
/// The kinds that are not simply text are the point of this: a reference field
/// stores an id, a pdf field stores a path-and-name object, and an export that
/// wrote either of them raw would carry a UUID where the reader expects the
/// name of a hotel.
///
/// Resolved across ALL of a set's entries rather than this season's, for the
/// reason `reference_item.dart` gives about towers: a file written last season
/// points at last season's entries and still has to render.
String exportFieldValue(
  ModuleField field,
  Object? raw, {
  required List<ReferenceSet> sets,
  required String languageCode,
}) {
  if (raw == null) return '';

  switch (field.kind) {
    case ModuleFieldKind.reference:
      final set = sets.where((s) => s.id == field.referenceSetId).firstOrNull;
      final item = set?.items.where((i) => i.id == raw).firstOrNull;
      // The id rather than a blank when the entry has been deleted: a cell that
      // says nothing hides that the field WAS answered.
      return item?.name.inLanguage(languageCode) ?? raw.toString();
    case ModuleFieldKind.pdf:
      return ModuleFile.fromJson(raw)?.name ?? '';
    case ModuleFieldKind.date:
      final parsed = DateTime.tryParse(raw.toString());
      return parsed == null ? raw.toString() : ExportValues.date(parsed);
    case ModuleFieldKind.text:
    case ModuleFieldKind.textarea:
    case ModuleFieldKind.number:
    case ModuleFieldKind.url:
    case ModuleFieldKind.location:
    case ModuleFieldKind.phone:
    case ModuleFieldKind.qr:
      return _plain(raw);
  }
}

/// Anything else, flattened the way the master-data export already flattens it:
/// a stored object is shown by whatever names it, and a list by its members.
String _plain(Object? value) => switch (value) {
  null => '',
  final Map<String, dynamic> map =>
    (map['name'] ?? map['label'] ?? map['address'] ?? map['url'] ?? '')
        .toString(),
  final List<dynamic> list => list.join(' / '),
  _ => value.toString(),
};
