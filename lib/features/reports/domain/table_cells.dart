/// Moving cells when columns move, and saying what a cell means when drawn.
///
/// This file replaces `table_columns.dart`, whose `realignRows` matched cells
/// to columns BY HEADING TEXT and carried a rename heuristic that existed only
/// because columns had no identity. Its documented worst case — two headings
/// changing at once — could only be answered by emptying both columns of
/// numbers, and its rows came back `after.length` wide, which on a table with
/// an expansion threw the generated cells away entirely. Columns have ids now,
/// so every case the heuristic guessed at is exact.
library;

import '../../modules/domain/reference_item.dart';
import 'table_column.dart';

/// Moves every cell to where its column went.
///
/// Positional against the EFFECTIVE layout, because that is how rows are
/// stored: the typed columns with the generated block spliced in. The old
/// layout is `before[0..beforeAt) ++ generated ++ before[beforeAt..)`; the new
/// one the same around [afterAt]. Each new typed column takes its cells from
/// wherever its ID sat before — a renamed column keeps its data because its id
/// did not change, a removed one takes only its own cells, and the generated
/// block rides from `beforeAt` to `afterAt` untouched.
///
/// A column whose id was not there before reads `''`, and a short row reads
/// `''` rather than throwing — the same tolerances `realignRows` had.
List<List<String>> moveCells({
  required List<TableColumn> before,
  required List<TableColumn> after,
  required List<List<String>> rows,
  int expandedCount = 0,
  int? beforeAt,
  int? afterAt,
}) {
  if (rows.isEmpty) return const [];

  final bAt = beforeAt ?? before.length;
  final aAt = afterAt ?? after.length;

  // Where each old typed column's cells sit in a stored row.
  int oldEffective(int typed) => typed < bAt ? typed : typed + expandedCount;

  String cell(List<String> row, int index) =>
      index >= 0 && index < row.length ? row[index] : '';

  return [
    for (final row in rows)
      [
        for (var j = 0; j < aAt; j++)
          cell(row, _sourceOf(before, after[j].id, oldEffective)),
        for (var g = 0; g < expandedCount; g++) cell(row, bAt + g),
        for (var j = aAt; j < after.length; j++)
          cell(row, _sourceOf(before, after[j].id, oldEffective)),
      ],
  ];
}

int _sourceOf(
  List<TableColumn> before,
  String id,
  int Function(int) oldEffective,
) {
  for (var i = 0; i < before.length; i++) {
    if (before[i].id == id) return oldEffective(i);
  }
  return -1;
}

/// The three renderings a stored cell may need on its way to a reader's eye.
///
/// Injected rather than reached for, because exactly three of the seven kinds
/// are locale- or master-data-dependent, and the same function must be
/// callable from a screen holding `AppLocalizations` and from a test holding
/// fakes.
class TableText {
  const TableText({
    this.referenceName = _rawReference,
    this.timeRange = _rawRange,
    this.date = _raw,
  });

  /// An entry's display name, given its set's code and its id. Must look
  /// across ALL of the set's entries, not this season's — a document written
  /// last season still has to render (reference_item.dart says this in as many
  /// words about towers and hotels).
  final String Function(String setCode, String id) referenceName;

  /// The sentence for a span of clock times — `l.reportTimeRange`.
  final String Function(String from, String to) timeRange;

  /// A calendar date, `formatDate`-shaped.
  final String Function(String iso) date;

  static String _rawReference(String setCode, String id) => id;
  static String _rawRange(String from, String to) => '$from–$to';
  static String _raw(String iso) => iso;
}

/// Two clock times, wherever they stand in the cell.
///
/// Mined from the retired `_TimeRangeField`, which is also why it is loose:
/// the legacy form is a LOCALIZED sentence — «من الساعة 13:00 إلى الساعة
/// 16:00» — whose wording depended on the app's UI language at entry time.
/// The canonical form written since 0104 is `HH:mm-HH:mm`; both parse here.
final _clock = RegExp(r'(\d{1,2}):(\d{2})');

/// What a stored cell shows a reader.
String drawCell(TableColumn column, String raw, TableText text) {
  if (raw.trim().isEmpty) return raw;
  switch (column.kind) {
    case TableColumnKind.text:
    case TableColumnKind.number:
    case TableColumnKind.tags:
    case TableColumnKind.time:
      return raw;
    case TableColumnKind.date:
      // Unparseable draws as stored, never blank: a cut cell in a published
      // document is worse than an ugly one.
      return DateTime.tryParse(raw) == null ? raw : text.date(raw);
    case TableColumnKind.timeRange:
      final times = _clock.allMatches(raw).toList();
      if (times.length < 2) return raw;
      return text.timeRange(times[0].group(0)!, times[1].group(0)!);
    case TableColumnKind.reference:
      final set = column.setCode;
      if (set == null) return raw;
      // Not found draws BLANK, never the uuid: a uuid nobody can use is worse
      // than a gap, and it is the rule the typed reader already follows.
      return text.referenceName(set, raw);
  }
}

/// What a cell becomes when its column changes kind, and whether it was lost.
///
/// Retype is the one column edit that can genuinely invalidate data — a rename
/// never touches a row, but `text → reference` leaves every cell holding a
/// name that is not an id. So each target kind states its coercion, and the
/// editor counts the losses and asks before applying. Nothing else in this app
/// empties a column silently, and this must not be the first.
({String value, bool lost}) coerceCell(
  String raw,
  TableColumnKind to, {
  ReferenceSet? set,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return (value: '', lost: false);

  switch (to) {
    case TableColumnKind.text:
    case TableColumnKind.number:
    case TableColumnKind.tags:
      return (value: raw, lost: false);
    case TableColumnKind.date:
      final parsed = DateTime.tryParse(trimmed);
      return parsed == null
          ? (value: '', lost: true)
          : (value: parsed.toIso8601String().split('T').first, lost: false);
    case TableColumnKind.time:
      final match = _clock.firstMatch(trimmed);
      return match == null
          ? (value: '', lost: true)
          : (value: _pad(match), lost: false);
    case TableColumnKind.timeRange:
      final times = _clock.allMatches(trimmed).toList();
      return times.length < 2
          ? (value: '', lost: true)
          : (value: '${_pad(times[0])}-${_pad(times[1])}', lost: false);
    case TableColumnKind.reference:
      final items = set?.items ?? const <ReferenceItem>[];
      // Already an id → keep. Else a unique name match → that id. Else lost.
      if (items.any((i) => i.id == trimmed)) {
        return (value: trimmed, lost: false);
      }
      final byName = [
        for (final i in items)
          if (i.name.ar.trim() == trimmed ||
              (i.name.en ?? '').trim() == trimmed)
            i,
      ];
      return byName.length == 1
          ? (value: byName.single.id, lost: false)
          : (value: '', lost: true);
  }
}

String _pad(RegExpMatch m) =>
    '${m.group(1)!.padLeft(2, '0')}:${m.group(2)!}';
