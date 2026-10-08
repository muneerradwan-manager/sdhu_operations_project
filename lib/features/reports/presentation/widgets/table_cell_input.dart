import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../modules/domain/reference_item.dart';
import '../../../modules/presentation/widgets/picker_sheet.dart';
import '../../domain/table_column.dart';
import 'tag_list_field.dart';

/// One cell of a written table, asked for the way its column says.
///
/// Deliberately NOT [ModuleFieldInput], for four reasons worth keeping on
/// record: three of these kinds (time, time range, tags) do not exist there;
/// four of its kinds (pdf, location, phone, qr) have no business in a table
/// cell; its `onChanged` hands back an `Object?` — a `num` for a number —
/// while a row is `List<String>`; and its reference picker reads the whole
/// set unscoped, which is precisely wrong for an editor. The PIECES are
/// reused: `showPickerSheet`, the platform date and time pickers, and
/// [TagListField].
///
/// What each kind writes is the canonical machine form `drawCell` reads —
/// stated there, obeyed here, and the reason a stored value never depends on
/// the app's UI language at entry time (the retired `_TimeRangeField` stored a
/// localized sentence, and the value changed meaning with the locale).
class TableCellInput extends StatelessWidget {
  const TableCellInput({
    super.key,
    required this.column,
    required this.value,
    required this.onChanged,
    this.set,
    this.seasonId,
  });

  final TableColumn column;
  final String value;
  final ValueChanged<String> onChanged;

  /// The list a reference cell picks from. Null for every other kind — and for
  /// a reference column whose list no longer resolves, where the cell falls
  /// back to text rather than presenting a picker over nothing.
  final ReferenceSet? set;

  /// The document's season, for scoping the OFFER. The display of an already
  /// chosen entry is not scoped — a document written last season still shows
  /// its own choices.
  final String? seasonId;

  @override
  Widget build(BuildContext context) {
    switch (column.kind) {
      case TableColumnKind.text:
        return _text(context);
      case TableColumnKind.number:
        return _text(
          context,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        );
      case TableColumnKind.date:
        return _tap(
          context,
          shown: value,
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(value) ?? now,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
            );
            if (picked != null) {
              onChanged(picked.toIso8601String().split('T').first);
            }
          },
        );
      case TableColumnKind.time:
        return _tap(
          context,
          shown: value,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _timeOf(value) ?? TimeOfDay.now(),
            );
            if (picked != null) onChanged(_pad(picked));
          },
        );
      case TableColumnKind.timeRange:
        return _TimeRangeCell(
          label: column.label,
          value: value,
          onChanged: onChanged,
        );
      case TableColumnKind.reference:
        final set = this.set;
        if (set == null) return _text(context);
        return _ReferenceCell(
          label: column.label,
          value: value,
          set: set,
          seasonId: seasonId,
          onChanged: onChanged,
        );
      case TableColumnKind.tags:
        return TagListField(
          label: column.label,
          items: [
            for (final t in value.split('\n'))
              if (t.trim().isNotEmpty) t.trim(),
          ],
          onChanged: (v) => onChanged(v.join('\n')),
        );
    }
  }

  Widget _text(
    BuildContext context, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) => TextFormField(
    initialValue: value,
    keyboardType: keyboardType,
    inputFormatters: formatters,
    decoration: InputDecoration(isDense: true, labelText: column.label),
    onChanged: onChanged,
  );

  Widget _tap(
    BuildContext context, {
    required String shown,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        labelText: column.label,
        suffixIcon: const Icon(Icons.expand_more_rounded, size: 18),
      ),
      child: Text(
        shown.isEmpty ? '—' : shown,
        // Clock and calendar values read left-to-right whatever the page does.
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.start,
      ),
    ),
  );
}

TimeOfDay? _timeOf(String value) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _pad(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// From and to, as two taps.
///
/// Mined from the retired `_TimeRangeField` with its one defect corrected: it
/// stored the localized sentence, so what the database held depended on which
/// language the enterer's phone was set to. The canonical `HH:mm-HH:mm` goes
/// to storage; the sentence belongs to the reader.
class _TimeRangeCell extends StatelessWidget {
  const _TimeRangeCell({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final times = RegExp(r'(\d{1,2}):(\d{2})').allMatches(value).toList();
    final from = times.isNotEmpty ? times[0].group(0)! : '';
    final to = times.length > 1 ? times[1].group(0)! : '';

    Future<void> pick(bool start) async {
      final current = start ? from : to;
      final picked = await showTimePicker(
        context: context,
        initialTime: _timeOf(current) ?? TimeOfDay.now(),
      );
      if (picked == null) return;
      final f = start ? _pad(picked) : from;
      final t = start ? to : _pad(picked);
      // Half a range is stored as half — the other tap completes it, and a
      // reader shown one clock time can still act on it.
      onChanged(t.isEmpty ? f : '$f-$t');
    }

    return InputDecorator(
      decoration: InputDecoration(isDense: true, labelText: label),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => pick(true),
              child: Text(
                from.isEmpty ? l.reportTimeFrom : from,
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
          const Text(' – ', textDirection: TextDirection.ltr),
          Expanded(
            child: InkWell(
              onTap: () => pick(false),
              child: Text(
                to.isEmpty ? l.reportTimeTo : to,
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A choice from master data, season-scoped the way an EDITOR must be.
class _ReferenceCell extends StatelessWidget {
  const _ReferenceCell({
    required this.label,
    required this.value,
    required this.set,
    required this.seasonId,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ReferenceSet set;
  final String? seasonId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Offered: this season's active entries. Shown: whatever is chosen, even
    // an entry the season no longer offers — hiding it would read as "nobody
    // filled this in" and the enterer would not re-pick.
    final chosen = set.items.where((i) => i.id == value).firstOrNull;
    final gone = value.isNotEmpty && chosen == null;

    return InkWell(
      onTap: () async {
        final offered = [
          for (final item in set.itemsForSeason(seasonId))
            if (item.isActive || item.id == value) item,
        ];
        final result = await showPickerSheet(
          context,
          title: label,
          options: [
            for (final item in offered)
              PickerOption(id: item.id, label: item.name.of(context)),
          ],
          selected: {?(value.isEmpty ? null : value)},
          emptyMessage: l.referenceEmpty,
        );
        if (result != null) onChanged(result.firstOrNull ?? '');
      },
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          suffixIcon: const Icon(Icons.expand_more_rounded, size: 18),
        ),
        child: Text(
          gone
              ? l.reportCellEntryGone
              : chosen?.name.of(context) ?? '—',
          style: gone
              ? TextStyle(color: Theme.of(context).colorScheme.error)
              : null,
        ),
      ),
    );
  }
}
